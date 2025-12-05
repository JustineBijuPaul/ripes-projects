.data
    # Offsets spaced by the cache size (1024 B) to force index collisions
    .equ OFFSET_A, 0
    .equ OFFSET_B, 1024
    .equ OFFSET_C, 2048
    .equ OFFSET_D, 3072

    # Reserve 4 KB so all offsets are valid
base_addr:
    .space 4096

.text
.globl main
main:
    la  s0, base_addr        # s0 = base address of allocated space
    li  t0, 10               # loop counter: perform the access sequence 10 times

conflict_loop:
    lw  t1, OFFSET_A(s0)     # Access A: base + 0
    lw  t2, OFFSET_B(s0)     # Access B: base + 1024
    lw  t3, OFFSET_C(s0)     # Access C: base + 2048
    lw  t4, OFFSET_D(s0)     # Access D: base + 3072

    addi t0, t0, -1          # t0--
    bnez t0, conflict_loop   # repeat until t0 == 0

    # Terminate program (ecall semantics may vary in Ripes)
    li  a7, 10
    ecall
