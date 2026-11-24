use std::{fs, io::{Read, Write}, path::Path};

use anyhow::{ensure, Context, Result};
use ark_bls12_381::{Bls12_381, Fr};
use ark_ff::UniformRand;
use ark_groth16::{prepare_verifying_key, Groth16, Proof, ProvingKey, VerifyingKey};
use ark_serialize::{CanonicalDeserialize, CanonicalSerialize};
use ed25519_dalek::{SigningKey, VerifyingKey as DeviceKey};
use rand::rngs::OsRng;

use crate::{circuit::Step, model::count_commit, wire::{self, Manifest}};

type G = Groth16<Bls12_381>;

pub fn setup(dir: &Path) -> Result<()> {
    fs::create_dir(dir).context("key output directory must not exist")?;
    let pk = G::generate_random_parameters_with_reduction(Step::shape(), &mut OsRng)?;
    wire::save(&dir.join("pk.bin"), &pk)?;
    wire::save(&dir.join("vk.bin"), &pk.vk)?;
    let sk = SigningKey::generate(&mut OsRng);
    for (name, b) in [("device.sk", sk.to_bytes()), ("device.pub", sk.verifying_key().to_bytes())] {
        let mut f = wire::create(&dir.join(name))?;
        f.write_all(&b)?;
        f.flush()?;
    }
    Ok(())
}

pub fn prove(pk: &Path, manifest: &Path, witness: &Path, bundle: &Path) -> Result<()> {
    let mut m = wire::open(manifest)?;
    let mft = Manifest::read(&mut m)?;
    wire::eof(&mut m)?;
    let mut w = wire::open(witness)?;
    wire::magic(&mut w, wire::WITNESS)?;
    let pk: ProvingKey<Bls12_381> = wire::load(pk)?;
    let mut out = wire::create(bundle)?;
    out.write_all(wire::BUNDLE)?;
    out.write_all(&mft.wire)?;
    let mut count = 0u16;
    let mut salt = Fr::rand(&mut OsRng);
    let mut link = count_commit(mft.nonce, 0, count, salt);
    salt.serialize_compressed(&mut out)?;
    link.serialize_compressed(&mut out)?;
    for (index, &root) in (0..mft.n).zip(&mft.roots) {
        let window = wire::read_window(&mut w)?;
        ensure!(window.root(mft.nonce, index) == root, "witness does not open signed root {index}");
        let after = count + u16::from(window.pass());
        let new_salt = Fr::rand(&mut OsRng);
        let next = count_commit(mft.nonce, index + 1, after, new_salt);
        let step = Step { nonce: mft.nonce, index, root, links: [link, next], window, before: count, salts: [salt, new_salt] };
        let proof = G::create_random_proof_with_reduction(step, &pk, &mut OsRng)?;
        next.serialize_compressed(&mut out)?;
        proof.serialize_compressed(&mut out)?;
        (count, salt, link) = (after, new_salt, next);
    }
    wire::eof(&mut w)?;
    salt.serialize_compressed(&mut out)?;
    out.write_all(&count.to_le_bytes())?;
    Ok(out.flush()?)
}

pub fn verify(vk: &Path, device: &Path, expected_nonce: u128, expected_n: u16, bundle: &Path) -> Result<u16> {
    let vk: VerifyingKey<Bls12_381> = wire::load(vk)?;
    let device = DeviceKey::from_bytes(&wire::fixed_key(device)?)?;
    verify_stream(&vk, &device, expected_nonce, expected_n, &mut wire::open(bundle)?)
}

fn verify_stream(vk: &VerifyingKey<Bls12_381>, key: &DeviceKey, nonce: u128, n: u16, r: &mut impl Read) -> Result<u16> {
    wire::magic(r, wire::BUNDLE)?;
    let m = Manifest::read(r)?;
    m.authenticate(key, nonce, n)?;
    let salt0 = Fr::deserialize_compressed(&mut *r)?;
    let mut prev = Fr::deserialize_compressed(&mut *r)?;
    ensure!(prev == count_commit(nonce, 0, 0, salt0), "initial prefix is not zero");
    let pvk = prepare_verifying_key(vk);
    for (index, &root) in (0..n).zip(&m.roots) {
        let next = Fr::deserialize_compressed(&mut *r)?;
        let proof = Proof::deserialize_compressed(&mut *r)?;
        let inputs = [Fr::from(nonce), Fr::from(index), root, prev, next];
        ensure!(G::verify_proof(&pvk, &proof, &inputs)?, "invalid proof at index {index}");
        prev = next;
    }
    let final_salt = Fr::deserialize_compressed(&mut *r)?;
    let total = u16::from_le_bytes(wire::bytes(r)?);
    wire::eof(r)?;
    ensure!(total <= n && prev == count_commit(nonce, n, total, final_salt), "invalid aggregate opening");
    Ok(total)
}
