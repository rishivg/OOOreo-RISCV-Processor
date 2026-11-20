# Self-checking Zicsr / M-mode trap / CLINT test (no spike needed). Build: ZICSR=1 core.
#   PASS  -> reach `halt` (slti x0,x0,-256 = 0xF0002013) -> monitor $finish.
#   FAIL  -> x31 = failure code, then a non-halt infinite loop -> timeout.
# The CSR/SYSTEM instructions are not modeled by the rv32imc RVFI monitor, but every
# check below is an ordinary load/compare/branch, so any wrong CSR value, wrong trap
# (cause / epc / tval), missed trap or spurious trap is caught.
#
# Register convention: s1 = trap count, s2 = expected mcause, s3/s4/s5 = mepc/mtval/
# mcause captured by the handler, x31 = fail code.
.align 4
.section .text
.globl _start
_start:
    li s1, 0
    li s2, 0
    li x31, 0

    # ---- 1. csrrw / csrrs / csrrc and the immediate forms on mscratch ----
    li t0, 0x12345678
    csrw mscratch, t0              # csrrw x0, mscratch, t0
    csrr t1, mscratch              # csrrs t1, mscratch, x0 (read, NO write)
    li x31, 1
    bne t1, t0, fail
    li t2, 0x0000FFFF
    csrrs t3, mscratch, t2         # rd = old, mscratch |= t2
    li x31, 2
    bne t3, t0, fail
    csrr t1, mscratch
    li t4, 0x1234FFFF
    li x31, 3
    bne t1, t4, fail
    csrrc t3, mscratch, t2         # rd = old, mscratch &= ~t2
    li x31, 4
    bne t3, t4, fail
    csrr t1, mscratch
    li t4, 0x12340000
    li x31, 5
    bne t1, t4, fail
    csrrwi t3, mscratch, 5         # rd = old, mscratch = 5
    li x31, 6
    bne t3, t4, fail
    csrrsi t3, mscratch, 0x10      # rd = 5, mscratch = 0x15
    li t4, 5
    li x31, 7
    bne t3, t4, fail
    csrrci t3, mscratch, 1         # rd = 0x15, mscratch = 0x14
    li t4, 0x15
    li x31, 8
    bne t3, t4, fail
    csrr t1, mscratch
    li t4, 0x14
    li x31, 9
    bne t1, t4, fail
    # a CSR result feeding dependent ALU ops right away
    csrrwi t1, mscratch, 7         # old = 0x14
    addi t2, t1, 1
    slli t2, t2, 4
    li t4, 0x150
    li x31, 10
    bne t2, t4, fail

    # ---- 2. read-only / info CSRs ----
    csrr t1, misa                  # MXL=1 | A | C | I | M
    li t4, 0x40001105
    li x31, 11
    bne t1, t4, fail
    csrr t1, mhartid
    li x31, 12
    bne t1, x0, fail
    csrr t1, mvendorid
    bne t1, x0, fail
    csrr t1, mstatus               # reset: MIE=0 MPIE=0 MPP=11
    li t4, 0x1800
    li x31, 13
    bne t1, t4, fail

    # ---- 3. counters ----
    csrr t1, minstret
    nop
    nop
    nop
    nop
    csrr t2, minstret              # counts retired BEFORE itself: t1's csrr + 4 nops
    sub t3, t2, t1
    li t4, 5
    li x31, 14
    bne t3, t4, fail
    csrr t1, cycle
    csrr t2, cycle
    li x31, 15
    bgeu t1, t2, fail
    csrr t1, time                  # CLINT mtime via the CSR shadow: monotonic too
    csrr t2, time
    li x31, 16
    bgeu t1, t2, fail

    # ---- 4. mtvec + ecall (cause 11, mtval 0, mepc = ecall) ----
    la t0, trap_handler
    csrw mtvec, t0
    csrr t1, mtvec
    li x31, 17
    bne t1, t0, fail
    li s2, 11
    ecall
ecall_ret:
    li t4, 1
    li x31, 18
    bne s1, t4, fail               # exactly one trap
    la t0, ecall_ret
    addi t0, t0, -4
    li x31, 19
    bne s3, t0, fail               # mepc == pc of ecall
    li x31, 20
    bne s4, x0, fail               # mtval == 0
    csrr t1, mstatus               # after mret with MIE=0: MPIE=1, MIE=0
    li t4, 0x1880
    li x31, 21
    bne t1, t4, fail

    # ---- 5. ebreak (cause 3, mtval = pc) ----
    li s2, 3
    ebreak
ebreak_ret:
    li t4, 2
    li x31, 22
    bne s1, t4, fail
    la t0, ebreak_ret
    addi t0, t0, -4
    li x31, 23
    bne s3, t0, fail
    li x31, 24
    bne s4, t0, fail

    # ---- 6. illegal instruction (cause 2, mtval = the instruction) ----
    li s2, 2
    .word 0x0000000B               # custom-0 opcode: not implemented -> illegal
    li t4, 3
    li x31, 25
    bne s1, t4, fail
    li t4, 0x0000000B
    li x31, 26
    bne s4, t4, fail
    # unknown CSR address -> illegal
    csrr t1, 0x7FF
    li t4, 4
    li x31, 27
    bne s1, t4, fail
    # write to a read-only CSR -> illegal (read of it above was fine)
    csrw mhartid, t0
    li t4, 5
    li x31, 28
    bne s1, t4, fail
    # csrrs with rs1 = x0 is a pure read: no trap on a read-only CSR
    csrrs t1, mhartid, x0
    li x31, 29
    bne s1, t4, fail
    # rv32a opcode with a reserved funct5 is still decoded (amoadd) -- not checked here

    # ---- 7. misaligned loads / stores (cause 4 / 6, mtval = address) ----
    la a0, scratch
    li t0, 0xCAFEF00D
    sw t0, 0(a0)
    li s2, 4
    lw t1, 2(a0)                   # misaligned word load
    li t4, 6
    li x31, 30
    bne s1, t4, fail
    addi t4, a0, 2
    li x31, 31
    bne s4, t4, fail
    li s2, 6
    sh t0, 1(a0)                   # misaligned halfword store: must NOT write
    li t4, 7
    li x31, 32
    bne s1, t4, fail
    addi t4, a0, 1
    li x31, 33
    bne s4, t4, fail
    lw t1, 0(a0)
    li x31, 34
    bne t1, t0, fail               # memory untouched
    li s2, 6
    sw t0, 3(a0)
    li t4, 8
    li x31, 35
    bne s1, t4, fail
    li s2, 4
    lh t1, 1(a0)
    li t4, 9
    li x31, 36
    bne s1, t4, fail
    # aligned-enough accesses must not trap
    lb t1, 3(a0)
    lbu t1, 1(a0)
    sb t0, 2(a0)
    lh t1, 2(a0)
    lhu t1, 0(a0)
    sh t0, 2(a0)
    li x31, 37
    bne s1, t4, fail

    # ---- 8. FENCE / FENCE.I / WFI execute as NOPs ----
    fence
    fence.i
    fence rw, rw
    wfi                            # MIE=0, nothing pending -> completes
    li x31, 38
    bne s1, t4, fail

    # ---- 9. CLINT timer interrupt (cause 0x80000007) ----
    li t6, 0x0200BFF8
    lw t0, 0(t6)                   # mtime lo
    addi t0, t0, 400
    li t5, 0x02004000
    sw t0, 0(t5)                   # mtimecmp lo (hi still all-ones -> no fire yet)
    sw x0, 4(t5)                   # mtimecmp hi = 0 -> arms
    li s2, 0x80000007
    li t2, 0x80
    csrs mie, t2                   # MTIE
    li t4, 10                      # expect trap #10
    csrsi mstatus, 8               # MIE -> interrupts live
    li t3, 20000
timer_wait:
    beq s1, t4, timer_done
    addi t3, t3, -1
    bnez t3, timer_wait
    li x31, 39
    j fail
timer_done:
    la t0, timer_wait              # mepc must point into the wait loop
    la t1, timer_done
    li x31, 40
    bltu s3, t0, fail
    li x31, 41
    bgeu s3, t1, fail
    li x31, 42
    bne s4, x0, fail               # mtval 0 for interrupts
    csrr t1, mstatus               # mret with MPIE=1 -> MIE=1 again
    li t4, 0x1888
    li x31, 43
    bne t1, t4, fail

    # ---- 10. software interrupt, first MASKED by mstatus.MIE, then taken ----
    csrci mstatus, 8               # MIE off
    li t2, 0x8
    csrs mie, t2                   # MSIE
    li s2, 0x80000003
    li t6, 0x02000000
    li t0, 1
    sw t0, 0(t6)                   # msip = 1 -> pending but masked
    li t3, 200
soft_mask:
    addi t3, t3, -1
    bnez t3, soft_mask
    li t4, 10
    li x31, 44
    bne s1, t4, fail               # still no trap
    csrr t1, mip
    li t4, 0x8
    li x31, 45
    bne t1, t4, fail               # mip.MSIP visible
    csrsi mstatus, 8               # MIE on -> trap now
    li t4, 11
    li t3, 20000
soft_wait:
    beq s1, t4, soft_done
    addi t3, t3, -1
    bnez t3, soft_wait
    li x31, 46
    j fail
soft_done:
    csrr t1, mip
    li x31, 47
    bne t1, x0, fail               # handler cleared msip

    # ---- 11. trap inside a CSR-heavy loop with interrupts enabled (just run it) ----
    li t3, 16
mix_loop:
    csrr t0, mscratch
    addi t0, t0, 1
    csrw mscratch, t0
    lw t1, 0(a0)
    addi t1, t1, 1
    sw t1, 0(a0)
    addi t3, t3, -1
    bnez t3, mix_loop
    csrr t0, mscratch
    li t4, 7+16
    li x31, 48
    bne t0, t4, fail

halt:
    slti x0, x0, -256              # 0xF0002013 -> PASS ($finish)

fail:
    nop
    j fail                         # not a halt -> timeout

# ---- trap handler: sync -> check cause, mepc += 4; irq -> clear source ----
.align 4
trap_handler:
    csrr s3, mepc
    csrr s4, mtval
    csrr s5, mcause
    addi s1, s1, 1
    bne s5, s2, fail_cause
    bltz s5, irq
    addi t6, s3, 4                 # every faulting instruction here is 32-bit
    csrw mepc, t6
    mret
irq:
    li t6, 0x02004000
    li t5, -1
    sw t5, 4(t6)                   # mtimecmp hi = all ones -> timer off
    li t6, 0x02000000
    sw x0, 0(t6)                   # msip = 0
    mret
fail_cause:
    li x31, 99
    j fail

    .balign 32, 0
    .word 0
    .balign 32, 0

.section .data
.balign 32
scratch:
    .word 0
    .word 0
    .balign 32, 0
