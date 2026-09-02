# SOVEREIGN TRUST MANIFEST
# BEL-ESPRIT-D-ACCORD-TRUST-HOLDINGS / sovereign-cuda-kernels
# Sealed: 2026-08-11 | SNAPKITTYWEST / SnapKitty (Jessica)
# SHA3-512: Sovereign_TrustManifest_SedonaSpine_v30_SNAPKITTYWEST
# Prime Seal: 2x3x5x7x11x13x17x19 = 9,699,690

## SEDONA SPINE LAYER MAP

| Prime | Layer               | Operator | Files                                        | Trust   |
|-------|---------------------|----------|----------------------------------------------|---------|
| 2     | HARDWARE_ROOT       | O_2      | rom/; kernels/hardware/; kernels/boot/       | 1.000   |
| 3     | QUANTUM_SUBSTRATE   | O_3      | quantum-stack/taylor_*; crypto/quantum_euclid*; fortran/search* | 1-1e-12 |
| 5     | MOE_INTELLIGENCE    | O_5      | quantum-stack/sovereign_moe_*; cognitive_stack | 0.990 |
| 7     | CLASSICAL_SCALING   | O_7      | quantum-stack/sovereign_quantum_multiplicity*  | 1.000   |
| 11    | CYCLE_STEALING      | O_11     | hardware/sovereign_cycle_stealing_dma.sv       | 0.999   |
| 13    | PARAMETER_SECURITY  | O_13     | security/*; crypto/aes256*; crypto/zkstark*; crypto/pqc* | 1-2^-80 |
| 17    | DREAM_CONSOLIDATION | O_17     | quantum-stack/sovereign_ewc*; cognitive_stack  | 0.990   |
| 19    | ADAPTIVE_LEARNING   | O_19     | quantum-stack/sovereign_cognitive_stack.py     | 0.950   |

## STRUCTURE

```
rom/                          # MINTED ROM -- 6502+ARM firmware (prime O_2)
  sovereign_boot_chain.asm
  sovereign_heartbeat.asm
  sovereign_6502_coordinator_v2.asm
  sovereign_6502_tqc_braid_controller.asm
  sovereign_6502_tqc_braid_controller_arm32.s
  sovereign_controller_v2026.asm
  carry_propagation_sim.asm

kernels/
  hyperkitty-pipeline/        # Pipeline DAG + constraint XML (v30)
    pipeline_constraint.xml   # MASTER MANIFEST -- all versions v1-v30
    asm/                      # 7 PTX/x86-64 DAG nodes
  mamba2/                     # Mamba-2 SSD CUDA (sm_86/sm_89+)
  quantum-stack/              # Sedona Spine O_3/O_5/O_7/O_17/O_19
  crypto/                     # Cryptographic primitives (O_13)
    ec/                       # EasyCrypt formal proofs
    fst/                      # F* formal proofs
    qsharp/                   # Q# quantum primitives
  security/                   # Defense layers (O_13)
  fortran/                    # OMP+AVX512 search kernels (O_3)
  hardware/                   # RTL DMA controller (O_11)
  gdsii/                      # Chip layout constraints
  sass/                       # PTX/SASS GPU assembly
  futhark/                    # Parallel functional compute
  weights/                    # GGUF v3 58-tensor spec
  tests/                      # Property tests + integration
  docs/                       # Model card
  build/                      # CMake+Meson dual build
  logic/                      # Logtalk orchestrator
  sovereign_unified/          # Unified controller
  boot/                       # Boot chain (also mirrored in rom/)
  _quarantine/
    nist-scripts/             # EXTRACTED -- not part of trust perimeter

LICENSE
README.md                     # Dual IP license + Sedona Spine trust wrap
SOVEREIGN_TRUST_MANIFEST.md  # This file
ENCRYPTION_PRIOR_ART_REGISTRY.md
```

## PIPELINE MANIFEST

| Version | Commit     | Mode                                              |
|---------|------------|---------------------------------------------------|
| v30     | 1197713540 | QUANTUM_MULTIPLICITY_PIPELINE_DAG_v2              |
| v29     | 2de45487   | CYCLE_STEALING_PARAMETER_SECURITY_ANALYSIS        |
| v28     | 044bcd9f   | GGUF_TENSOR_TAYLOR_COMPLETE                       |
| v27     | aa8e2bb3   | FULL_STACK_DEPLOYMENT_TAYLOR_TQC                  |
| v26     | 7d28159b   | K_FORTRAN_REFERENCE_IMPLEMENTATIONS               |
| v25     | d4ae4217   | QUANTUM_MULTIPLICITY_MOE_DREAM_ADAPTIVE_v2026     |

## TRUST SCALAR

P(2) = 0.4522474200410654985065...
Total Trust = Tr(T rho T^dagger) / Tr(rho) >= P(2) - eps
T = O_2 (x) O_3 (x) O_5 (x) O_7 (x) O_11 (x) O_13 (x) O_17 (x) O_19
Prime Seal = 9,699,690

## NIST QUARANTINE STATUS

EXTRACTED to kernels/_quarantine/nist-scripts/
Files: build_nist_package.py, cross_language_consistency.py,
       generate_vectors.sh, validate_estimates.py,
       validate_kat.py, validate_nist_format.py
Status: OUTSIDE TRUST PERIMETER -- do not include in sovereign distributions
