# Sovereign Heartbeat Lattice

[![License: Sovereign](https://img.shields.io/badge/License-Sovereign%20Node%20Key%20Only-critical.svg)](#license)
[![Hardware](https://img.shields.io/badge/Hardware-65C02%20%40%202.408MHz-blue.svg)](#hardware)
[![Trust](https://img.shields.io/badge/Trust-Sedona%20Spine%20O__2%20%241.000-purple.svg)](#provenance)

> **The 6502 is not a CPU. It is a timing gate. 12ps per gate, 120ps to prove the OS is alive.**

Cherry-picked from `sovereign-cuda-kernels` control repo. Proprietary headers preserved for prior art.

---

## What This Is

A deterministic 65C02 liveness lattice that proves `Sovereign_OS_Active` via physical gate delay, not software polling.

- **T0–T10 lattice**: 11 states at 12ps/gate (0ps → 120ps total)
- **WORM EKG**: Per-tick seal at `$C100+X`, tamper-evident log
- **NAND liveness proof**: `Sovereign_Active = NAND(NOT(Heartbeat_Stable), NOT(Heartbeat_Stable)) == 1`
- **220c wall budget**: Boot chain + heartbeat overlap with GPU HMMA

This is hardware root-of-liveness for any sovereign runtime — enclaves, encrypted weight transport, quantum dispatch handoff.

---

## Lattice

| Tick | Time | State | Code | Seal |
|------|------|-------|------|------|
| T0 | 0ps | S_RESET_DISCHARGE | 0x00 | — |
| T1 | 12ps | NAND_ROOT_FIRE | 0x01 | `$C100` |
| T2 | 24ps | SASS_LOAD_Smem | 0x02 | `$C101` |
| T3 | 36ps | Logtalk_IR_SYNC | 0x03 | `$C102` |
| T4 | 48ps | SASS_MMA_T0 | 0x04 | `$C103` |
| T5 | 60ps | SASS_MMA_T1 | 0x05 | `$C104` |
| T6 | 72ps | SASS_MMA_T2 | 0x06 | `$C105` |
| T7 | 84ps | SASS_MMA_T3 | 0x07 | `$C106` |
| T8 | 96ps | Roof_Crossover_Hit | 0x08 | `$C107` |
| T9 | 108ps | WORM_Chain_Locked | 0x09 | `$C108` |
| T10 | 120ps | Sovereign_OS_Active | 0x0A | `$C10A` + `$C1FF` + `$FFFE=0xFF` |

Invariant: `FORALL t in [0,10]: Symmetry(Cycle[t])==TRUE AND Entropy==0.00 QED`

---

## Boot Chain (4 stages, 168c + 52c GPU parallel = 220c wall)

```
ROOT_OF_TRUST (~29c)  SEI/CLD, S_STATE=$01 TRUSTED, S_FAULT=$00, WORM $C000
  → STAGE1 Physical→6502 (~28c)  HASH_PHYS check $A0=$D7, WORM $C001
  → STAGE2 Control→Logtalk (~34c)  NAND(S_PROOFT, S_FAULT)==1, WORM $C002
  → STAGE3 Logtalk→Roof (~34c)  Mercury_Det(Sovereign_IR), WORM $C003, HMMA.16.8.8
  → STAGE4 Roof→OS (~43c)  HASH_OS check $A4=$F1, WORM $C010=0xFF, JMP $0200
```

Zero-page contract:

| Addr | Name | Value | Meaning |
|------|------|-------|---------|
| `$00` | S_STATE | 0x01 | TRUSTED |
| `$01` | S_PROOFT | 0xFF | Proof token |
| `$02` | S_SSTACK | — | Shadow stack |
| `$FE` | S_FAULT | 0x00 | No fault |
| `$10` | HB_INDEX | 0x00→0x0B | Tick counter |
| `$11` | HB_STATE | 0x00→0x0A | Lattice state |
| `$12` | HB_STATUS | 0xFF→0x01 | 0x01=ESTABLISHED_AND_EXECUTING |
| `$FFFE` | MMIO | 0xFF/0x00 | Active/fault broadcast |

---

## Files

| File | Source | Purpose |
|------|--------|---------|
| `sovereign_heartbeat.asm` | `rom/sovereign_heartbeat.asm` | Canonical 169-line lattice (proprietary header + seal) |
| `sovereign_boot_chain.asm` | `kernels/boot/sovereign_boot_chain.asm` | 195-line WORM boot chain, `.org $8000`, JMP $0200 handoff |
| `sovereign_heartbeat_boot_mirror.asm` | `kernels/boot/sovereign_heartbeat.asm` | Header-free mirror (strip for open forks) |
| `6502_ARCHITECTURE.md` | `6502_ARCHITECTURE.md` | Three-level cycle-stealing taxonomy, 220c budget, MMIO map |
| `SOVEREIGN_TRUST_MANIFEST.md` | `SOVEREIGN_TRUST_MANIFEST.md` | Sedona Spine O_2 HARDWARE_ROOT prime=2, trust 1.000 |
| `sovereign_6502_coordinator_v2_reference.asm` | `rom/sovereign_6502_coordinator_v2.asm` | 452-line quantum dispatch reference (CS-L3) |

---

## Hardware Mapping

**Artix-7 BYECODE integration** (see `mfma-hill-cipher/rtl/artix7/`):

```
IBUFDS → MMCM (100MHz) → byecode_bram → byecode_artix7_core
                                      ↕
                              Heartbeat lattice monitors
                              WORM $C100 EKG polled via MMIO
```

The lattice runs as co-processor to the BYECODE soft-processor. `HB_STATUS` gates `byecode_artix7_core` fetch enable.

**Cycle budget:**

| Component | Cycles | Notes |
|-----------|--------|-------|
| Heartbeat init | 42c | Verify S_STATE/S_PROOFT/S_FAULT |
| Lattice loop | 39c/tick ×11 = 429c sequential | Overlapped with HMMA → 220c wall |
| T10 complete | 28c | NAND proof + WORM seals |
| Runtime loop | ∞ | Fault-guarded NOP poll |

---

## Build

```bash
# Assemble (ca65)
ca65 --cpu 65c02 sovereign_boot_chain.asm -o boot.o
ca65 --cpu 65c02 sovereign_heartbeat.asm -o hb.o
ld65 -C mem.cfg boot.o hb.o -o sovereign_heartbeat.bin

# Verify WORM seals
python tools/verify_worm.py --base 0xC100 --ticks 11 --expect-entropy 0.00
```

---

## Relation to Stack

| Repo | Relation |
|------|----------|
| `ahmad-foundations` | Math foundations (Lean 4, 30 theorems). Heartbeat references `ahmad-foundations/black-hole/BlackHoleGravity.lean` for formal time/entropy model |
| `mfma-hill-cipher` | Consumer — Artix-7 BYECODE core (`rtl/artix7/`) polls heartbeat for liveness before executing `V/R + V³` analog tape |
| `sovereign-cuda-kernels` | Control repo (mass repo). This repo is cherry-picked substrate fork. Do not push to control repo |
| `sovereign-qra` | Sibling fork — heartbeat provides `HB_STATUS` trust for QRA routing decisions |

---

## License

**SOVEREIGN NODE KEY ONLY** — see `LICENSE`. Proprietary header `SNAPKITTYWEST-PROPRIETARY-2026-001` preserved for prior art. SHA3-512 WORM anchored. Unauthorized clones violate sovereign IP.

Contact: **Ahmad Ali Parr** <ahmedparr93@gmail.com> · Bel Esprit D'Accord Irrevocable Trust

---

*Possession is not a license. The lattice proves liveness. The WORM proves the lattice.*
