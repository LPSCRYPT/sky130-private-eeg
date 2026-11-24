use std::sync::LazyLock;

use ark_bls12_381::Fr;
use ark_ff::{Field, PrimeField};
use ark_serialize::CanonicalDeserialize;

pub const SLOTS: usize = 500;
pub const PACK: usize = 10;
pub const ROUNDS: usize = 65;
pub const WINDOW_TAG: u64 = 0x4545_4701;
pub const COUNT_TAG: u64 = 0x4351_5401;
pub const NEG_RAIL: u32 = 0x80_0000;
pub const POS_RAIL: u32 = 0x7f_ffff;
pub const VALID: u32 = 1 << 24;

pub fn hex<const N: usize>(s: &[u8]) -> Result<[u8; N], &'static str> {
    fn digit(b: u8) -> Result<u8, &'static str> {
        match b {
            b'0'..=b'9' => Ok(b - b'0'),
            b'a'..=b'f' => Ok(b - b'a' + 10),
            _ => Err("expected lowercase hexadecimal digits"),
        }
    }
    if s.len() != 2 * N { return Err("incorrect hex length"); }
    let mut result = [0; N];
    for (n, pair) in result.iter_mut().zip(s.chunks_exact(2)) {
        *n = (digit(pair[0])? << 4) | digit(pair[1])?;
    }
    Ok(result)
}

pub struct Params {
    pub ark: [[Fr; 3]; ROUNDS],
    pub mds: [[Fr; 3]; 3],
}

pub fn params() -> &'static Params {
    fn matrix<const ROWS: usize>(text: &str) -> [[Fr; 3]; ROWS] {
        let mut lines = text.lines();
        let values = std::array::from_fn(|_| std::array::from_fn(|_| {
            let mut b = hex::<32>(lines.next().expect("missing parameter").as_bytes()).unwrap();
            b.reverse();
            Fr::deserialize_compressed(b.as_slice()).expect("noncanonical field constant")
        }));
        assert!(lines.next().is_none(), "extra parameter");
        values
    }
    static PARAMS: LazyLock<Params> = LazyLock::new(|| Params {
        ark: matrix(include_str!("../../params/ark.hex")),
        mds: matrix(include_str!("../../params/mds.hex")),
    });
    &PARAMS
}

pub fn full_round(r: usize) -> bool { !(4..ROUNDS - 4).contains(&r) }

pub fn permute(mut s: [Fr; 3]) -> [Fr; 3] {
    let p = params();
    for (r, keys) in p.ark.iter().enumerate() {
        for (i, (x, k)) in s.iter_mut().zip(keys).enumerate() {
            *x += k;
            if i == 0 || full_round(r) { *x *= x.square().square(); }
        }
        s = p.mds.map(|row| row[0] * s[0] + row[1] * s[1] + row[2] * s[2]);
    }
    s
}

pub fn count_commit(nonce: u128, position: u16, count: u16, salt: Fr) -> Fr {
    let domain = COUNT_TAG | ((position as u64) << 32) | ((count as u64) << 48);
    permute([Fr::from(domain), Fr::from(nonce), salt])[0]
}

#[derive(Clone)]
pub struct Window {
    // Each slot is zero (absent) or VALID | raw24. There is no distinct -0.
    pub slots: [u32; SLOTS],
    pub blind: Fr,
}

impl Window {
    pub fn root(&self, nonce: u128, index: u16) -> Fr {
        let domain = WINDOW_TAG | ((index as u64) << 32);
        let mut s = permute([Fr::from(domain), Fr::from(nonce), self.blind]);
        for group in self.slots.chunks_exact(PACK) {
            // 250 bits fit in Fr; place slot 0 at the least significant end.
            let word = group.iter().rev().fold(Fr::from(0u8), |v, &slot| {
                v * Fr::from(1u32 << 25) + Fr::from(slot)
            });
            s[0] += word;
            s = permute(s);
        }
        s[0]
    }

    pub fn pass(&self) -> bool {
        self.slots.iter().all(|&s| s & VALID != 0) &&
            self.slots.iter().filter(|&&s| s == (VALID | NEG_RAIL) || s == (VALID | POS_RAIL)).count() < 5
    }

    pub fn synthetic(index: u16, blind: Fr) -> Self {
        let slots = std::array::from_fn(|t| match (index % 3, t) {
            (0, 0..4) => VALID | NEG_RAIL,
            (1, 0..5) => VALID | POS_RAIL,
            (2, 0) => 0,
            _ => VALID | ((t as u32 * 73 + u32::from(index) * 11) % 0x70_0000),
        });
        Self { slots, blind }
    }
}

pub fn print_fixture_roots() {
    for i in 0..2 {
        let root = Window::synthetic(i, Fr::from(100 + i)).root(42, i);
        for limb in root.into_bigint().as_ref().iter().rev() { print!("{limb:016x}"); }
        println!();
    }
}
