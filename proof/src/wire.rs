use std::{fs::{self, File, OpenOptions}, io::{BufRead, BufReader, BufWriter, Read, Write}, path::Path};

use anyhow::{bail, ensure, Context, Result};
use ark_bls12_381::Fr;
use ark_ff::UniformRand;
use ark_serialize::{CanonicalDeserialize, CanonicalSerialize};
use ed25519_dalek::{Signature, Signer, SigningKey, VerifyingKey};
use rand::rngs::OsRng;

use crate::model::{Window, SLOTS, VALID};

// Fixed-width raw Ed25519 (not DER). The signed prefix contains the protocol
// version and exact QC-policy identifier before the verifier's fresh challenge.
pub const MANIFEST: &[u8] = b"EEG-MANIFEST\x01QC01";
pub const WITNESS: &[u8] = b"EEG-WIT\x01";
pub const BUNDLE: &[u8] = b"EEG-PROOF\x01";

pub fn create(path: &Path) -> Result<BufWriter<File>> {
    let mut opts = OpenOptions::new();
    opts.write(true).create_new(true);
    #[cfg(unix)] {
        use std::os::unix::fs::OpenOptionsExt;
        opts.mode(0o600);
    }
    Ok(BufWriter::new(opts.open(path).with_context(|| format!("creating {} (must not exist)", path.display()))?))
}

pub fn open(path: &Path) -> Result<BufReader<File>> {
    Ok(BufReader::new(File::open(path).with_context(|| format!("opening {}", path.display()))?))
}

pub fn bytes<const N: usize>(r: &mut impl Read) -> Result<[u8; N]> {
    let mut a = [0; N];
    r.read_exact(&mut a)?;
    Ok(a)
}

pub fn magic(r: &mut impl Read, expected: &[u8]) -> Result<()> {
    let mut b = vec![0; expected.len()];
    r.read_exact(&mut b)?;
    ensure!(b == expected, "wrong file, protocol version or quality policy");
    Ok(())
}

pub fn eof(r: &mut impl Read) -> Result<()> {
    ensure!(r.read(&mut [0; 1])? == 0, "unexpected trailing bytes");
    Ok(())
}

pub fn load<T: CanonicalDeserialize>(path: &Path) -> Result<T> {
    let mut f = open(path)?;
    let t = T::deserialize_compressed(&mut f)?;
    eof(&mut f)?;
    Ok(t)
}

pub fn save<T: CanonicalSerialize>(path: &Path, obj: &T) -> Result<()> {
    let mut w = create(path)?;
    obj.serialize_compressed(&mut w)?;
    Ok(w.flush()?)
}

pub fn fixed_key(path: &Path) -> Result<[u8; 32]> {
    let mut f = open(path)?;
    let key = bytes(&mut f)?;
    eof(&mut f)?;
    Ok(key)
}

pub struct Manifest {
    pub nonce: u128,
    pub n: u16,
    pub roots: Vec<Fr>,
    pub wire: Vec<u8>,
}

impl Manifest {
    pub fn read(r: &mut impl Read) -> Result<Self> {
        magic(r, MANIFEST)?;
        let challenge: [u8; 16] = bytes(r)?;
        let n = u16::from_le_bytes(bytes(r)?);
        ensure!(n != 0, "empty session");
        let mut wire = Vec::with_capacity(MANIFEST.len() + 18 + usize::from(n) * 34 + 64);
        wire.extend_from_slice(MANIFEST);
        wire.extend_from_slice(&challenge);
        wire.extend_from_slice(&n.to_le_bytes());
        let start = wire.len();
        wire.resize(start + usize::from(n) * 34 + 64, 0);
        r.read_exact(&mut wire[start..])?;
        let mut roots = Vec::with_capacity(usize::from(n));
        for (i, rec) in wire[start..wire.len()-64].chunks_exact(34).enumerate() {
            ensure!(rec[..2] == (i as u16).to_le_bytes(), "missing or out-of-order index");
            roots.push(Fr::deserialize_compressed(&rec[2..])?);
        }
        Ok(Self { n, nonce: u128::from_le_bytes(challenge), roots, wire })
    }

    pub fn authenticate(&self, key: &VerifyingKey, expected_nonce: u128, expected_n: u16) -> Result<()> {
        ensure!(self.nonce == expected_nonce && self.n == expected_n, "unexpected challenge or session length");
        let (msg, sig) = self.wire.split_at(self.wire.len() - 64);
        key.verify_strict(msg, &Signature::from_slice(sig)?)?;
        Ok(())
    }
}

pub enum Source {
    Fixture,
    Recording { text: BufReader<File>, line: String },
}

impl Source {
    fn next(&mut self, index: u16, blind: Fr) -> Result<Window> {
        match self {
            Self::Fixture => Ok(Window::synthetic(index, blind)),
            Self::Recording { text, line } => {
                let mut slots = [0u32; SLOTS];
                for (t, slot) in slots.iter_mut().enumerate() {
                    line.clear();
                    ensure!(text.read_line(line)? > 0, "short recording at window {index}, slot {t}");
                    let token = line.strip_suffix('\n').unwrap_or(line);
                    let token = token.strip_suffix('\r').unwrap_or(token);
                    if token == "-" { continue; }
                    let value: i32 = token.parse().with_context(|| format!("bad sample at window {index}, slot {t}"))?;
                    ensure!((-8_388_608..=8_388_607).contains(&value), "sample out of 24-bit range at window {index}, slot {t}");
                    *slot = VALID | ((value as u32) & (VALID - 1));
                }
                Ok(Window { slots, blind })
            }
        }
    }

    fn finish(&mut self) -> Result<()> {
        if let Self::Recording { text, .. } = self { eof(text)?; }
        Ok(())
    }
}

// A development surrogate for a recorder inside the acquisition trust boundary.
// The standalone prover does not possess the signing key.
pub fn capture(sk_path: &Path, nonce: u128, n: u16, mut source: Source, dir: &Path) -> Result<()> {
    ensure!(n > 0, "empty session");
    let sk = SigningKey::from_bytes(&fixed_key(sk_path)?);
    fs::create_dir(dir).context("capture output directory must not exist")?;
    let mut witness = create(&dir.join("witness.bin"))?;
    witness.write_all(WITNESS)?;
    let mut msg = Vec::with_capacity(MANIFEST.len() + 18 + usize::from(n) * 34);
    msg.extend_from_slice(MANIFEST);
    msg.extend_from_slice(&nonce.to_le_bytes());
    msg.extend_from_slice(&n.to_le_bytes());
    for index in 0..n {
        let w = source.next(index, Fr::rand(&mut OsRng))?;
        msg.extend_from_slice(&index.to_le_bytes());
        w.root(nonce, index).serialize_compressed(&mut msg)?;
        w.blind.serialize_compressed(&mut witness)?;
        for slot in w.slots { witness.write_all(&slot.to_le_bytes())?; }
    }
    source.finish()?;
    witness.flush()?;
    let sig = sk.sign(&msg);
    let mut manifest = create(&dir.join("manifest.bin"))?;
    manifest.write_all(&msg)?;
    manifest.write_all(&sig.to_bytes())?;
    Ok(manifest.flush()?)
}

pub fn read_window(r: &mut impl Read) -> Result<Window> {
    let blind = Fr::deserialize_compressed(&mut *r)?;
    let mut slots = [0; SLOTS];
    for s in &mut slots {
        *s = u32::from_le_bytes(bytes(r)?);
        if *s != 0 && !(VALID..2*VALID).contains(s) { bail!("noncanonical witness slot"); }
    }
    Ok(Window { slots, blind })
}
