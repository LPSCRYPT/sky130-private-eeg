use ark_bls12_381::Fr;
use ark_r1cs_std::{fields::fp::FpVar, prelude::*};
use ark_relations::r1cs::{ConstraintSynthesizer, ConstraintSystemRef, SynthesisError};

use crate::model::{full_round, params, Window, COUNT_TAG, NEG_RAIL, PACK, POS_RAIL, SLOTS, VALID, WINDOW_TAG};

type V = FpVar<Fr>;
type Cs = ConstraintSystemRef<Fr>;
type R<T> = Result<T, SynthesisError>;

fn permutation(s: &mut [V; 3]) -> R<()> {
    let p = params();
    for (r, keys) in p.ark.iter().enumerate() {
        for (i, (x, k)) in s.iter_mut().zip(keys).enumerate() {
            *x += *k;
            if i == 0 || full_round(r) { *x = x.square()?.square()? * &*x; }
        }
        let mixed = p.mds.map(|row| &s[0] * row[0] + &s[1] * row[1] + &s[2] * row[2]);
        for (lane, sum) in s.iter_mut().zip(mixed) {
            // Unboxed lanes in the partial rounds would otherwise accumulate
            // long linear combinations of all preceding rounds' variables.
            if full_round(r) {
                *lane = sum;
            } else {
                let isolated = V::new_witness(sum.cs(), || sum.value())?;
                isolated.enforce_equal(&sum)?;
                *lane = isolated;
            }
        }
    }
    Ok(())
}

fn bounded(cs: Cs, value: u32, width: usize) -> R<V> {
    let mut x = V::zero();
    for bit in 0..width {
        let b = Boolean::new_witness(cs.clone(), || Ok((value >> bit) & 1 != 0))?;
        x += V::from(b) * Fr::from(1u32 << bit);
    }
    Ok(x)
}

fn commit_prefix(nonce: &V, pos: &V, count: &V, salt: Fr) -> R<V> {
    let salt = V::new_witness(nonce.cs(), || Ok(salt))?;
    let mut s = [pos * Fr::from(1u64 << 32) + count * Fr::from(1u64 << 48) + Fr::from(COUNT_TAG), nonce.clone(), salt];
    permutation(&mut s)?;
    Ok(s.into_iter().next().unwrap())
}

pub struct Step {
    pub nonce: u128,
    pub index: u16,
    pub root: Fr,
    pub links: [Fr; 2],
    pub window: Window,
    pub before: u16,
    pub salts: [Fr; 2],
}

impl Step {
    pub fn shape() -> Self {
        let z = Fr::from(0u8);
        Self { nonce: 0, index: 0, root: z, links: [z; 2], window: Window { slots: [0; SLOTS], blind: z }, before: 0, salts: [z; 2] }
    }
}

impl ConstraintSynthesizer<Fr> for Step {
    fn generate_constraints(self, cs: Cs) -> R<()> {
        // Verifier constructs the first two field inputs from fixed-width types.
        let nonce = V::new_input(cs.clone(), || Ok(Fr::from(self.nonce)))?;
        let index = V::new_input(cs.clone(), || Ok(Fr::from(self.index)))?;
        let root = V::new_input(cs.clone(), || Ok(self.root))?;
        let left = V::new_input(cs.clone(), || Ok(self.links[0]))?;
        let right = V::new_input(cs.clone(), || Ok(self.links[1]))?;

        let blind = V::new_witness(cs.clone(), || Ok(self.window.blind))?;
        let domain = &index * Fr::from(1u64 << 32) + Fr::from(WINDOW_TAG);
        let mut s = [domain, nonce.clone(), blind];
        permutation(&mut s)?;
        let mut present = V::zero();
        let mut rails = V::zero();
        for group in self.window.slots.chunks_exact(PACK) {
            let mut word = V::zero();
            for &slot in group.iter().rev() {
                let raw = bounded(cs.clone(), slot & (VALID - 1), 24)?;
                let valid = Boolean::new_witness(cs.clone(), || Ok(slot & VALID != 0))?;
                // Prevent a witness from hiding nonzero payloads in absent slots.
                raw.conditional_enforce_equal(&V::zero(), &!&valid)?;
                let valid = V::from(valid);
                present += &valid;
                let a = &raw - Fr::from(NEG_RAIL);
                let b = &raw - Fr::from(POS_RAIL);
                rails += V::from((a * b).is_zero()?);
                word = word * Fr::from(1u32 << 25) + valid * Fr::from(VALID) + raw;
            }
            s[0] += word;
            permutation(&mut s)?;
        }
        s[0].enforce_equal(&root)?;

        let complete = present.is_eq(&V::constant(Fr::from(SLOTS as u32)))?;
        // rails is a sum of exactly 500 booleans. This polynomial is zero
        // precisely for the five integers 0..=4, without a private comparison hint.
        let low = (1..5u8).fold(rails.clone(), |p, k| p * (&rails - Fr::from(k))).is_zero()?;
        let pass = V::from(complete & low);
        let before = bounded(cs.clone(), self.before.into(), 16)?;
        let slack = bounded(cs, self.index.saturating_sub(self.before).into(), 16)?;
        (&before + slack).enforce_equal(&index)?;
        commit_prefix(&nonce, &index, &before, self.salts[0])?.enforce_equal(&left)?;
        // 0 <= before <= index <= N-1. Thus after <= index+1 <= 65535;
        // these field operations cannot wrap into another integer transition.
        commit_prefix(&nonce, &(index + Fr::from(1u8)), &(before + pass), self.salts[1])?.enforce_equal(&right)
    }
}
