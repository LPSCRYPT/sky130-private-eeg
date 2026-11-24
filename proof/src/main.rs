mod circuit;
mod model;
mod session;
mod wire;
#[cfg(test)]
mod tests;

use std::{env, path::Path};
use anyhow::{bail, ensure, Result};
use rand::{rngs::OsRng, RngCore};

fn nonce(s: &str) -> Result<u128> {
    Ok(u128::from_le_bytes(model::hex(s.as_bytes()).map_err(anyhow::Error::msg)?))
}

fn count(s: &str) -> Result<u16> {
    let n = s.parse()?;
    ensure!(n != 0, "N must be in 1..=65535");
    Ok(n)
}

fn main() -> Result<()> {
    let args: Vec<_> = env::args().skip(1).collect();
    let args: Vec<_> = args.iter().map(String::as_str).collect();
    match args.as_slice() {
        ["roots"] => model::print_fixture_roots(),
        ["challenge"] => {
            let mut b = [0u8; 16];
            OsRng.fill_bytes(&mut b);
            for x in b { print!("{x:02x}"); }
            println!();
        }
        ["setup", dir] => session::setup(Path::new(dir))?,
        ["fixture", sk, ch, n, dir] => wire::capture(Path::new(sk), nonce(ch)?, count(n)?, wire::Source::Fixture, Path::new(dir))?,
        ["capture", sk, ch, n, text, dir] => {
            let src = wire::Source::Recording { text: wire::open(Path::new(text))?, line: String::new() };
            wire::capture(Path::new(sk), nonce(ch)?, count(n)?, src, Path::new(dir))?;
        }
        ["prove", pk, m, w, out] => session::prove(Path::new(pk), Path::new(m), Path::new(w), Path::new(out))?,
        ["verify", vk, device, ch, n, b] => {
            let total = session::verify(Path::new(vk), Path::new(device), nonce(ch)?, count(n)?, Path::new(b))?;
            println!("verified: {total} of {n} windows passed QC01");
        }
        _ => bail!("usage: eeg-proof <command>\n  roots\n  challenge\n  setup NEW_KEY_DIR\n  fixture DEVICE_SK CHALLENGE N NEW_PRIVATE_DIR\n  capture DEVICE_SK CHALLENGE N SLOTS_TEXT NEW_PRIVATE_DIR\n  prove PK MANIFEST WITNESS NEW_BUNDLE\n  verify PINNED_VK PINNED_DEVICE_PUB EXPECTED_CHALLENGE EXPECTED_N BUNDLE\nCHALLENGE: 16 bytes as 32 lowercase hex digits in wire order. SLOTS_TEXT: one signed 24-bit decimal integer or '-' per line."),
    }
    Ok(())
}
