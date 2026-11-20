.align 4
.section .text
.globl _start

_start:
    addi x1,  x0, 1
    addi x2,  x0, 2
    addi x3,  x0, 3
    addi x4,  x0, 4
    addi x5,  x0, 5
    addi x6,  x0, 6
    addi x7,  x0, 7
    addi x8,  x0, 8

    add  x9,  x1, x2
    add  x10, x3, x4
    add  x11, x5, x6
    add  x12, x7, x8
    xor  x9,  x9, x10
    xor  x11, x11, x12
    add  x13, x9, x11
    add  x14, x13, x2

stream_block0:
    addi x1,  x1, 1
    addi x2,  x2, 1
    addi x3,  x3, 1
    addi x4,  x4, 1
    addi x5,  x5, 1
    addi x6,  x6, 1
    addi x7,  x7, 1
    addi x8,  x8, 1

stream_block1:
    add  x9,  x1, x2
    add  x10, x3, x4
    add  x11, x5, x6
    add  x12, x7, x8
    xor  x9,  x9, x10
    xor  x11, x11, x12
    add  x13, x9, x11
    add  x14, x13, x2

stream_block2:
    sll  x1,  x1, x0
    sll  x2,  x2, x0
    sll  x3,  x3, x0
    sll  x4,  x4, x0
    srl  x5,  x5, x0
    srl  x6,  x6, x0
    srl  x7,  x7, x0
    srl  x8,  x8, x0

stream_block3:
    addi x1,  x1, 2
    addi x2,  x2, 2
    addi x3,  x3, 2
    addi x4,  x4, 2
    addi x5,  x5, 2
    addi x6,  x6, 2
    addi x7,  x7, 2
    addi x8,  x8, 2

stream_block4:
    add  x9,  x1, x5
    add  x10, x2, x6
    add  x11, x3, x7
    add  x12, x4, x8
    xor  x9,  x9, x10
    xor  x11, x11, x12
    add  x13, x9, x11
    add  x14, x13, x5

stream_block5:
    addi x1,  x1, 3
    addi x2,  x2, 3
    addi x3,  x3, 3
    addi x4,  x4, 3
    addi x5,  x5, 3
    addi x6,  x6, 3
    addi x7,  x7, 3
    addi x8,  x8, 3

stream_block6:
    add  x9,  x1, x2
    add  x10, x3, x4
    add  x11, x5, x6
    add  x12, x7, x8
    xor  x9,  x9, x10
    xor  x11, x11, x12
    add  x13, x9, x11
    add  x14, x13, x2

    add  x31, x13, x14

halt:
    slti x0, x0, -256
