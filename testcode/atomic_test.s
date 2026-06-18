# Self-checking RV32A test (no spike needed).
#   PASS  -> reach `halt` (slti x0,x0,-256 = 0xF0002013) -> monitor $finish.
#   FAIL  -> any wrong atomic result branches to `fail:` (a non-halt infinite
#            loop, so the run times out -> distinguishable from PASS).
# The atomics themselves are not modeled by the rv32imc monitor, but every check
# below uses monitored loads/branches, so a wrong atomic effect is caught.
.align 4
.section .text
.globl _start
_start:
    la a0, scratch                 # a0 = &scratch (writable DRAM)

    # ---- amoswap.w: rd=old, mem=rs2 ----
    li t0, 0x11111111
    sw t0, 0(a0)
    li t1, 0x22222222
    amoswap.w t2, t1, (a0)
    li t3, 0x11111111
    bne t2, t3, fail               # rd must be old value
    lw t4, 0(a0)
    li t5, 0x22222222
    bne t4, t5, fail               # mem must be rs2

    # ---- amoadd.w: rd=old, mem=old+rs2 ----
    li t0, 100
    sw t0, 0(a0)
    li t1, 5
    amoadd.w t2, t1, (a0)
    li t3, 100
    bne t2, t3, fail
    lw t4, 0(a0)
    li t5, 105
    bne t4, t5, fail

    # ---- amoor.w / amoand.w / amoxor.w ----
    li t0, 0xF0F0F0F0
    sw t0, 0(a0)
    li t1, 0x0F0F0F0F
    amoor.w t2, t1, (a0)           # mem = 0xFFFFFFFF, rd = 0xF0F0F0F0
    lw t4, 0(a0)
    li t5, 0xFFFFFFFF
    bne t4, t5, fail
    li t0, 0xFF00FF00
    sw t0, 0(a0)
    li t1, 0x0FF00FF0
    amoand.w t2, t1, (a0)          # mem = 0x0F000F00
    lw t4, 0(a0)
    li t5, 0x0F000F00
    bne t4, t5, fail
    li t0, 0xAAAAAAAA
    sw t0, 0(a0)
    li t1, 0xFFFFFFFF
    amoxor.w t2, t1, (a0)          # mem = 0x55555555
    lw t4, 0(a0)
    li t5, 0x55555555
    bne t4, t5, fail

    # ---- amomin.w (signed) / amomaxu.w (unsigned) ----
    li t0, 10
    sw t0, 0(a0)
    li t1, -5
    amomin.w t2, t1, (a0)          # signed min(10,-5) = -5
    lw t4, 0(a0)
    li t5, -5
    bne t4, t5, fail
    li t0, 10
    sw t0, 0(a0)
    li t1, -1                      # 0xFFFFFFFF
    amomaxu.w t2, t1, (a0)         # unsigned max(10, 0xFFFFFFFF) = 0xFFFFFFFF
    lw t4, 0(a0)
    li t5, -1
    bne t4, t5, fail

    # ---- lr.w / sc.w success (no intervening store) ----
    li t0, 0
    sw t0, 0(a0)
    lr.w t1, (a0)                  # reservation set
    li t2, 0x12345678
    sc.w t3, t2, (a0)             # success -> rd=0, mem=rs2
    bne t3, x0, fail               # sc must succeed (rd==0)
    lw t4, 0(a0)
    li t5, 0x12345678
    bne t4, t5, fail

    # ---- lr.w / sc.w fail (intervening store clears reservation) ----
    lr.w t1, (a0)
    li t2, 0xDEADBEEF
    sw t2, 0(a0)                   # intervening store -> clears reservation
    li t6, 0xCAFEBABE
    sc.w t3, t6, (a0)            # fail -> rd!=0, mem unchanged
    beq t3, x0, fail               # sc must fail (rd!=0)
    lw t4, 0(a0)
    li t5, 0xDEADBEEF
    bne t4, t5, fail               # mem must still be the sw value

halt:
    slti x0, x0, -256              # 0xF0002013 -> PASS ($finish)

fail:
    nop
    j fail                        # jal x0,-4 (offset!=0) -> not a halt -> timeout

.section .data
.align 4
scratch:
    .word 0
