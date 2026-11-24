use ark_bls12_381::Fr;
use ark_relations::r1cs::{ConstraintSynthesizer, ConstraintSystem};

use crate::{circuit::Step, model::{count_commit, Window, NEG_RAIL, POS_RAIL, SLOTS, VALID}, wire::{self, Manifest}};

fn step(window: Window, index: u16, before: u16, claimed_pass: bool) -> Step {
    let nonce = 42;
    let root = window.root(nonce, index);
    let salts = [Fr::from(11u8), Fr::from(12u8)];
    let links = [count_commit(nonce, index, before, salts[0]), count_commit(nonce, index + 1, before + u16::from(claimed_pass), salts[1])];
    Step { nonce, index, root, links, window, before, salts }
}

fn satisfied(step: Step) -> bool {
    let cs = ConstraintSystem::new_ref();
    step.generate_constraints(cs.clone()).unwrap();
    cs.is_satisfied().unwrap()
}

#[test]
fn rails_are_exact_codes_and_every_slot_counts() {
    let mut w = Window { slots: [VALID | (NEG_RAIL+1); SLOTS], blind: Fr::from(10u8) };
    w.slots[0] = VALID | (POS_RAIL-1);
    for (t, raw) in [NEG_RAIL, POS_RAIL, NEG_RAIL, POS_RAIL].into_iter().enumerate() { w.slots[t+10] = VALID | raw; }
    assert!(w.pass());
    assert!(satisfied(step(w.clone(), 17, 11, true)));
    w.slots[SLOTS-1] = VALID | POS_RAIL;
    assert!(!w.pass());
    assert!(satisfied(step(w.clone(), 17, 11, false)));
    assert!(!satisfied(step(w.clone(), 17, 11, true)));
    w.slots[SLOTS-1] = 0;
    assert!(!w.pass());
    assert!(satisfied(step(w.clone(), 17, 11, false)));
    assert!(!satisfied(step(w, 17, 11, true)));
}

#[test]
fn mismatched_openings_and_illegal_prefixes_fail() {
    let w = Window::synthetic(0, Fr::from(100u8));
    let mut st = step(w.clone(), 9, 3, true);
    st.window.slots.swap(10, 20);
    assert!(!satisfied(st));
    let mut st = step(w.clone(), 9, 3, true);
    st.salts[0] += Fr::from(1u8);
    assert!(!satisfied(st));
    assert!(!satisfied(step(w.clone(), 9, 10, true)));
    // The input decoder rejects this form, and the circuit must reject it too.
    let mut invalid = w;
    invalid.slots[0] = 123;
    assert!(!satisfied(step(invalid, 9, 0, false)));
}

#[test]
fn decoder_rejects_bad_indices_field_encodings_and_witness_slots() {
    let mut bytes = Vec::from(wire::MANIFEST);
    bytes.extend_from_slice(&[0; 16]);
    bytes.extend_from_slice(&1u16.to_le_bytes());
    let end_header = bytes.len();
    bytes.extend_from_slice(&[0; 2 + 32 + 64]);
    assert!(Manifest::read(&mut bytes.as_slice()).is_ok()); // syntax only
    bytes[end_header] = 1;
    assert!(Manifest::read(&mut bytes.as_slice()).is_err());
    bytes[end_header] = 0;
    bytes[end_header+2..end_header+34].fill(0xff);
    assert!(Manifest::read(&mut bytes.as_slice()).is_err());
    let mut witness = vec![0; 32 + SLOTS * 4];
    witness[32] = 1;
    assert!(wire::read_window(&mut witness.as_slice()).is_err());
}
