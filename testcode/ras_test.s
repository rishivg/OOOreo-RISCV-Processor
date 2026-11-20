.section .text
.globl _start

_start:
    # Initialize base addresses and test values
    la x10, test_data           # x10 = base address for data
    li x11, 0                   # Accumulator for test verification

    #==========================================================================
    # TEST 1: Basic Call and Return (JAL/JALR)
    # Tests that RAS pushes on call and pops on return
    #==========================================================================
    
    jal x1, func1               # Call func1 (should push return address to RAS)
    addi x11, x11, 1            # Should execute after return (verify return worked)
    
    # Verify we returned correctly
    li x13, 1
    bne x11, x13, fail

    #==========================================================================
    # TEST 2: Multiple Sequential Calls
    # Tests RAS with multiple non-nested calls
    #==========================================================================
    
    jal x1, func4               # Call func4
    addi x11, x11, 10
    
    jal x1, func5               # Call func5
    addi x11, x11, 10
    
    jal x1, func6               # Call func6
    addi x11, x11, 10
    
    # Verify all returns worked (should be 1 + 4 + 10 + 5 + 10 + 6 + 10 = 46)
    li x13, 46
    bne x11, x13, fail

    #==========================================================================
    # TEST 3: Call with x5 (alternate link register)
    # Tests that RAS recognizes x5 as a link register
    #==========================================================================
    
    jal x5, func7               # Call with x5 as link register
    addi x11, x11, 100
    
    # Verify return worked (should be 46 + 7 + 100 = 153)
    li x13, 153
    bne x11, x13, fail

    #==========================================================================
    # TEST 4: Nested Calls (2 levels)
    # Tests that RAS can handle nesting with saved link registers
    #==========================================================================
    
    jal x1, nested1             # Call nested1
    li x2, 1000
    add x11, x11, x2
    
    # nested1 adds 10, nested2 adds 20
    # Total: 153 + 10 + 20 + 1000 = 1183
    li x13, 1183
    bne x11, x13, fail

    #==========================================================================
    # TEST 5: Return Pattern Detection
    # Multiple returns in sequence to test RAS pop behavior
    #==========================================================================
    
    jal x1, ret_test1
    jal x1, ret_test2
    jal x1, ret_test3
    li x2, 10000
    add x11, x11, x2
    
    # ret_test1-3 each add 100, total: 1183 + 300 + 10000 = 11483
    li x13, 11483
    bne x11, x13, fail

    #==========================================================================
    # TEST 6: Mixed JAL and JALR
    # Tests both types of call instructions
    #==========================================================================
    
    jal x1, func_jal            # JAL call
    
    # JALR call (indirect)
    la x2, func_jalr
    jalr x1, 0(x2)              # JALR call
    
    li x2, 100000
    add x11, x11, x2
    
    # func_jal adds 500, func_jalr adds 600
    # Total: 11483 + 500 + 600 + 100000 = 112583
    li x13, 112583
    bne x11, x13, fail

    #==========================================================================
    # Success - All tests passed
    #==========================================================================
success:
    li x1, 1                    # Success code
    li x2, 0x800
    add x2, x2, x10
    sw x1, 0(x2)                # Write success indicator
    sw x11, 4(x2)               # Write final accumulator value
    slti x0, x0, -256           # Simulator success sentinel
    j end

fail:
    li x1, 0                    # Failure flag
    li x2, 0x800
    add x2, x2, x10
    sw x1, 0(x2)                # Write failure indicator
    sw x11, 4(x2)               # Write accumulator (for debugging)
    j end

end:
    # Infinite loop to halt
    j end

#==============================================================================
# Function Definitions
#==============================================================================

func1:
    addi x11, x11, 0            # No operation, just test return
    jalr x0, 0(x1)              # Return (RAS should pop)

func4:
    addi x11, x11, 4
    jalr x0, 0(x1)

func5:
    addi x11, x11, 5
    jalr x0, 0(x1)

func6:
    addi x11, x11, 6
    jalr x0, 0(x1)

func7:
    addi x11, x11, 7
    jalr x0, 0(x5)              # Return using x5

# Nested function - saves x1 to stack
nested1:
    addi sp, sp, -8             # Allocate stack space
    sw x1, 0(sp)                # Save return address
    addi x11, x11, 10           # Add 10
    jal x1, nested2             # Call nested2
    lw x1, 0(sp)                # Restore return address
    addi sp, sp, 8              # Deallocate stack
    jalr x0, 0(x1)              # Return

nested2:
    addi x11, x11, 20           # Add 20
    jalr x0, 0(x1)              # Return

# Return test functions
ret_test1:
    addi x11, x11, 100
    jalr x0, 0(x1)

ret_test2:
    addi x11, x11, 100
    jalr x0, 0(x1)

ret_test3:
    addi x11, x11, 100
    jalr x0, 0(x1)

func_jal:
    addi x11, x11, 500
    jalr x0, 0(x1)

func_jalr:
    addi x11, x11, 600
    jalr x0, 0(x1)

.section .data
.balign 256
test_data:
    .word 0x00000000
    .space 512
