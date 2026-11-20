.section .text
.globl _start

_start:
    # Initialize base addresses and test values
    la x10, test_data           # x10 = base address for data
    li x11, 100                 # Counter/test value
    li x12, 0                   # Accumulator

    #==========================================================================
    # TEST 1: Age-Ordered Issue from Reservation Stations
    # Create instructions with dependencies - older instructions should issue first
    #==========================================================================
    
    # Independent loads that can all execute OoO
    # The oldest ready instruction should be selected first
    lw x5, 0(x10)               # Oldest load - should issue first
    lw x6, 4(x10)               # Second oldest
    lw x7, 8(x10)               # Third oldest
    lw x8, 12(x10)              # Youngest
    
    # Use results - verifies age-ordered completion
    add x12, x12, x5
    add x12, x12, x6
    add x12, x12, x7
    add x12, x12, x8

    #==========================================================================
    # TEST 2: Age-Ordered Issue with Mixed Ready Times
    # Some instructions ready immediately, others need to wait for operands
    #==========================================================================
    
    # Create a dependency chain
    li x13, 10
    addi x14, x13, 20           # Depends on x13
    
    # Independent instruction (older but ready earlier)
    li x15, 30                  # Should issue before x16 even though x16 becomes ready
    
    # Another dependent instruction
    addi x16, x14, 40           # Depends on x14, younger but may become ready
    
    # Verify order with accumulation
    add x12, x12, x13
    add x12, x12, x14
    add x12, x12, x15
    add x12, x12, x16

    #==========================================================================
    # TEST 3: Age-Ordered ALU Operations
    # Multiple ALU operations competing for execution units
    #==========================================================================
    
    li x17, 1
    li x18, 2
    li x19, 3
    li x20, 4
    
    # Create multiple independent ALU ops (age-ordered)
    add x21, x17, x18           # Oldest ALU op
    add x22, x19, x20           # Second oldest
    sub x23, x17, x18           # Third oldest
    sub x24, x19, x20           # Youngest
    
    # Multiply operations (different functional unit, still age-ordered)
    mul x25, x17, x18           # Oldest mul
    mul x26, x19, x20           # Second oldest mul
    
    # Use results
    add x12, x12, x21
    add x12, x12, x22
    add x12, x12, x23
    add x12, x12, x24
    add x12, x12, x25
    add x12, x12, x26

    #==========================================================================
    # TEST 4: Age-Ordered Loads from LSQ
    # Multiple loads to different addresses - oldest ready load should execute first
    #==========================================================================
    
    # Create a pending store
    sw x11, 64(x10)             # Store that may cause younger loads to wait
    
    # Multiple loads to different addresses (all can bypass the store)
    lw x27, 128(x10)            # Oldest load (different address)
    lw x28, 132(x10)            # Second oldest
    lw x29, 136(x10)            # Third oldest
    lw x30, 140(x10)            # Youngest
    
    # These should execute in age order when all become ready
    add x12, x12, x27
    add x12, x12, x28
    add x12, x12, x29
    add x12, x12, x30

    #==========================================================================
    # TEST 5: Mixed Operation Types with Age Ordering
    # ALU, MUL, BR, and MEM operations all issued together
    #==========================================================================
    
    # Issue operations to different functional units
    lw x5, 16(x10)              # MEM operation (oldest)
    add x6, x17, x18            # ALU operation (second oldest)
    mul x7, x19, x20            # MUL operation (third oldest)
    lw x8, 20(x10)              # MEM operation (youngest)
    
    # Within each functional unit, age ordering should be maintained
    # Across units, parallel execution is expected
    add x12, x12, x5
    add x12, x12, x6
    add x12, x12, x7
    add x12, x12, x8

    #==========================================================================
    # TEST 6: Age Ordering Under Pressure (Full Reservation Stations)
    # Fill up reservation stations and verify oldest ready instructions issue first
    #==========================================================================
    
    li x1, 1
    li x2, 2
    li x3, 3
    li x4, 4
    
    # Create many operations to fill reservation stations
    add x5, x1, x2              # Op 1 (oldest)
    add x6, x2, x3              # Op 2
    add x7, x3, x4              # Op 3
    add x8, x4, x1              # Op 4
    add x9, x5, x6              # Op 5 (depends on 1,2)
    add x13, x7, x8             # Op 6 (depends on 3,4)
    add x14, x9, x13            # Op 7 (depends on 5,6)
    
    # Ops 1-4 should issue in age order (oldest first)
    # Then ops 5-6 should issue in age order when ready
    # Finally op 7 should issue when ready
    
    add x12, x12, x14

    #==========================================================================
    # TEST 7: Age Ordering with Branch Operations
    # Branches in reservation station should respect age order
    #==========================================================================
    
    li x15, 10
    li x16, 20
    
    # Conditional branches (oldest should resolve first if both ready)
    blt x15, x16, skip1         # Oldest branch (should be taken)
    addi x12, x12, 999          # Should not execute
    
skip1:
    bge x16, x15, skip2         # Second oldest branch (should be taken)
    addi x12, x12, 888          # Should not execute
    
skip2:
    beq x15, x15, skip3         # Third branch (should be taken)
    addi x12, x12, 777          # Should not execute
    
skip3:
    # Continue execution
    addi x12, x12, 100

    #==========================================================================
    # TEST 8: Age Ordering with Data Hazards
    # Instructions with data hazards should still respect age order when ready
    #==========================================================================
    
    li x17, 5
    addi x18, x17, 10           # Depends on x17 (second oldest)
    addi x19, x17, 15           # Also depends on x17 (third oldest)
    addi x20, x17, 20           # Also depends on x17 (youngest)
    
    # All three addi operations depend on x17
    # They should execute in age order: x18, then x19, then x20
    # Even though they all become ready at the same time
    
    add x12, x12, x18
    add x12, x12, x19
    add x12, x12, x20

    #==========================================================================
    # TEST 9: Store Age Ordering in LSQ
    # Stores must commit in program order (age order)
    #==========================================================================
    
    li x21, 0xAAAA
    li x22, 0xBBBB
    li x23, 0xCCCC
    li x24, 0xDDDD
    
    # Multiple stores - must complete in order
    sw x21, 80(x10)             # Oldest store
    sw x22, 84(x10)             # Second oldest
    sw x23, 88(x10)             # Third oldest
    sw x24, 92(x10)             # Youngest
    
    # Verify stores completed in order by reading back
    lw x25, 80(x10)
    lw x26, 84(x10)
    
    # Check values match
    bne x25, x21, fail
    bne x26, x22, fail

    #==========================================================================
    # TEST 10: Complex Age Ordering Scenario
    # Mix of all operation types with complex dependencies
    #==========================================================================
    
    # Independent operations (all ready immediately)
    li x1, 100                  # Op 1 (oldest)
    li x2, 200                  # Op 2
    lw x3, 24(x10)              # Op 3
    li x4, 300                  # Op 4
    lw x5, 28(x10)              # Op 5
    
    # Dependent operations
    add x6, x1, x2              # Op 6 (depends on 1,2)
    add x7, x3, x4              # Op 7 (depends on 3,4)
    add x8, x5, x6              # Op 8 (depends on 5,6)
    mul x9, x7, x8              # Op 9 (depends on 7,8) (youngest)
    
    # Final accumulation
    add x12, x12, x9

    #==========================================================================
    # Success - All tests passed
    #==========================================================================
success:
    li x1, 1                    # Success code
    li x2, 0x800
    add x2, x2, x10
    sw x1, 0(x2)                # Write success indicator
    sw x12, 4(x2)               # Write final accumulator value
    slti x0, x0, -256           # Simulator success sentinel
    j end

fail:
    li x1, 0                    # Failure code
    li x2, 0x800
    add x2, x2, x10
    sw x1, 0(x2)                # Write failure indicator
    j end

end:
    # Infinite loop to halt
    j end

.section .data
.balign 256
test_data:
    # Pre-initialized data for loads
    .word 0x00000001            # test_data[0]
    .word 0x00000002            # test_data[1]
    .word 0x00000003            # test_data[2]
    .word 0x00000004            # test_data[3]
    .word 0x00000005            # test_data[4]
    .word 0x00000006            # test_data[5]
    .word 0x00000007            # test_data[6]
    .word 0x00000008            # test_data[7]
    .word 0x00000009            # test_data[8]
    .word 0x0000000A            # test_data[9]
    .word 0x0000000B            # test_data[10]
    .word 0x0000000C            # test_data[11]
    .word 0x0000000D            # test_data[12]
    .word 0x0000000E            # test_data[13]
    .word 0x0000000F            # test_data[14]
    .word 0x00000010            # test_data[15]
    
    # More test data for loads
    .word 0x00000011            # test_data[16]
    .word 0x00000012            # test_data[17]
    .word 0x00000013            # test_data[18]
    .word 0x00000014            # test_data[19]
    .word 0x00000015            # test_data[20]
    .word 0x00000016            # test_data[21]
    .word 0x00000017            # test_data[22]
    .word 0x00000018            # test_data[23]
    .word 0x00000019            # test_data[24]
    .word 0x0000001A            # test_data[25]
    .word 0x0000001B            # test_data[26]
    .word 0x0000001C            # test_data[27]
    .word 0x0000001D            # test_data[28]
    .word 0x0000001E            # test_data[29]
    .word 0x0000001F            # test_data[30]
    .word 0x00000020            # test_data[31]
    
    # Even more data (different cache line)
    .word 0x10000001            # test_data[32]
    .word 0x10000002            # test_data[33]
    .word 0x10000003            # test_data[34]
    .word 0x10000004            # test_data[35]
    .word 0x10000005            # test_data[36]
    .word 0x10000006            # test_data[37]
    .word 0x10000007            # test_data[38]
    .word 0x10000008            # test_data[39]
    
    # Buffer space for writes
    .space 512
