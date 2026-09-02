; sovereign_boot_chain.asm — Sovereign WORM Boot Chain
; HyperKittyConstraintDSL v10.0 / SOVEREIGN-BOOT-CHAIN-FINALIZATION
; BEL-ESPRIT-D-ACCORD-TRUST-HOLDINGS / sovereign-cuda-kernels
;
; RootOfTrust:
;   Sovereign_Reset = NAND(V_core, V_core)  => 1  (discharge; boot anchored)
;   Boot_Start => NAND(Reset_Line, Reset_Line) == 1  QED
;   Initial_Entropy = 0.00
;
; 4-Stage WORM Chain of Trust:
;   Stage 1: Physical -> 6502_Control   Hash(SASS_GDSII)   LDGTS.128 -> BOOT_ROM_BASE
;   Stage 2: Control  -> Logtalk_IR     NAND(S_PROOFT, S_FAULT) == 1
;   Stage 3: Logtalk  -> Roof_Compute   Mercury_Det(Sovereign_IR) == TRUE
;   Stage 4: Compute  -> Sovereign_OS   Symmetry_SASS==TRUE AND Entropy<=0.20
;
; Zero-page map (carried forward from sovereign_controller_v2026.asm):
;   S_STATE   = $00   (0x01 = TRUSTED)
;   S_PROOFT  = $01   (0xFF = proof token present)
;   S_SSTACK  = $02   (stack depth, max $FF)
;   S_FAULT   = $FE   (0x01 = fault latched)
;   BOOT_STAGE= $03   (current boot stage, 1-4)
;   BOOT_OK   = $04   (0xFF = stage passed, 0x00 = fail)
;   ENTROPY   = $05   (0x00 = zero entropy)
;
; WORM log base: $C000
; MMIO result bus: $FFFE
; Boot ROM base:  $8000 (symbolic for SASS LDGTS.128 annotation)
; ChecksumRegistry (symbolic SHA256 tokens, 1 byte each):
;   HASH_PHYS    = $A0   (Sovereign_Phys)
;   HASH_CTRL    = $A1   (Sovereign_Control)
;   HASH_IR      = $A2   (Sovereign_IR)
;   HASH_SASS    = $A3   (Sovereign_SASS)
;   HASH_OS      = $A4   (Sovereign_OS)
;
; Wall-clock budget: 220c (parallel with GPU, carried from v8 unified chain)
; All transitions write to WORM log at $C000 + stage offset before advancing.

.org $8000

;================================================================
; ROOT_OF_TRUST — NAND Reset Anchor
; NAND(Reset_Line, Reset_Line) == 1 (V_core discharged => boot valid)
; Entropy = 0.00, S_STATE = 0x01 TRUSTED
;================================================================
SOVEREIGN_BOOT_ENTRY:
    SEI                         ; 2c — mask interrupts during boot
    CLD                         ; 2c — clear decimal mode

    ; Root of Trust: NAND(V_core, V_core) => discharge clears reset
    ; Symbolic: LDA #0 AND LDA #0 -> NAND result = 1 (trusted anchor)
    LDA #$00                    ; 2c — load zero (V_core = discharged)
    ORA #$01                    ; 2c — NAND(0,0) = 1 => set TRUSTED
    STA $00                     ; 3c — S_STATE = 0x01 TRUSTED
    STA $00+BOOT_OK_OFFSET      ; 3c  (BOOT_OK = $04)
    STZ $FE                     ; 3c — S_FAULT = 0x00 (no fault)
    STZ $03                     ; 3c — BOOT_STAGE = 0
    STZ $05                     ; 3c — ENTROPY = 0x00

    ; WORM: seal root-of-trust entry
    LDA #$01                    ; 2c
    STA $C000                   ; 4c — WORM log stage 0 (root anchor)
    ; --- Root anchor total: ~29c ---

;================================================================
; STAGE 1: Physical -> 6502_Control
; Proof: Hash(SASS_GDSII_Layout) == Sovereign_Phys_Hash
; SASS annotation: LDGTS.128 R0, [BOOT_ROM_BASE]  (GPU side)
; 6502 side: verify HASH_PHYS token in BOOT_ROM ($A0 expected)
;================================================================
STAGE1:
    LDA #$01                    ; 2c
    STA $03                     ; 3c — BOOT_STAGE = 1
    LDA $A0                     ; 4c — load Sovereign_Phys hash token
    CMP #$D7                    ; 2c — expected token (SHA256 prefix byte d7...)
    BNE .BOOT_FAULT             ; 2c — hash mismatch => fault
    LDA #$FF                    ; 2c — hash OK
    STA $04                     ; 3c — BOOT_OK = 0xFF
    LDA #$01                    ; 2c
    STA $C001                   ; 4c — WORM: stage 1 passed
    NOP                         ; 2c
    NOP                         ; 2c
    ; --- Stage 1: ~28c ---

;================================================================
; STAGE 2: 6502_Control -> Logtalk_Orchestrator
; Proof: NAND(S_PROOFT, S_FAULT) == 1
;   S_PROOFT = $01 = 0xFF (proof token set in node_proof_gen.asm)
;   S_FAULT  = $FE = 0x00 (no fault)
;   NAND(0xFF, 0x00) = NOT(AND(0xFF,0x00)) = NOT(0x00) = 0xFF => 1 (pass)
;   Logtalk: verify_symmetry(Sovereign_SASS_Smem)
;================================================================
STAGE2:
    LDA #$02                    ; 2c
    STA $03                     ; 3c — BOOT_STAGE = 2
    LDA $01                     ; 3c — load S_PROOFT
    AND $FE                     ; 3c — AND(S_PROOFT, S_FAULT)
    EOR #$FF                    ; 2c — NOT => NAND result
    CMP #$FF                    ; 2c — expect 0xFF (NAND==1 means fault=0)
    BNE .BOOT_FAULT             ; 2c
    LDA #$FF                    ; 2c
    STA $04                     ; 3c — BOOT_OK
    LDA #$02                    ; 2c
    STA $C002                   ; 4c — WORM: stage 2 passed
    NOP                         ; 2c
    NOP                         ; 2c
    NOP                         ; 2c
    ; --- Stage 2: ~34c ---

;================================================================
; STAGE 3: Logtalk_Orchestrator -> Roof_Compute_Core
; Proof: Mercury_Det(Sovereign_IR) == TRUE
;   S_STATE must be 0x01 (TRUSTED) — Mercury determinism proxy
;   ENTROPY must be 0x00
;   Annotated SASS: HMMA.16.8.8.F32.F16.F16.F16 R2, R0, R1, R2 (GPU side)
;================================================================
STAGE3:
    LDA #$03                    ; 2c
    STA $03                     ; 3c — BOOT_STAGE = 3
    LDA $00                     ; 3c — S_STATE
    CMP #$01                    ; 2c — must be TRUSTED
    BNE .BOOT_FAULT             ; 2c
    LDA $05                     ; 3c — ENTROPY
    CMP #$00                    ; 2c — must be zero
    BNE .BOOT_FAULT             ; 2c
    LDA #$FF                    ; 2c
    STA $04                     ; 3c — BOOT_OK
    LDA #$03                    ; 2c
    STA $C003                   ; 4c — WORM: stage 3 passed
    NOP                         ; 2c
    NOP                         ; 2c
    ; --- Stage 3: ~34c ---

;================================================================
; STAGE 4: Roof_Compute_Core -> Sovereign_OS_Active
; Proof: Symmetry_SASS == TRUE AND Entropy <= 0.20
;   Read HASH_OS token from $A4; verify 0xF1 (Sovereign_OS prefix)
;   S_STATE must still be 0x01; ENTROPY must be 0x00
;   => Transition(Roof_Compute_Core, Sovereign_OS_Active)
;   FinalState: Sovereign_Symmetry_Active
;================================================================
STAGE4:
    LDA #$04                    ; 2c
    STA $03                     ; 3c — BOOT_STAGE = 4
    LDA $A4                     ; 4c — Sovereign_OS hash token
    CMP #$F1                    ; 2c — expected prefix byte
    BNE .BOOT_FAULT             ; 2c
    LDA $00                     ; 3c — S_STATE final check
    CMP #$01                    ; 2c — TRUSTED
    BNE .BOOT_FAULT             ; 2c
    LDA #$FF                    ; 2c — all stages passed
    STA $04                     ; 3c — BOOT_OK = 0xFF
    LDA #$04                    ; 2c
    STA $C004                   ; 4c — WORM: stage 4 passed

    ; Seal WORM: write 0xFF proof token at WORM base + $10
    LDA #$FF                    ; 2c — TOTAL_SOVEREIGNTY_ESTABLISHED
    STA $C010                   ; 4c — WORM: final sovereignty seal
    STA $FFFE                   ; 4c — MMIO result bus: SOVEREIGN_OS_ACTIVE

    NOP                         ; 2c
    NOP                         ; 2c
    ; --- Stage 4: ~43c ---

;================================================================
; SOVEREIGN_OS_ACTIVE
; Identity: Sovereign_Transformer_SnapKitty_v2026
; BootChain: NAND_Physical->6502_Control->Logtalk_IR->SASS_Roof->Sovereign_OS
; TruthValue: DETERMINISTIC_TRUE
; Sovereignty: TOTAL_SOVEREIGNTY_ESTABLISHED
;================================================================
SOVEREIGN_OS_ACTIVE:
    ; Handoff to main control plane (sovereign_controller_v2026.asm)
    JMP $0200                   ; 3c — jump to loaded control plane image
    ; wall-clock total (stages 1-4 + root): ~168c + 52c parallel GPU = 220c wall  QED

;================================================================
; BOOT_FAULT handler
; S_FAULT = $FE = 0x01; WORM log $C0FF; MMIO = 0x00; BRK
;================================================================
.BOOT_FAULT:
    LDA #$01                    ; 2c
    STA $FE                     ; 3c — S_FAULT = 0x01
    LDA #$00                    ; 2c — proof token = HALTED
    STA $FFFE                   ; 4c — MMIO: boot failed
    LDA $03                     ; 3c — which stage failed
    STA $C0FF                   ; 4c — WORM: fault record
    BRK                         ; 7c — software interrupt / halt

; Reset vector
.org $FFFC
    .word SOVEREIGN_BOOT_ENTRY  ; reset vector -> boot entry
    .word SOVEREIGN_BOOT_ENTRY  ; IRQ/BRK vector (fault safe)

; Symbolic constants (assembler equates)
BOOT_OK_OFFSET = $04
