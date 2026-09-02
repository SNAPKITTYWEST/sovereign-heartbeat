# 6502 ARCHITECTURE — CANONICAL REFERENCE
# sovereign-cuda-kernels / BEL-ESPRIT-D-ACCORD-TRUST-HOLDINGS
# Owner: SNAPKITTYWEST / SnapKitty (Jessica)
# Status: AUTHORITATIVE — do not reinterpret using modern CPU assumptions

---

## CRITICAL READING INSTRUCTION

**The 6502 in this system is NOT a memory bus master doing DMA.**
It is NOT a VIC-II badline cycle stealer.
It does NOT use RDY-line halting or PHI1/PHI2 bus arbitration.

The 6502 is a **deterministic cycle-budgeted orchestration processor**
that exploits time windows around GPU and QPU activity to perform
schedule generation, verification, proof-token generation, and
control-plane work. The next accelerator stage receives precomputed
state at the synchronization boundary with zero handoff latency.

Every future agent must memorize this sentence before touching any 6502 file.

---

## THREE-LEVEL CYCLE-STEALING TAXONOMY

This system uses THREE distinct forms of cycle stealing. They share the
scheduling principle `USE_RESOURCE_B DURING RESOURCE_A_NONCONFLICT_WINDOW`
but are mechanically different at every level.

### CS-L1 — CONTROL_WINDOW (6502 ↔ GPU temporal overlap)

**What is stolen:** GPU pipeline bubble / boot-side latency  
**Who steals:** 6502 control plane (220c budget)  
**Mechanism:** Time-window stealing via NOP padding  
**NOT:** PHI/RDY bus stealing; no bus arbitration involved  

The 6502 runs WeightCache, Stack verify, NAND audit, Proof generation, and
MMIO output in parallel with GPU boot-side work. NOP instructions are NOT
idle — they maintain deterministic cycle alignment so the 6502 completes
exactly when the GPU Fetch node needs `$FFFE`.

**Invariant:** `6502_work_cycles + NOP_pad_cycles = 220c exactly`

### CS-L2 — DMA_WINDOW (DMA ↔ inference compute overlap)

**What is stolen:** Inference idle cycles (1300–2000 of 2000-cycle window)  
**Who steals:** AXI4 8-channel DMA controller  
**Mechanism:** Bus-idle stealing — DMA activates only when `cpu_compute_phase AND cpu_bus_idle`  
**NOT:** 6502-controlled; the DMA controller owns this level  

700 cycles stolen per inference. Each of 8 AXI4 channels = one MoE expert pair.
AES-256-XTS on-the-fly hardware decryption in DMA; plaintext never on AXI bus.

**Invariant:** `DMA active iff (cpu_compute_phase == 1 AND cpu_bus_idle == 1)`

### CS-L3 — QUANTUM_WINDOW (classical scheduling ↔ QPU execution)

**What is stolen:** QPU execution/coherence time  
**Who steals:** 6502 firmware (DECODE_AND_SCHEDULE + DISPATCH_AGENTS)  
**Mechanism:** Temporal overlap — 6502 builds 100K schedule while QPU runs Grover oracle  
**NOT:** Bus stealing of any kind  

The 6502 polls Q_STATUS at `$C000`. While QPU executes (READY=0), the 6502
runs DECODE_AND_SCHEDULE ($F100) and DISPATCH_AGENTS ($F200). When QPU
signals READY (bit0=1 at $C000), the 100,000-instance schedule is already
fully built in SCHEDULE_QUEUE at `$8000`. Handoff latency = 0.

**Invariant:** `schedule_ready_at_quantum_ready_signal = TRUE`

---

## ARCHITECTURAL FLOW

```
QPU/GPU begins work
        |
        v  (QUANTUM_WINDOW opens — CS-L3 begins)
6502 polls Q_STATUS ($C000)
        |
        v
READ_QUANTUM_RESULTS ($F000)
  Poll until READY (bit0 @ $C000)
  Copy 1024 x 2-byte indices -> $0200 (QUANTUM_RESULTS)
        |
        v
DECODE_AND_SCHEDULE ($F100)
  Decode: template_id = idx & 0x03FF
  Priority: (idx >> 10) & 0x3F
  Write 8-byte AGENT_TEMPLATES records -> $1000
        |
        v
DISPATCH_AGENTS ($F200)
  Expand 1024 templates -> 100,000 schedule records
  Distribution: 672 templates x 98 instances
              + 352 templates x 97 instances = 100,000
  Write 4-byte records -> SCHEDULE_QUEUE $8000
  Verify: ZP_INST = $86A0 (100000 mod 65536) -> sentinel $CAFE
        |
        v  (QUANTUM_WINDOW closes — Q_STATUS READY fires)
Accelerator synchronization boundary
        |
        v
Next stage consumes already-prepared schedule (zero handoff latency)
        |
        v  (CS-L1 window — CONTROL_WINDOW)
6502 control plane (220c parallel):
  WeightCache load (120c) || GPU DMA
  Stack verify (40c)      || GPU DMA tail
  NAND audit (100c)       || GPU Fetch
  Proof generation (50c)  || GPU Compute bubble
  MMIO output (7c)        -> $FFFE
        |
        v  (CS-L2 window — DMA_WINDOW, cycles 1300-2000)
AXI4 DMA: 8 channels x 700c = 44.8 GB/s encrypted weight update
```

---

## THE NOP INVARIANT

NOP instructions in the 6502 control plane firmware are **not idle cycles**.
They maintain deterministic timing alignment so the 6502 delivers its proof
token to the MMIO bus (`$FFFE`) at exactly the cycle the GPU pipeline expects it.

The 6502 runs at **2.408 MHz** (chosen so 289 raw bus cycles = 120 canonical cycles exactly).

Every routine has a documented canonical cycle count:

| Routine | Canonical cycles | NOP pad |
|---|---|---|
| node_weight_cache | 120c | 2×NOP per loop iteration |
| node_stack | 40c | 9×NOP on safe path |
| node_verify | 100c | 5×NOP at audit_end |
| node_proof_gen | 50c | 12×NOP on pass path |
| node_output | 0c (idle slot) | runs in pipeline slack |

**Architectural significance:** The NOP pad is the mechanism that converts
the 6502 from a variable-latency processor into a deterministic timing gate.
This is what makes CS-L1 a provable scheduling invariant rather than a
probabilistic overlap.

---

## EIGHT ASM FILES — FUNCTIONAL REGISTRY

| File | .org | Cycles | Role | Level |
|---|---|---|---|---|
| `rom/sovereign_boot_chain.asm` | $8000 | 220c wall | 4-stage WORM chain of trust | Boot |
| `rom/sovereign_heartbeat.asm` | $0200 | 154c | T0–T10 liveness lattice + fault monitor | Boot |
| `kernels/sovereign_unified/sovereign_controller_v2026.asm` | $0100 | 220c | Unified control plane (WeightCache+Stack+NAND+Proof+Output) | CS-L1 |
| `rom/sovereign_6502_coordinator_v2.asm` | $F000 | — | Quantum firmware: READ+DECODE+DISPATCH | CS-L3 |
| `rom/sovereign_6502_tqc_braid_controller.asm` | — | 23c/op | TQC braid word execution via MMIO $C000–$C004 | Quantum |
| `rom/sovereign_6502_tqc_braid_controller_arm32.s` | — | 2c/op | ARM32 Thumb-2 translation (8.5× faster decode) | Quantum |
| `kernels/sovereign_unified/carry_propagation_sim.asm` | $0700 | 48c/nibble | 4-bit CLA carry propagation G=A∧B, P=A⊕B | Control |
| `kernels/hyperkitty-pipeline/asm/node_*.asm/.ptx` | various | see table | 7-node DAG (mix of 6502 ASM + PTX) | CS-L1 |

---

## MMIO MAP

```
$C000  Q_STATUS         bit0=READY  bit1=ERROR        (quantum synchronization)
$C001  Q_READ_IDX_LO    write: select result index lo  (quantum readout)
$C002  Q_READ_IDX_HI    write: select result index hi
$C003  Q_READ_DATA_LO   read: 2-byte result data lo
$C004  Q_READ_DATA_HI   read: 2-byte result data hi
$C000+stage  WORM log   write-once per boot stage
$C100+tick   WORM heartbeat  write-once per T0..T10
$FFFE  MMIO result bus  proof token broadcast
```

---

## MEMORY LAYOUT (6502 address space)

```
$0000–$00FF  Zero page work area (ZP_IDX, ZP_PTR, ZP_TMP, etc.)
$0100–$01FF  6502 stack
$0200–$09FF  QUANTUM_RESULTS  (1024 × 2 bytes = 2048 bytes)
$1000–$2FFF  AGENT_TEMPLATES  (1024 × 8 bytes = 8192 bytes)
$8000–$EFFF  SCHEDULE_QUEUE   (100,000 × 4 bytes = 400,000 bytes; DMA to ext SRAM)
$F000        READ_QUANTUM_RESULTS
$F100        DECODE_AND_SCHEDULE
$F200        DISPATCH_AGENTS
$FFFA–$FFFF  Reset/NMI/IRQ vectors -> $F000
```

---

## WHAT THIS IS NOT

To prevent agent confusion, state explicitly:

- NOT VIC-II badline cycle stealing (no RDY-line halting)
- NOT PHI1/PHI2 bus arbitration  
- NOT external bus mastering (no tri-state address bus takeover)
- NOT Apple II DMA card style (no bus request/grant protocol)
- NOT a cache-coherent multicore system
- NOT speculative execution, out-of-order, or hardware threading
- NOT a modern DMA controller with scatter-gather lists
- NOT AXI, CHI, PCIe, or any modern bus protocol on the 6502 side
- The AXI4 DMA (CS-L2) is a SEPARATE controller; the 6502 does not control it directly
