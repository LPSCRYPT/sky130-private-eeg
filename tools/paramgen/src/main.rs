use ark_bls12_381::Fr;
use ark_crypto_primitives::sponge::poseidon::find_poseidon_ark_and_mds;
use ark_ff::{BigInteger, PrimeField};
use std::{env, fs::File, io::{BufWriter, Write}, path::PathBuf};

fn main() -> std::io::Result<()> {
    let out = PathBuf::from(env::args_os().nth(1).expect("pass existing output directory"));
    let (ark, mds) = find_poseidon_ark_and_mds::<Fr>(255, 2, 8, 57, 0);
    for (name, rows) in [("ark.hex", ark), ("mds.hex", mds)] {
        let mut file = BufWriter::new(File::create(out.join(name))?);
        for value in rows.into_iter().flatten() {
            for byte in value.into_bigint().to_bytes_be() { write!(file, "{byte:02x}")?; }
            writeln!(file)?;
        }
        file.flush()?;
    }
    Ok(())
}
