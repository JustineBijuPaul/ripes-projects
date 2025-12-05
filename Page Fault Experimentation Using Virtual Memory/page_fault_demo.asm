.text
.globl main

main:
    # 1. Register Trap Handler
    la   t0, trap_handler   # Load address of trap handler
    csrw mtvec, t0          # Set mtvec to point to trap_handler

    # 2. Good Access (should succeed)
    li   s0, 0x10000000     # Assume this is a valid mapped data segment
    lw   t1, 0(s0)          # Normal load; no exception expected

    # 3. Bad Access (Triggers Exception: Page/Access Fault)
    li   s1, 0x00000000     # Null pointer (assumed unmapped)
    lw   t2, 0(s1)          # *** EXCEPTION TRIGGERED HERE ***

    # 4. Continuation Point
    # If the trap handler works correctly, execution resumes here
    li   t3, 42             # We expect this to execute after mret
    li   a7, 10
    ecall                   # End program (semantics depend on Ripes)

# --- Trap Handler (Machine Mode) ---
.align 4
trap_handler:
    # In a real OS, we would inspect mcause to check the exception type
    csrr t5, mcause         # Read cause of trap (optional: for debugging)

    # We must SKIP the faulting instruction, or we'd fault forever.
    csrr t6, mepc           # t6 = address of faulting instruction (lw t2, 0(s1))
    addi t6, t6, 4          # Advance PC by 4 bytes (skip over that instruction)
    csrw mepc, t6           # Update MEPC so we resume AFTER bad load

    mret                    # Return from trap to main program
