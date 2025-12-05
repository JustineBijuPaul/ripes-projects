# Array Size vs. Cache Miss Analysis (Thrashing) — Ripes Demonstration

A complete experiment showing how **array/matrix size** interacts with **cache capacity**, why performance suddenly collapses when the *working set* exceeds cache size, and how **loop tiling** restores locality.

This is one of the most important real-world performance phenomena in computer architecture.

---

# 📁 Project Files

| File               | Description                                 |
| ------------------ | ------------------------------------------- |
| `matmul_naive.asm` | Naive matrix multiplication (no tiling)     |
| `matmul_tiled.asm` | Loop-tiled version using cache-sized blocks |

You will run both programs with **different matrix sizes N**, using the same cache configuration in Ripes, then analyze the miss spikes due to thrashing.

---

# 🎯 What This Demonstrates

* **Working Set vs Cache Size:**
  When the working set is smaller than the cache → high hit rate.
  When it grows beyond cache size → thrashing occurs.

* **Thrashing Cliff (Phase Change):**
  Cache performance collapses *dramatically and suddenly*, not gradually.

* **Matrix Multiplication Memory Pattern:**
  Naive matrix multiplication touches large portions of matrices A, B, and C repeatedly, making it an excellent thrashing test.

* **Loop Tiling (Blocking):**
  Restricting computation to small sub-blocks keeps the working set within cache and restores the hit rate.

---

# 🔧 Ripes Setup Instructions

### Step 1 — Select the CPU

Choose a RISC-V pipelined core:

* `RV32I 5-stage` or `RV32IM 5-stage`

### Step 2 — Configure the D-Cache

Use a cache small enough that thrashing is visible:

* **Cache Size:** 1024 bytes (1 KiB)
* **Block Size:** 16 bytes
* **Associativity:** 1-way or 2-way
* Keep I-cache unchanged (instruction footprint is small)

### Step 3 — Run the tests for **N = 4, 8, 16**

You will assemble each program with different N values (or provide three separate .asm files).

---

# 📝 Naive Matrix Multiplication Code

This assembly uses the classic triple-nested loop:

$$
C[i][j] = \sum_k A[i][k] \cdot B[k][j]
$$

Below is a compact RISC-V implementation skeleton (details vary depending on memory layout):

```asm
.data
N:      .word 4                # Change this to 4, 8, 16
A:      .zero 1024             # Enough space for largest matrix
B:      .zero 1024
C:      .zero 1024

.text
.globl main
main:
    la s0, A                  # Base of A
    la s1, B                  # Base of B
    la s2, C                  # Base of C

    lw t0, N                  # t0 = N

    li t1, 0                  # i = 0
loop_i:
    beq t1, t0, end_program

    li t2, 0                  # j = 0
loop_j:
    beq t2, t0, inc_i

    li t3, 0                  # sum = 0
    li t4, 0                  # k = 0

loop_k:
    beq t4, t0, store_c

    # Load A[i][k]
    mul t5, t1, t0
    add t5, t5, t4
    slli t5, t5, 2
    add t6, s0, t5
    lw t7, 0(t6)

    # Load B[k][j]
    mul t8, t4, t0
    add t8, t8, t2
    slli t8, t8, 2
    add t9, s1, t8
    lw t9, 0(t9)

    # sum += A[i][k] * B[k][j]
    mul t7, t7, t9
    add t3, t3, t7

    addi t4, t4, 1
    j loop_k

store_c:
    # Store sum into C[i][j]
    mul t5, t1, t0
    add t5, t5, t2
    slli t5, t5, 2
    add t6, s2, t5
    sw t3, 0(t6)

    addi t2, t2, 1
    j loop_j

inc_i:
    addi t1, t1, 1
    j loop_i

end_program:
    li a7, 10
    ecall
```

---

# 📊 Running the Working Set Experiments

We compute total memory footprint:

$$
\text{Total bytes} = 3 \times N^2 \times 4
$$

Because A, B, C all must be touched each iteration.

---

## ▶️ **Test 1 — N = 4**

* Data = 3 × 16 × 4 = **192 bytes**
* Fits easily in 1KB cache.

**Expected Behavior:**

* > 95% D-cache hit rate
* No thrashing
* Stable performance

Working set fits in cache ⇒ Ideal performance.

---

## ▶️ **Test 2 — N = 8**

* Data = 3 × 64 × 4 = **768 bytes**
* Still fits in 1KB cache (barely)

**Expected Behavior:**

* 90%+ D-cache hit rate
* Some conflict misses depending on associativity
* No catastrophic slowdown

Working set near cache size ⇒ Performance still good.

---

## ▶️ **Test 3 — N = 16**

* Data = 3 × 256 × 4 = **3072 bytes**
* **3× larger than the 1KB cache**
* Cannot fit working set → Thrashing occurs

**Expected Behavior:**

* Miss rate spikes >50%
* Inevitable thrashing because:

  * To compute a row of C, you repeatedly reload rows of A and columns of B.
* When finishing one row:

  * The row you need next has already been evicted.
* Constant reloading of A and B

This is the **Thrashing Cliff**.

---

# 🔥 The Thrashing Cliff Explained

Cache behavior is **non-linear**:

* Below the threshold: cache works perfectly
* *Just above it:* hit rate collapses suddenly and brutally

This phase change is due to:

* Repeatedly evicting blocks that are still part of the working set
* No reuse before eviction
* Working set cycles through more data than cache can retain

This is *exactly* what happens for naive matrix multiplication when N gets too big.

---

# 🧠 Why Tiling (Blocking) Fixes Everything

### Problem:

Naive matrix multiplication touches entire rows and columns of size N each time.
For N=16:

* Rows too large
* Columns too large
* Cache can’t keep them

### Solution:

Process smaller **B × B submatrices** (tiles) that fit the cache.

Let B = block size such that:

$$
3 \times B^2 \times 4 \le 1024
$$

For 1KB cache:

* B = 8 works well
* Working set = 3 × 64 × 4 = **768 bytes** (fits!)

---

# 📝 Tiled Matrix Multiplication (Skeleton)

```asm
# for ii in 0..N step B
#   for jj in 0..N step B
#     for kk in 0..N step B
#       compute block C[ii:ii+B][jj:jj+B] using A and B tiles
```

Each tile stays hot in L1 cache.

This maintains:

* Good spatial locality
* Good temporal locality
* No thrashing even for large N

---

# 🔍 What Ripes Will Show

### Naive Multiplier (`matmul_naive.asm`)

* For **N=4,8**:

  * D-cache heatmap = very stable
  * Low miss count
* For **N=16**:

  * D-cache view = blocks constantly replaced
  * Many conflict and capacity misses
  * Huge cycle slowdown

### Tiled Multiplier (`matmul_tiled.asm`)

* Even for **N=16**:

  * D-cache activity localized
  * Far fewer misses
  * Smooth performance
  * Hit rate restored >90%

---

# 🧪 Experiment Workflow

### 1️⃣ Run Naive Matmul for N = 4, 8, 16

Record:

* Cycles
* CPI
* D-cache reads
* D-cache misses
* Miss rate

You should see:

| N  | Miss Rate | Behavior        |
| -- | --------- | --------------- |
| 4  | <5%       | fits in cache   |
| 8  | <10%      | near capacity   |
| 16 | >50%      | thrashing cliff |

---

### 2️⃣ Run Tiled Matmul for N = 16

Record the same metrics.

Expected:

* Miss rate << 20%
* No thrashing
* Much faster execution

---

# 📈 Summary: Why This Matters

This experiment reveals **the fundamental performance model** in modern computing:

| Working Set        | Cache Reaction                         |
| ------------------ | -------------------------------------- |
| Smaller than cache | High hit rate, predictable performance |
| Larger than cache  | Thrashing, extreme slowdown            |

Matrix multiplication is the classic example taught in textbooks because the memory pattern is predictable and illustrates the working-set cliff perfectly.

Tiling is the universal remedy used by:

* BLAS libraries
* GPU kernels
* Compiler auto-vectorizers
* High-performance scientific computing

---

# 📚 Key Concepts

| Concept           | Meaning                                                           |
| ----------------- | ----------------------------------------------------------------- |
| Working Set       | Memory actively reused in a phase of execution                    |
| Thrashing         | Continuous eviction of needed blocks, causing sky-high miss rates |
| Loop Tiling       | Restricting computation to cache-sized regions                    |
| Spatial Locality  | Accessing adjacent addresses                                      |
| Temporal Locality | Reusing data shortly after first use                              |

---

# 🚀 Extensions

Try:

* Changing cache size (512B, 2KB, 4KB)
* Changing associativity (1-way vs 4-way)
* Measuring the break-even tile size B
* Running random vs sequential access inside the matrix
* Counting misses per loop nest level

---

# 📄 License

This material is designed for use in architecture labs, reports, teaching, and self-study.
You’re free to copy, modify, and include it in your Ripes coursework.
