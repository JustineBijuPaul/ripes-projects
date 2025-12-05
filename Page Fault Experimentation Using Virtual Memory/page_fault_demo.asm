.data
    .align 4
# Simulated page table: each entry is 8 bytes (4 for virtual base, 4 for valid flag)
# In a real system, the MMU handles this in hardware
page_table:
    .word 0x10010000, 1     # Page 0: valid (mapped to data segment)
    .word 0x10011000, 1     # Page 1: valid
    .word 0x00000000, 0     # Page 2: invalid (unmapped - will cause "fault")
    .word 0xDEAD0000, 0     # Page 3: invalid (unmapped)

fault_flag:    .word 0     # 0 = no fault, 1 = fault occurred
fault_addr:    .word 0     # Address that caused the fault
access_count:  .word 0     # Number of successful accesses
fault_count:   .word 0     # Number of faults

valid_data:    .word 0xCAFEBABE   # Some valid data to read

msg_ok:        .string "Access OK\n"
msg_fault:     .string "PAGE FAULT!\n"

.text
.globl main

main:
    # Initialize counters
    la   s0, access_count
    sw   zero, 0(s0)
    la   s1, fault_count
    sw   zero, 0(s1)

    # ----- Test 1: Access valid mapped address -----
    la   a0, valid_data         # Load address of valid data
    jal  ra, check_and_access   # Check page table and access
    
    # ----- Test 2: Access another valid address -----
    la   a0, page_table         # Access page table itself (valid)
    jal  ra, check_and_access

    # ----- Test 3: Access unmapped address (simulated page fault) -----
    li   a0, 0x00000000         # Null pointer (will be marked invalid)
    jal  ra, check_and_access   # This will trigger simulated fault

    # ----- Test 4: Access another bad address -----
    li   a0, 0xDEAD0000         # Bad address
    jal  ra, check_and_access   # This will trigger simulated fault

    # ----- Print results -----
    # Load final counts
    la   t0, access_count
    lw   s2, 0(t0)              # s2 = successful accesses
    la   t1, fault_count
    lw   s3, 0(t1)              # s3 = faults

    # Exit program
    li   a7, 93                 # Ripes exit syscall
    li   a0, 0                  # Exit code 0
    ecall

# ============================================================
# Subroutine: check_and_access
# Simulates MMU page table lookup before memory access
# Input: a0 = address to access
# ============================================================
check_and_access:
    addi sp, sp, -8
    sw   ra, 0(sp)
    sw   a0, 4(sp)

    # Check if address is in valid range (simplified check)
    # We consider addresses in 0x10010000-0x10012000 as "mapped"
    li   t0, 0x10010000
    li   t1, 0x10012000
    
    blt  a0, t0, page_fault     # Below valid range -> fault
    bge  a0, t1, page_fault     # Above valid range -> fault

    # Valid access - perform the load
valid_access:
    lw   t2, 0(a0)              # Actual memory access
    
    # Increment success counter
    la   t3, access_count
    lw   t4, 0(t3)
    addi t4, t4, 1
    sw   t4, 0(t3)
    
    j    access_done

page_fault:
    # Simulated page fault handler
    # In a real OS, this would:
    # 1. Save processor state
    # 2. Look up the page in swap/disk
    # 3. Load page into memory
    # 4. Update page table
    # 5. Retry the instruction
    
    # Record the fault
    la   t3, fault_flag
    li   t4, 1
    sw   t4, 0(t3)
    
    la   t3, fault_addr
    sw   a0, 0(t3)              # Store faulting address
    
    # Increment fault counter
    la   t3, fault_count
    lw   t4, 0(t3)
    addi t4, t4, 1
    sw   t4, 0(t3)
    
    # In simulation, we just skip the access (like a fault handler would)
    
access_done:
    lw   ra, 0(sp)
    lw   a0, 4(sp)
    addi sp, sp, 8
    ret
