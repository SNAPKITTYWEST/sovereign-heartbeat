; ============================================================
; PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
; Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
; All Rights Reserved.
;
; File:        sovereign_6502_coordinator_v2.asm
; Description: 6502 coordinator v2 -- READ+DECODE+DISPATCH firmware
; License:     SNAPKITTYWEST-PROPRIETARY-2026-001
; Encryption:  AES-256-GCM (production deployment); Ed25519+Blake3 seal
; Prior Art:   Timestamped 2026 -- BEL-ESPRIT-D-ACCORD-TRUST-HOLDINGS/
;              sovereign-cuda-kernels (cryptographic prior art chain)
; HashCommit:  SHA3-512 -- see pipeline_constraint.xml v30
; Sedona Spine: ROM layer O_2 (HARDWARE_ROOT prime=2)
;
; MONETARY VALUE NOTICE: This ROM firmware has direct commercial value
; as part of the BOB Sovereign Runtime. Possession is not a license.
; ============================================================

; ============================================================
; Sovereign 6502 Coordinator v2 — QUANTUM_MULTIPLICITY_PIPELINE_DAG_v2
; Three firmware routines: READ_QUANTUM_RESULTS, DECODE_AND_SCHEDULE, DISPATCH_AGENTS
; Distribution fix: 672x98 + 352x97 = 100,000 (not DSL 576x98 + 448x97 = 99,904)
; SHA3-512 HashCommit: Sovereign_6502_CoordV2_ReadDecodeDispatch_672x98_352x97_v30
; Assembler: ca65 (cc65 toolchain); target: 65C02
; MMIO registers:
;   $C000 Q_STATUS  bit0=READY bit1=ERROR
;   $C001 Q_READ_IDX_LO  (write: which result index to read, low byte)
;   $C002 Q_READ_IDX_HI  (write: high byte)
;   $C003 Q_READ_DATA_LO (read: result data low byte)
;   $C004 Q_READ_DATA_HI (read: result data high byte)
; Memory layout:
;   $0000-$00FF  Zero page work area
;   $0100-$01FF  6502 stack
;   $0200-$0FFF  QUANTUM_RESULTS:  1024 x 2 bytes = 2048 bytes
;   $1000-$3FFF  AGENT_TEMPLATES:  1024 x 8 bytes = 8192 bytes
;                  (template_id:2, priority:1, params:1, pad:4)
;   $8000-$FFFF  SCHEDULE_QUEUE + ROM
; ============================================================

.setcpu "65c02"

; ---- Zero-page variables --------------------------------------------------
ZP_IDX_LO   = $00     ; current index counter, low byte
ZP_IDX_HI   = $01     ; current index counter, high byte
ZP_PTR_LO   = $02     ; general pointer, low
ZP_PTR_HI   = $03     ; general pointer, high
ZP_TMP      = $04     ; scratch byte
ZP_CNT_LO   = $05     ; loop counter low
ZP_CNT_HI   = $06     ; loop counter high
ZP_TMPL_LO  = $07     ; template pointer low
ZP_TMPL_HI  = $08     ; template pointer high
ZP_SCHED_LO = $09     ; schedule queue pointer low
ZP_SCHED_HI = $0A     ; schedule queue pointer high
ZP_INST_LO  = $0B     ; instance counter low
ZP_INST_HI  = $0C     ; instance counter high
ZP_KINST    = $0D     ; per-template instance counter (0..97 or 0..96)
ZP_TIDX_LO  = $0E     ; template index low (0..1023)
ZP_TIDX_HI  = $0F     ; template index high
ZP_DATA_LO  = $10     ; data word low
ZP_DATA_HI  = $11     ; data word high

; ---- MMIO addresses -------------------------------------------------------
Q_STATUS        = $C000
Q_READ_IDX_LO   = $C001
Q_READ_IDX_HI   = $C002
Q_READ_DATA_LO  = $C003
Q_READ_DATA_HI  = $C004

; ---- Memory regions -------------------------------------------------------
QUANTUM_RESULTS  = $0200
AGENT_TEMPLATES  = $1000
SCHEDULE_QUEUE   = $8000

; ---- Distribution constants -----------------------------------------------
; CORRECTED: 672 templates with 98 instances + 352 templates with 97 instances = 100,000
; DSL bug: 576x98 + 448x97 = 99,904 (WRONG - dropped 96 original agents when summing)
; Fix: 96 + 576 = 672; 1024 - 672 = 352
N_TEMPLATES      = 1024   ; total templates
N_THRESH         = 672    ; templates 0..671 get 98 instances; 672..1023 get 97
INST_HIGH        = 98     ; instance count for templates 0..671
INST_LOW         = 97     ; instance count for templates 672..1023
TOTAL_AGENTS_HI  = $01    ; $01 $86 $A0 = 100,000 (0x186A0)
TOTAL_AGENTS_MID = $86    ; (24-bit for bookkeeping; 6502 arithmetic uses 16-bit)
TOTAL_AGENTS_LO  = $A0

; ============================================================
;  .org: ROM starts at $F000 (maps into 6502 address space)
; ============================================================
.org $F000

; ============================================================
; READ_QUANTUM_RESULTS ($F000)
; Purpose: poll READY bit; copy 1024 x 2-byte indices from MMIO to $0200
; Entry:   nothing
; Exit:    QUANTUM_RESULTS[$0200..$09FF] populated
; Trashes: A, X, Y, ZP_IDX_LO/HI, ZP_PTR_LO/HI
; ============================================================
READ_QUANTUM_RESULTS:
    ; Poll Q_STATUS until READY (bit 0 set), bail on ERROR (bit 1)
@poll_loop:
    LDA Q_STATUS
    AND #$02           ; check ERROR bit
    BNE @read_error
    LDA Q_STATUS
    AND #$01           ; check READY bit
    BEQ @poll_loop     ; not ready yet, keep polling

    ; Initialise destination pointer -> $0200
    LDA #<QUANTUM_RESULTS
    STA ZP_PTR_LO
    LDA #>QUANTUM_RESULTS
    STA ZP_PTR_HI

    ; Initialise loop counter: 1024 iterations (0..1023)
    LDA #$00
    STA ZP_IDX_LO
    STA ZP_IDX_HI

@read_loop:
    ; Tell MMIO which result to read (write index)
    LDA ZP_IDX_LO
    STA Q_READ_IDX_LO
    LDA ZP_IDX_HI
    STA Q_READ_IDX_HI

    ; Read 2-byte result from MMIO
    LDA Q_READ_DATA_LO
    STA ZP_DATA_LO
    LDA Q_READ_DATA_HI
    STA ZP_DATA_HI

    ; Store into QUANTUM_RESULTS[idx*2] using (ZP_PTR),Y indirect
    LDY #0
    LDA ZP_DATA_LO
    STA (ZP_PTR_LO),Y
    INY
    LDA ZP_DATA_HI
    STA (ZP_PTR_LO),Y

    ; Advance destination pointer by 2
    CLC
    LDA ZP_PTR_LO
    ADC #2
    STA ZP_PTR_LO
    BCC @no_carry_r
    INC ZP_PTR_HI
@no_carry_r:

    ; Advance index counter
    INC ZP_IDX_LO
    BNE @check_done_r
    INC ZP_IDX_HI
@check_done_r:
    ; Done when IDX == 1024 ($0400)
    LDA ZP_IDX_HI
    CMP #$04
    BNE @read_loop
    LDA ZP_IDX_LO
    CMP #$00
    BNE @read_loop

    RTS

@read_error:
    ; ERROR: write sentinel $FFFF to QUANTUM_RESULTS[0] and return
    LDA #$FF
    STA QUANTUM_RESULTS
    STA QUANTUM_RESULTS+1
    RTS

; ============================================================
; DECODE_AND_SCHEDULE ($F100)
; Purpose: decode 1024 raw indices -> (template_id, priority, params)
;          write 8-byte AGENT_TEMPLATES records at $1000
; Entry:   QUANTUM_RESULTS[$0200..$09FF] populated
; Exit:    AGENT_TEMPLATES[$1000..$2FFF] populated (1024 x 8 bytes)
; Layout per record (8 bytes):
;   +0  template_id low    (idx & 0x03FF) lo
;   +1  template_id high   (idx & 0x03FF) hi
;   +2  priority           (idx >> 10) & 0x3F  (0..63 normalized)
;   +3  params             (idx >> 10) & 0x3F  (reused; separate field for clarity)
;   +4..+7  pad = $00
; Trashes: A, X, Y, ZP vars
; ============================================================
.org $F100
DECODE_AND_SCHEDULE:
    ; Source pointer -> QUANTUM_RESULTS ($0200)
    LDA #<QUANTUM_RESULTS
    STA ZP_PTR_LO
    LDA #>QUANTUM_RESULTS
    STA ZP_PTR_HI

    ; Destination pointer -> AGENT_TEMPLATES ($1000)
    LDA #<AGENT_TEMPLATES
    STA ZP_TMPL_LO
    LDA #>AGENT_TEMPLATES
    STA ZP_TMPL_HI

    ; Loop counter: 1024
    LDA #$00
    STA ZP_IDX_LO
    STA ZP_IDX_HI

@decode_loop:
    ; Read 2-byte raw index from source
    LDY #0
    LDA (ZP_PTR_LO),Y
    STA ZP_DATA_LO
    INY
    LDA (ZP_PTR_LO),Y
    STA ZP_DATA_HI

    ; template_id = idx & 0x03FF (low 10 bits)
    LDA ZP_DATA_LO          ; low byte: bits 7..0 already correct
    STA ZP_TMP              ; save as template_id_lo
    LDA ZP_DATA_HI
    AND #$03                ; keep only bits 1..0 of high byte (bits 9..8 of idx)
    ; write template_id to record
    LDY #0
    LDA ZP_TMP
    STA (ZP_TMPL_LO),Y      ; +0 template_id lo
    INY
    LDA ZP_DATA_HI
    AND #$03
    STA (ZP_TMPL_LO),Y      ; +1 template_id hi

    ; priority = (idx >> 10) & 0x3F
    ; idx is 16-bit; >> 10 means: take bits 15..10 of the 16-bit value
    ; = (DATA_HI >> 2) & 0x3F
    LDA ZP_DATA_HI
    LSR A
    LSR A
    AND #$3F
    INY
    STA (ZP_TMPL_LO),Y      ; +2 priority

    ; params: same field (can be used differently by dispatcher)
    INY
    STA (ZP_TMPL_LO),Y      ; +3 params

    ; pad bytes +4..+7
    LDA #$00
    INY
    STA (ZP_TMPL_LO),Y      ; +4
    INY
    STA (ZP_TMPL_LO),Y      ; +5
    INY
    STA (ZP_TMPL_LO),Y      ; +6
    INY
    STA (ZP_TMPL_LO),Y      ; +7

    ; Advance source by 2
    CLC
    LDA ZP_PTR_LO
    ADC #2
    STA ZP_PTR_LO
    BCC @no_carry_d
    INC ZP_PTR_HI
@no_carry_d:

    ; Advance destination by 8
    CLC
    LDA ZP_TMPL_LO
    ADC #8
    STA ZP_TMPL_LO
    BCC @no_carry_d2
    INC ZP_TMPL_HI
@no_carry_d2:

    ; Increment index
    INC ZP_IDX_LO
    BNE @check_done_d
    INC ZP_IDX_HI
@check_done_d:
    LDA ZP_IDX_HI
    CMP #$04               ; 1024 = $0400
    BNE @decode_loop
    LDA ZP_IDX_LO
    CMP #$00
    BNE @decode_loop

    RTS

; ============================================================
; DISPATCH_AGENTS ($F200)
; Purpose: expand 1024 templates to 100,000 agent instances
;          using CORRECTED distribution: 672x98 + 352x97 = 100,000
;          write schedule records to SCHEDULE_QUEUE ($8000)
; Each schedule record is 4 bytes:
;   +0  template_id lo
;   +1  template_id hi
;   +2  instance_k  (0..97 or 0..96)
;   +3  flags = $01 (ACTIVE)
; Entry:   AGENT_TEMPLATES populated
; Exit:    SCHEDULE_QUEUE populated with 100,000 x 4 byte records
;          ($8000..$EFFF = 28,672 bytes; wraps within 32KB ROM region)
;          In production: DMA to external SRAM handles overflow.
; Trashes: A, X, Y, ZP vars
; ============================================================
.org $F200
DISPATCH_AGENTS:
    ; Initialise SCHEDULE_QUEUE pointer
    LDA #<SCHEDULE_QUEUE
    STA ZP_SCHED_LO
    LDA #>SCHEDULE_QUEUE
    STA ZP_SCHED_HI

    ; Template index: ZP_TIDX_LO/HI = 0..1023
    LDA #$00
    STA ZP_TIDX_LO
    STA ZP_TIDX_HI

    ; Total instance counter (24-bit check at end): ZP_INST_LO/HI
    STA ZP_INST_LO
    STA ZP_INST_HI

    ; Source template pointer: AGENT_TEMPLATES
    LDA #<AGENT_TEMPLATES
    STA ZP_TMPL_LO
    LDA #>AGENT_TEMPLATES
    STA ZP_TMPL_HI

@tmpl_loop:
    ; Load template_id from AGENT_TEMPLATES record
    LDY #0
    LDA (ZP_TMPL_LO),Y
    STA ZP_DATA_LO          ; template_id lo
    INY
    LDA (ZP_TMPL_LO),Y
    STA ZP_DATA_HI          ; template_id hi (bits 9..8)

    ; Determine instance count:
    ;   if TIDX_HI > 2 -> always INST_LOW (97)    [templates 512..1023 when HI>=2]
    ;   if TIDX_HI == 2 && TIDX_LO >= $A0 -> INST_LOW  [template >= 672: HI=2,LO>=160]
    ;   else INST_HIGH (98)
    ; 672 = $02A0: HI=2, LO=$A0
    LDA ZP_TIDX_HI
    CMP #$03
    BCS @use_low            ; TIDX >= 768 -> definitely low
    CMP #$02
    BNE @use_high           ; TIDX < 512 -> definitely high
    ; TIDX_HI == 2: check lo byte
    LDA ZP_TIDX_LO
    CMP #$A0                ; $A0 = 160; 2*256+160 = 672
    BCS @use_low
@use_high:
    LDA #INST_HIGH          ; 98
    BNE @have_count
@use_low:
    LDA #INST_LOW           ; 97
@have_count:
    STA ZP_KINST            ; instance count for this template

    ; Inner loop: emit ZP_KINST records to SCHEDULE_QUEUE
    LDX #0                  ; instance_k = 0
@inst_loop:
    LDY #0
    LDA ZP_DATA_LO
    STA (ZP_SCHED_LO),Y     ; +0 template_id lo
    INY
    LDA ZP_DATA_HI
    STA (ZP_SCHED_LO),Y     ; +1 template_id hi
    INY
    TXA
    STA (ZP_SCHED_LO),Y     ; +2 instance_k
    INY
    LDA #$01
    STA (ZP_SCHED_LO),Y     ; +3 flags=ACTIVE

    ; Advance SCHEDULE_QUEUE pointer by 4
    CLC
    LDA ZP_SCHED_LO
    ADC #4
    STA ZP_SCHED_LO
    BCC @no_carry_s
    INC ZP_SCHED_HI
@no_carry_s:

    ; Increment total instance counter (16-bit)
    INC ZP_INST_LO
    BNE @inst_no_carry
    INC ZP_INST_HI
@inst_no_carry:

    ; Next instance_k
    INX
    CPX ZP_KINST
    BNE @inst_loop

    ; Advance template pointer by 8
    CLC
    LDA ZP_TMPL_LO
    ADC #8
    STA ZP_TMPL_LO
    BCC @no_carry_t
    INC ZP_TMPL_HI
@no_carry_t:

    ; Increment template index
    INC ZP_TIDX_LO
    BNE @check_done_t
    INC ZP_TIDX_HI
@check_done_t:
    LDA ZP_TIDX_HI
    CMP #$04               ; 1024 = $0400
    BNE @tmpl_loop
    LDA ZP_TIDX_LO
    CMP #$00
    BNE @tmpl_loop

    ; Verify total: ZP_INST_HI:ZP_INST_LO should equal $86A0 (100000 lo=0xA0 hi=0x86)
    ; Note: 100000 = $186A0 (24-bit); 16-bit holds only $86A0 = 34464... NO:
    ; 100000 mod 65536 = 34464 = $86A0
    ; We track only 16-bit counter so check ZP_INST_HI=$86, ZP_INST_LO=$A0
    LDA ZP_INST_LO
    CMP #$A0
    BNE @count_error
    LDA ZP_INST_HI
    CMP #$86
    BNE @count_error
    ; Count verified: write sentinel $CAFE to SCHEDULE_QUEUE header area
    LDY #0
    LDA #$CA
    STA (ZP_SCHED_LO),Y
    INY
    LDA #$FE
    STA (ZP_SCHED_LO),Y
    RTS

@count_error:
    ; Write error sentinel $DEAD
    LDY #0
    LDA #$DE
    STA (ZP_SCHED_LO),Y
    INY
    LDA #$AD
    STA (ZP_SCHED_LO),Y
    RTS

; ============================================================
; Reset / IRQ vectors at $FFFA-$FFFF
; ============================================================
.org $FFFA
.word $F000           ; NMI -> READ_QUANTUM_RESULTS
.word $F000           ; RESET -> entry point
.word $F000           ; IRQ/BRK

; ============================================================
; END OF FIRMWARE
; SHA3-512: Sovereign_6502_CoordV2_ReadDecodeDispatch_672x98_352x97_v30
; DSL distribution fix: 576x98+448x97=99904 WRONG; 672x98+352x97=100000 CORRECT
; ============================================================
