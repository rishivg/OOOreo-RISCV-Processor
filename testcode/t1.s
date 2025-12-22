.section .text
.globl _start

_start:
    # Initialize base addresses and test values
    la x10, test_data           # x10 = base address for data
    li x11, 0                   # Accumulator for verification
    li x12, 0                   # Prefetch hit counter (for analysis)

    #==========================================================================
    # TEST 1: Sequential Stride-1 Access Pattern
    # Tests prefetcher detects stride of 1 cache line (32 bytes)
    #==========================================================================
    
    li x13, 0                   # Offset
    li x14, 16                  # Iteration count
loop1:
    # Access sequential addresses (stride = 32 bytes = 1 cache line)
    add x15, x10, x13
    lw x16, 0(x15)              # Load from current address
    add x11, x11, x16           # Accumulate
    
    addi x13, x13, 32           # Move to next cache line
    addi x14, x14, -1
    bnez x14, loop1
    
    # After detecting the pattern, prefetcher should fetch ahead
    # Subsequent accesses should hit in cache

    #==========================================================================
    # TEST 2: Stride-2 Access Pattern
    # Tests prefetcher detects stride of 2 cache lines (64 bytes)
    #==========================================================================
    
    li x13, 0
    li x14, 12
loop2:
    # Access every other cache line (stride = 64 bytes)
    add x15, x10, x13
    lw x16, 0(x15)
    add x11, x11, x16
    
    addi x13, x13, 64           # Stride of 2 cache lines
    addi x14, x14, -1
    bnez x14, loop2
    
    # Prefetcher should adapt to stride-2 pattern

    #==========================================================================
    # TEST 3: Stride-4 Access Pattern
    # Tests prefetcher detects larger stride (128 bytes)
    #==========================================================================
    
    li x13, 0
    li x14, 8
loop3:
    # Access every 4th cache line (stride = 128 bytes)
    add x15, x10, x13
    lw x16, 0(x15)
    add x11, x11, x16
    
    addi x13, x13, 128          # Stride of 4 cache lines
    addi x14, x14, -1
    bnez x14, loop3
    
    # Prefetcher should detect and adapt to stride-4

    #==========================================================================
    # TEST 4: Backward Stride Access Pattern
    # Tests prefetcher handles negative strides
    #==========================================================================
    
    li x13, 512                 # Start from high address
    li x14, 10
loop4:
    # Access backward (negative stride = -32 bytes)
    add x15, x10, x13
    lw x16, 0(x15)
    add x11, x11, x16
    
    addi x13, x13, -32          # Negative stride
    addi x14, x14, -1
    bnez x14, loop4
    
    # Prefetcher should detect backward stride

    #==========================================================================
    # TEST 5: Small Word-Level Stride (Within Cache Line)
    # Tests prefetcher with stride smaller than cache line
    #==========================================================================
    
    li x13, 0
    li x14, 32                  # More iterations for smaller stride
loop5:
    # Access every 4 bytes (word-level stride)
    add x15, x10, x13
    lw x16, 0(x15)
    add x11, x11, x16
    
    addi x13, x13, 4            # Stride of 1 word
    addi x14, x14, -1
    bnez x14, loop5
    
    # Sequential access within and across cache lines
    # Prefetcher should benefit from locality

    #==========================================================================
    # TEST 6: Stride Pattern Change
    # Tests prefetcher adapts when stride changes
    #==========================================================================
    
    # First pattern: stride = 32
    li x13, 0
    li x14, 8
loop6a:
    add x15, x10, x13
    lw x16, 0(x15)
    add x11, x11, x16
    addi x13, x13, 32
    addi x14, x14, -1
    bnez x14, loop6a
    
    # Change to different stride: stride = 64
    li x13, 0
    li x14, 8
loop6b:
    add x15, x10, x13
    lw x16, 64(x15)             # Different offset to avoid same addresses
    add x11, x11, x16
    addi x13, x13, 64
    addi x14, x14, -1
    bnez x14, loop6b
    
    # Prefetcher should detect new stride and adapt

    #==========================================================================
    # TEST 7: Interleaved Access Patterns
    # Tests prefetcher with two interleaved stride patterns
    #==========================================================================
    
    li x13, 0                   # Offset for pattern A
    li x14, 1024                # Offset for pattern B
    li x15, 8                   # Iteration count
loop7:
    # Pattern A: stride = 32
    add x16, x10, x13
    lw x17, 0(x16)
    add x11, x11, x17
    
    # Pattern B: stride = 32 (different base)
    add x16, x10, x14
    lw x17, 0(x16)
    add x11, x11, x17
    
    addi x13, x13, 32
    addi x14, x14, 32
    addi x15, x15, -1
    bnez x15, loop7
    
    # Prefetcher should handle both streams

    #==========================================================================
    # TEST 8: Long Sequential Scan
    # Tests prefetcher effectiveness over long sequential access
    #==========================================================================
    
    li x13, 0
    li x14, 64                  # Large iteration count
loop8:
    add x15, x10, x13
    lw x16, 0(x15)
    add x11, x11, x16
    
    addi x13, x13, 32           # Sequential cache line access
    addi x14, x14, -1
    bnez x14, loop8
    
    # Prefetcher should maintain high hit rate throughout

    #==========================================================================
    # TEST 9: Stride with Computation (Realistic Pattern)
    # Tests prefetcher with stride access mixed with computation
    #==========================================================================
    
    li x13, 0
    li x14, 16
loop9:
    # Load from stride pattern
    add x15, x10, x13
    lw x16, 0(x15)
    
    # Do some computation (simulates real workload)
    mul x17, x16, x16           # Square the value
    addi x17, x17, 100          # Add constant
    srli x17, x17, 2            # Shift right
    
    add x11, x11, x17           # Accumulate result
    
    addi x13, x13, 32           # Stride access
    addi x14, x14, -1
    bnez x14, loop9
    
    # Prefetcher should work with realistic computation patterns

    #==========================================================================
    # TEST 10: Multiple Cache Line Access per Iteration
    # Tests prefetcher when multiple lines accessed per iteration
    #==========================================================================
    
    li x13, 0
    li x14, 8
loop10:
    add x15, x10, x13
    
    # Access multiple words from same stride base
    lw x16, 0(x15)              # First word
    lw x17, 4(x15)              # Second word
    lw x18, 8(x15)              # Third word
    lw x19, 12(x15)             # Fourth word
    
    add x11, x11, x16
    add x11, x11, x17
    add x11, x11, x18
    add x11, x11, x19
    
    addi x13, x13, 32           # Move to next cache line
    addi x14, x14, -1
    bnez x14, loop10
    
    # Prefetcher benefits from spatial locality

    #==========================================================================
    # TEST 11: Stride Pattern with Random Access Mixed In
    # Tests prefetcher robustness with occasional non-stride access
    #==========================================================================
    
    li x13, 0
    li x14, 16
loop11:
    # Regular stride access
    add x15, x10, x13
    lw x16, 0(x15)
    add x11, x11, x16
    
    # Occasional random access (every 4th iteration)
    andi x17, x14, 3
    bnez x17, skip11
    li x18, 2048
    add x19, x10, x18
    lw x20, 0(x19)              # Random access
    add x11, x11, x20
    
skip11:
    addi x13, x13, 32
    addi x14, x14, -1
    bnez x14, loop11
    
    # Prefetcher should maintain stride pattern despite random accesses

    #==========================================================================
    # TEST 12: Matrix Column Access Pattern (Stride = Row Size)
    # Tests prefetcher with matrix column traversal
    #==========================================================================
    
    # Simulate 8x8 matrix (each element 4 bytes, row = 32 bytes)
    li x13, 0                   # Column offset
    li x14, 8                   # Rows to access
loop12:
    add x15, x10, x13
    lw x16, 0(x15)              # Access column element
    add x11, x11, x16
    
    addi x13, x13, 32           # Stride = row size (8 words * 4 bytes)
    addi x14, x14, -1
    bnez x14, loop12
    
    # Column-major access creates stride pattern

    #==========================================================================
    # TEST 13: Prefetch Distance Test
    # Tests how far ahead prefetcher fetches
    #==========================================================================
    
    # Rapid sequential access to test prefetch distance
    li x13, 0
    li x14, 32
loop13:
    add x15, x10, x13
    lw x16, 0(x15)
    lw x17, 32(x15)             # Access next line immediately
    lw x18, 64(x15)             # Access next+1 line
    
    add x11, x11, x16
    add x11, x11, x17
    add x11, x11, x18
    
    addi x13, x13, 96           # Skip ahead (3 cache lines)
    addi x14, x14, -1
    bnez x14, loop13
    
    # Tests if prefetcher can stay ahead of aggressive access

    #==========================================================================
    # TEST 14: Warmup and Steady State
    # Tests prefetcher training period vs steady state performance
    #==========================================================================
    
    # Training phase (first few accesses establish pattern)
    li x13, 0
    li x14, 4                   # Short warmup
loop14a:
    add x15, x10, x13
    lw x16, 0(x15)
    add x11, x11, x16
    addi x13, x13, 32
    addi x14, x14, -1
    bnez x14, loop14a
    
    # Steady state (prefetcher should be trained)
    li x14, 32                  # Long run
loop14b:
    add x15, x10, x13
    lw x16, 0(x15)
    add x11, x11, x16
    addi x13, x13, 32
    addi x14, x14, -1
    bnez x14, loop14b
    
    # Compare warmup vs steady state cache behavior

    #==========================================================================
    # TEST 15: Linked List Traversal (Anti-Pattern for Stride Prefetcher)
    # Tests prefetcher behavior with pointer chasing (should not help)
    #==========================================================================
    
    # Simulate linked list with "next" pointers
    # In real linked list, addresses would be scattered
    # Here we simulate with computed addresses
    
    la x13, linked_list_data
    li x14, 8                   # List length
loop15:
    lw x15, 0(x13)              # Load data
    add x11, x11, x15
    
    lw x13, 4(x13)              # Load next pointer (simulated)
    beqz x13, end15             # Check for null
    
    addi x14, x14, -1
    bnez x14, loop15
    
end15:
    # Stride prefetcher cannot help with pointer chasing
    # This tests that prefetcher doesn't harm performance

    #==========================================================================
    # TEST 16: Burst Access Pattern
    # Tests prefetcher with bursts of accesses separated by computation
    #==========================================================================
    
    li x13, 0
    li x14, 4                   # Number of bursts
loop16_outer:
    # Burst of sequential accesses
    li x15, 8                   # Burst size
loop16_inner:
    add x16, x10, x13
    lw x17, 0(x16)
    add x11, x11, x17
    addi x13, x13, 32
    addi x15, x15, -1
    bnez x15, loop16_inner
    
    # Computation phase (simulate work between bursts)
    li x18, 1000
compute16:
    addi x18, x18, -1
    bnez x18, compute16
    
    addi x14, x14, -1
    bnez x14, loop16_outer
    
    # Prefetcher should handle bursty access patterns

    #==========================================================================
    # Success - All tests completed
    #==========================================================================
success:
    li x1, 1                    # Success code
    li x2, 0x800
    add x2, x2, x10
    sw x1, 0(x2)                # Write success indicator
    sw x11, 4(x2)               # Write final accumulator
    sw x12, 8(x2)               # Write prefetch hit counter
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
    # Large array for stride testing
    .word 0x00000001, 0x00000002, 0x00000003, 0x00000004
    .word 0x00000005, 0x00000006, 0x00000007, 0x00000008
    .word 0x00000009, 0x0000000A, 0x0000000B, 0x0000000C
    .word 0x0000000D, 0x0000000E, 0x0000000F, 0x00000010
    .word 0x00000011, 0x00000012, 0x00000013, 0x00000014
    .word 0x00000015, 0x00000016, 0x00000017, 0x00000018
    .word 0x00000019, 0x0000001A, 0x0000001B, 0x0000001C
    .word 0x0000001D, 0x0000001E, 0x0000001F, 0x00000020
    
    # Continue pattern for multiple cache lines
    .word 0x00000021, 0x00000022, 0x00000023, 0x00000024
    .word 0x00000025, 0x00000026, 0x00000027, 0x00000028
    .word 0x00000029, 0x0000002A, 0x0000002B, 0x0000002C
    .word 0x0000002D, 0x0000002E, 0x0000002F, 0x00000030
    .word 0x00000031, 0x00000032, 0x00000033, 0x00000034
    .word 0x00000035, 0x00000036, 0x00000037, 0x00000038
    .word 0x00000039, 0x0000003A, 0x0000003B, 0x0000003C
    .word 0x0000003D, 0x0000003E, 0x0000003F, 0x00000040
    
    # More data (16 cache lines total)
    .word 0x00000041, 0x00000042, 0x00000043, 0x00000044
    .word 0x00000045, 0x00000046, 0x00000047, 0x00000048
    .word 0x00000049, 0x0000004A, 0x0000004B, 0x0000004C
    .word 0x0000004D, 0x0000004E, 0x0000004F, 0x00000050
    .word 0x00000051, 0x00000052, 0x00000053, 0x00000054
    .word 0x00000055, 0x00000056, 0x00000057, 0x00000058
    .word 0x00000059, 0x0000005A, 0x0000005B, 0x0000005C
    .word 0x0000005D, 0x0000005E, 0x0000005F, 0x00000060
    
    .word 0x00000061, 0x00000062, 0x00000063, 0x00000064
    .word 0x00000065, 0x00000066, 0x00000067, 0x00000068
    .word 0x00000069, 0x0000006A, 0x0000006B, 0x0000006C
    .word 0x0000006D, 0x0000006E, 0x0000006F, 0x00000070
    .word 0x00000071, 0x00000072, 0x00000073, 0x00000074
    .word 0x00000075, 0x00000076, 0x00000077, 0x00000078
    .word 0x00000079, 0x0000007A, 0x0000007B, 0x0000007C
    .word 0x0000007D, 0x0000007E, 0x0000007F, 0x00000080
    
    # Large buffer for various stride patterns
    .space 2048
    
linked_list_data:
    # Simulated linked list (data, next_pointer pairs)
    .word 0x00000100, linked_list_data + 8
    .word 0x00000200, linked_list_data + 16
    .word 0x00000300, linked_list_data + 24
    .word 0x00000400, linked_list_data + 32
    .word 0x00000500, linked_list_data + 40
    .word 0x00000600, linked_list_data + 48
    .word 0x00000700, linked_list_data + 56
    .word 0x00000800, 0                         # Last node (null pointer)
    
    .space 1024
