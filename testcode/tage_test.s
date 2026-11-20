tage_test.s:
.align 4
.section .text
.globl _start

# Register setup
# x1: Loop counter (max 3)
# x2: Alternating register for pattern (T, NT, T, NT, ...)

_start:
    li x1, 3           
    li x2, 1            
    li x3, 0           

# ----------------------------------------------------
# TAGE Test 1: Allocation and Training (3 iterations)
# Pattern: BNEZ x1 (Taken 2x, NT 1x) and BNEZ x2 (T, NT, T)
# ----------------------------------------------------

MAIN_LOOP:
    addi x3, x3, 1      # x3 <- x3 + 1
    
BRANCH_A:
    bnez x1, BRANCH_B  
    j MISPREDICT_START  

BRANCH_B:
    addi x1, x1, -1     # Decrement loop counter
    
BRANCH_C:
    # Pattern Branch: Alternates T, NT, T, NT... 
    bnez x2, TAKEN_TARGET 
    j NOT_TAKEN_TARGET    # Jump to NT path

TAKEN_TARGET:
    li x2, 0            # Next time: NOT TAKEN
    j MAIN_LOOP         

NOT_TAKEN_TARGET:
    li x2, 1            # Next time: TAKEN
    j MAIN_LOOP         


# ----------------------------------------------------
# TAGE Test 2: Misprediction and Flush Check
# We force it to be T to test flush/recovery.
# ----------------------------------------------------
MISPREDICT_START:
    addi x10, x0, 100  

BRANCH_E:
    bnez x1, MISPREDICT_TARGET 
    
    addi x1, x0, 1     
    bnez x1, MISPREDICT_TARGET 

MISPREDICT_RECOVERY:
    addi x10, x10, 1   
    j halt

MISPREDICT_TARGET:
    # This should be the first instruction executed after the flush
    addi x10, x10, 200 
    j halt

halt:
    slti x0, x0, -256