.data
N:      .word 16               # Matrix size (NxN)
B_size: .word 8                # Block size (BxB)
A:      .zero 1024             # 16x16 * 4 bytes = 1024 bytes
B:      .zero 1024
C:      .zero 1024

.text
.globl main
main:
    la s0, A                   # Base of A
    la s1, B                   # Base of B
    la s2, C                   # Base of C

    lw s3, N                   # s3 = N
    lw s4, B_size              # s4 = B (Block size)

    # ii loop (0 to N, step B)
    li t0, 0                   # ii = 0
loop_ii:
    bge t0, s3, end_program

    # jj loop (0 to N, step B)
    li t1, 0                   # jj = 0
loop_jj:
    bge t1, s3, inc_ii

    # kk loop (0 to N, step B)
    li t2, 0                   # kk = 0
loop_kk:
    bge t2, s3, inc_jj

    # --- Inner Loops (Process Block) ---
    # i loop (ii to min(ii+B, N))
    mv t3, t0                  # i = ii
loop_i:
    add t6, t0, s4             # ii + B
    bge t3, t6, inc_kk         # if i >= ii+B, next block
    bge t3, s3, inc_kk         # if i >= N, next block

    # j loop (jj to min(jj+B, N))
    mv t4, t1                  # j = jj
loop_j:
    add t6, t1, s4             # jj + B
    bge t4, t6, inc_i          # if j >= jj+B, next i
    bge t4, s3, inc_i          # if j >= N, next i

    # Initialize sum (Load C[i][j] if accumulating, but here we overwrite or assume 0 init)
    # For simplicity, we'll load current C[i][j], add, and store back
    # C[i][j] address
    mul t5, t3, s3             # i * N
    add t5, t5, t4             # + j
    slli t5, t5, 2             # * 4
    add s5, s2, t5             # &C[i][j]
    lw a0, 0(s5)               # sum = C[i][j] (accumulate over kk blocks)

    # k loop (kk to min(kk+B, N))
    mv t5, t2                  # k = kk
loop_k:
    add t6, t2, s4             # kk + B
    bge t5, t6, store_c        # if k >= kk+B, store sum
    bge t5, s3, store_c        # if k >= N, store sum

    # Load A[i][k]
    mul t6, t3, s3             # i * N
    add t6, t6, t5             # + k
    slli t6, t6, 2
    add a1, s0, t6
    lw a2, 0(a1)               # A[i][k]

    # Load B[k][j]
    mul t6, t5, s3             # k * N
    add t6, t6, t4             # + j
    slli t6, t6, 2
    add a3, s1, t6
    lw a4, 0(a3)               # B[k][j]

    # sum += A * B
    mul a2, a2, a4
    add a0, a0, a2

    addi t5, t5, 1             # k++
    j loop_k

store_c:
    sw a0, 0(s5)               # Store updated sum to C[i][j]
    addi t4, t4, 1             # j++
    j loop_j

inc_i:
    addi t3, t3, 1             # i++
    j loop_i

inc_kk:
    add t2, t2, s4             # kk += B
    j loop_kk

inc_jj:
    add t1, t1, s4             # jj += B
    j loop_jj

inc_ii:
    add t0, t0, s4             # ii += B
    j loop_ii

end_program:
    li a7, 10
    ecall
