.section .text
.globl _start

_start:
    # Initialize base addresses and test values
    la x10, test_data           # x10 = base address for data
    li x11, 0xDEADBEEF          # Test value 1
    li x12, 0xCAFEBABE          # Test value 2
    li x13, 0x12345678          # Test value 3
    li x14, 0xABCDEF01          # Test value 4
    li x15, 0x55AA55AA          # Test value 5

    #==========================================================================
    # TEST 1: Split LSQ - Loads execute OoO between in-order stores
    #==========================================================================
    # Store to address A (slow dependency chain)
    sw x11, 0(x10)              # Store 0xDEADBEEF to test_data[0]
    
    # Load from different address B (should bypass above store)
    lw x20, 64(x10)             # Load from test_data[16] (different cache line)
    
    # Store to address C (in-order with first store)
    sw x12, 4(x10)              # Store 0xCAFEBABE to test_data[1]
    
    # Another load that can bypass
    lw x21, 68(x10)             # Load from test_data[17]
    
    # Verify loads completed (use results)
    add x22, x20, x21           # Should execute before all stores complete

    #==========================================================================
    # TEST 2: OoO Loads to Different Addresses
    #==========================================================================
    # Create a store that will take time
    add x5, x11, x12            # Some computation
    sw x5, 8(x10)               # Store to test_data[2]
    
    # Multiple loads to different addresses - these should all bypass
    lw x23, 128(x10)            # Load from test_data[32]
    lw x24, 132(x10)            # Load from test_data[33]
    lw x25, 136(x10)            # Load from test_data[34]
    lw x26, 140(x10)            # Load from test_data[35]
    
    # Use the loaded values immediately (tests OoO completion)
    add x27, x23, x24
    add x28, x25, x26
    xor x29, x27, x28

    #==========================================================================
    # TEST 3: Uncommitted Store Forwarding - Full Word
    #==========================================================================
    # Store a value
    sw x13, 16(x10)             # Store 0x12345678 to test_data[4]
    
    # Load same address immediately (should forward from store buffer)
    lw x30, 16(x10)             # Should get 0x12345678 from uncommitted store
    
    # Verify forwarded value
    bne x30, x13, fail          # Should match stored value
    
    # Another store-load pair
    sw x14, 20(x10)             # Store 0xABCDEF01 to test_data[5]
    lw x31, 20(x10)             # Should forward 0xABCDEF01
    bne x31, x14, fail

    #==========================================================================
    # TEST 4: Uncommitted Store Forwarding - Partial Word (Byte)
    #==========================================================================
    # Store byte
    li x5, 0xFF
    sb x5, 24(x10)              # Store 0xFF to byte 0 of test_data[6]
    
    # Load byte from same location (forwarding)
    lb x6, 24(x10)              # Should get 0xFFFFFFFF (sign-extended)
    
    # Verify
    li x7, -1                   # 0xFFFFFFFF
    bne x6, x7, fail
    
    # Store another byte
    li x5, 0x42
    sb x5, 25(x10)              # Store 0x42 to byte 1 of test_data[6]
    lb x6, 25(x10)              # Should forward 0x42
    li x7, 0x42
    bne x6, x7, fail

    #==========================================================================
    # TEST 5: Uncommitted Store Forwarding - Half Word
    #==========================================================================
    # Store half word
    li x5, 0x1234
    sh x5, 28(x10)              # Store 0x1234 to half-word at test_data[7]
    
    # Load half word (forwarding)
    lh x6, 28(x10)              # Should get 0x00001234
    li x7, 0x1234
    bne x6, x7, fail
    
    # Unsigned version
    li x5, 0xABCD
    sh x5, 30(x10)              # Store 0xABCD
    lhu x6, 30(x10)             # Load unsigned (should forward)
    li x7, 0xABCD
    bne x6, x7, fail

    #==========================================================================
    # TEST 6: Misaligned Store Forwarding (Byte-level matching)
    #==========================================================================
    # Store word at aligned address
    li x5, 0x11223344
    sw x5, 32(x10)              # Store 0x11223344 to test_data[8]
    
    # Load byte from within the stored word (byte 0)
    lbu x6, 32(x10)             # Should forward 0x44
    li x7, 0x44
    bne x6, x7, fail
    
    # Load byte 1
    lbu x6, 33(x10)             # Should forward 0x33
    li x7, 0x33
    bne x6, x7, fail
    
    # Load byte 2
    lbu x6, 34(x10)             # Should forward 0x22
    li x7, 0x22
    bne x6, x7, fail
    
    # Load byte 3
    lbu x6, 35(x10)             # Should forward 0x11
    li x7, 0x11
    bne x6, x7, fail

    #==========================================================================
    # TEST 7: Misaligned Store Forwarding - Half word from word store
    #==========================================================================
    li x5, 0xAABBCCDD
    sw x5, 36(x10)              # Store to test_data[9]
    
    # Load lower half word
    lhu x6, 36(x10)             # Should forward 0xCCDD
    li x7, 0xCCDD
    bne x6, x7, fail
    
    # Load upper half word
    lhu x6, 38(x10)             # Should forward 0xAABB
    li x7, 0xAABB
    bne x6, x7, fail

    #==========================================================================
    # TEST 8: Load-Store-Load Dependency Chain
    #==========================================================================
    # Load initial value
    lw x5, 40(x10)              # Load from test_data[10]
    
    # Compute and store
    addi x5, x5, 100
    sw x5, 44(x10)              # Store to test_data[11]
    
    # Load stored value (forwarding)
    lw x6, 44(x10)              # Should forward from previous store
    
    # Compute again
    addi x6, x6, 200
    sw x6, 48(x10)              # Store to test_data[12]
    
    # Final load
    lw x7, 48(x10)              # Should forward

    #==========================================================================
    # TEST 9: Multiple Stores to Same Address (WAW hazard)
    #==========================================================================
    li x5, 0x1111
    sw x5, 52(x10)              # First store
    
    li x5, 0x2222
    sw x5, 52(x10)              # Second store (overwrites first)
    
    li x5, 0x3333
    sw x5, 52(x10)              # Third store (overwrites second)
    
    # Load should get the last stored value
    lw x6, 52(x10)
    li x7, 0x3333
    bne x6, x7, fail

    #==========================================================================
    # TEST 10: Store-Load-Store to Same Address
    #==========================================================================
    li x5, 0xAAAA
    sw x5, 56(x10)              # Store 0xAAAA
    
    lw x6, 56(x10)              # Load (forwarding)
    
    li x9, 0x1111
    add x6, x6, x9
    sw x6, 56(x10)              # Store computed value (0xBBBB)
    
    lw x7, 56(x10)              # Final load
    li x8, 0xBBBB
    bne x7, x8, fail

    #==========================================================================
    # TEST 11: Complex Bypass Scenario
    #==========================================================================
    # Store to addr A
    sw x11, 60(x10)
    
    # Store to addr B
    sw x12, 64(x10)
    
    # Load from addr C (different from A and B - should bypass both stores)
    lw x5, 128(x10)
    
    # Store to addr D
    sw x13, 68(x10)
    
    # Load from addr E (should bypass all stores)
    lw x6, 132(x10)
    
    # Use loaded values
    add x7, x5, x6

    #==========================================================================
    # TEST 12: Age-Ordered Load Execution
    #==========================================================================
    # Create multiple loads that can execute OoO
    lw x5, 160(x10)             # Oldest load
    lw x6, 164(x10)             # Second
    lw x7, 168(x10)             # Third
    lw x8, 172(x10)             # Youngest
    
    # All should be able to execute in any order
    add x9, x5, x6
    add x9, x9, x7
    add x9, x9, x8

    #==========================================================================
    # TEST 13: Store-after-Store Ordering
    #==========================================================================
    # Stores must maintain program order
    li x5, 1
    sw x5, 80(x10)              # Store 1
    
    li x5, 2
    sw x5, 84(x10)              # Store 2
    
    li x5, 3
    sw x5, 88(x10)              # Store 3
    
    li x5, 4
    sw x5, 92(x10)              # Store 4
    
    # Verify order by loading back
    lw x6, 80(x10)
    li x7, 1
    bne x6, x7, fail
    
    lw x6, 84(x10)
    li x7, 2
    bne x6, x7, fail

    #==========================================================================
    # TEST 14: Partial Store Overlap (must wait)
    #==========================================================================
    # Store word
    li x5, 0xFFFFFFFF
    sw x5, 96(x10)
    
    # Store byte that overlaps (byte 1 of same word)
    li x6, 0x00
    sb x6, 97(x10)
    
    # Load full word - should see partial update
    lw x7, 96(x10)              # Should get 0xFF00FFFF

    #==========================================================================
    # TEST 15: Stress Test - Many Loads and Stores
    #==========================================================================
    # Issue many memory operations in quick succession
    li x1, 100
stress_loop:
    sw x1, 200(x10)
    lw x2, 204(x10)
    sw x2, 208(x10)
    lw x3, 212(x10)
    addi x1, x1, -1
    bgtz x1, stress_loop

    #==========================================================================
    # Success - All tests passed
    #==========================================================================
success:
    li x1, 1                    # Success code
    li x2, 0x800
    add x2, x2, x10
    sw x1, 0(x2)                # Write to specific address
    slti x0, x0, -256           # Simulator success sentinel
    j end

fail:
    li x1, 0                    # Failure code
    li x2, 0x800
    add x2, x2, x10
    sw x1, 0(x2)                # Write to specific address
    j end

end:
    # Infinite loop to halt
    j end

.section .data
.balign 256
test_data:
    # Pre-initialized data for loads
    .word 0x00000000            # test_data[0]
    .word 0x00000001            # test_data[1]
    .word 0x00000002            # test_data[2]
    .word 0x00000003            # test_data[3]
    .word 0x00000004            # test_data[4]
    .word 0x00000005            # test_data[5]
    .word 0x00000006            # test_data[6]
    .word 0x00000007            # test_data[7]
    .word 0x11223344            # test_data[8]
    .word 0xAABBCCDD            # test_data[9]
    .word 0x12345678            # test_data[10]
    .word 0xABCDEF01            # test_data[11]
    .word 0xCAFEBABE            # test_data[12]
    .word 0xDEADBEEF            # test_data[13]
    .word 0x55AA55AA            # test_data[14]
    .word 0xFF00FF00            # test_data[15]
    
    # More test data for OoO loads (different cache line)
    .word 0x10000000            # test_data[16]
    .word 0x20000000            # test_data[17]
    .word 0x30000000            # test_data[18]
    .word 0x40000000            # test_data[19]
    .word 0x50000000            # test_data[20]
    .word 0x60000000            # test_data[21]
    .word 0x70000000            # test_data[22]
    .word 0x80000000            # test_data[23]
    .word 0x90000000            # test_data[24]
    .word 0xA0000000            # test_data[25]
    .word 0xB0000000            # test_data[26]
    .word 0xC0000000            # test_data[27]
    .word 0xD0000000            # test_data[28]
    .word 0xE0000000            # test_data[29]
    .word 0xF0000000            # test_data[30]
    .word 0xF1000000            # test_data[31]
    
    # Even more data for bypass tests (another cache line)
    .word 0x01010101            # test_data[32]
    .word 0x02020202            # test_data[33]
    .word 0x03030303            # test_data[34]
    .word 0x04040404            # test_data[35]
    .word 0x05050505            # test_data[36]
    .word 0x06060606            # test_data[37]
    .word 0x07070707            # test_data[38]
    .word 0x08080808            # test_data[39]
    .word 0x09090909            # test_data[40]
    .word 0x0A0A0A0A            # test_data[41]
    .word 0x0B0B0B0B            # test_data[42]
    .word 0x0C0C0C0C            # test_data[43]
    .word 0x0D0D0D0D            # test_data[44]
    .word 0x0E0E0E0E            # test_data[45]
    .word 0x0F0F0F0F            # test_data[46]
    .word 0xF0F0F0F0            # test_data[47]
    
    # Buffer space for writes
    .space 512
