# Instruction vs. Data Cache Performance Demonstration for Ripes

An experiment demonstrating how **Instruction Cache (I-Cache)** and **Data Cache (D-Cache)** behave differently under two contrasting program structures:

1. A program with **extremely dense code** (lots of instructions → I-cache pressure).
2. A program with **very small code but huge data traffic** (D-cache pressure).

This models the real trade-off between **loop unrolling** (larger code, fewer branches) and **compact loops** (small code, more branch overhead).

---

## 📁 Project Files

| File                  | Description                                                           |
| --------------------- | --------------------------------------------------------------------- |
| `icache_pressure.asm` | Program with repeated instructions (100× copy), stressing the I-Cache |
| `dcache_pressure.asm` | Compact loop over a large array, stressing the D-Cache                |

You will load each program in Ripes **separately** and compare I-cache vs. D-cache activity.

---

## 🎯 What This Demonstrates

* **Modified Harvard Architecture**
  RISC-V processors in Ripes use **separate** L1 I-cache and D-cache, enabling:

  * I-cache fetch during IF stage
  * D-cache access during MEM stage
    simultaneously without structural hazards.

* **Instruction Footprint vs. Data Footprint**
  Large programs stress the **I-cache**.
  Large data loops stress the **D-cache**.

* **Pipeline Performance Impact**

  * I-cache misses stall *instruction fetch* → pipeline bubbles early.
  * D-cache misses stall *memory stage* → bubbles later in the pipe.

* **I-Cache Thrashing vs. D-Cache Thrashing**
  Which one dominates depends on whether the code or the data consumes more memory.

---

## 🔧 Ripes Setup Instructions (Common)

Use a processor model that has **both I-cache and D-cache**:

### Step 1: Select a Pipelined Harvard Architecture Core

1. Open **Ripes**.
2. Click the **Processor Selection** (chip icon).
3. Choose:

   * `RV32I 5-stage`
     or
   * `RV32IM 5-stage`
     (both provide separate I-cache and D-cache)

### Step 2: Configure Cache Sizes (Adjustable)

To clearly demonstrate I-cache or D-cache pressure, use deliberately small caches:

* **I-Cache Size:** 256B or 512B
* **D-Cache Size:** 1KB (default OK)
* **Block size:** 16B
* Associativity: 1-way or 2-way

This makes it easier to exceed the I-cache when we load 100 lines of code.

---

## 📝 The Assembly Code

### Version A — I-Cache Pressure (Loop Unrolled 100×)

This program **copies the loop body 100 times**, drastically increasing the code footprint.

```asm
.text
.globl main
main:
    li t0, 0

    # 100 consecutive addi instructions stressing I-cache
    addi t0, t0, 1
    addi t0, t0, 1
    addi t0, t0, 1
    addi t0, t0, 1
    ...
    # (Repeat this line literally 100 times)
    ...

    li a7, 10
    ecall
```

#### What This Code Does

* The code grows ~400 bytes or more (depending on repetition).
* If I-cache is small (e.g., 256B), the instruction stream **does not fit**.
* The IF stage constantly fetches new lines → **I-cache misses every few instructions**.
* D-cache remains completely idle (no loads/stores).

#### Expected Cache Activity

| Cache Type  | Activity                              |
| ----------- | ------------------------------------- |
| **I-Cache** | High churn: frequent misses and fills |
| **D-Cache** | No accesses (no lw/sw)                |

---

### Version B — D-Cache Pressure (Compact Loop Over Large Data)

This code is tiny (fits into **1 or 2 I-cache lines**), but iterates over a **large array**.

```asm
.data
array:
    .zero 4096       # Large data: 4KB array (1024 words)

.text
.globl main
main:
    la s0, array      # pointer to start of array
    li t0, 1024       # 1024 iterations

loop:
    lw t1, 0(s0)      # Data access → D-cache pressure
    addi s0, s0, 4
    addi t0, t0, -1
    bnez t0, loop

    li a7, 10
    ecall
```

#### What This Code Does

* The entire loop is only **4 instructions** long.
* Fits easily in I-cache (even with very small caches).
* Each iteration loads **a new word from a 4KB region**:

  * D-cache must fetch many blocks.
  * Cache lines evict quickly → D-cache thrashing likely.

#### Expected Cache Activity

| Cache Type  | Activity                                   |
| ----------- | ------------------------------------------ |
| **I-Cache** | Near 100% hit rate                         |
| **D-Cache** | High churn, many misses as array is walked |

---

## 🔍 Ripes Visualization Guide

Ripes allows you to toggle between:

* **Instruction Memory View**
* **Data Memory View**
* **I-Cache Visualization**
* **D-Cache Visualization**
* **Statistics (Miss/Hit counters)**

### For Test A (I-Cache Pressure):

* The **I-Cache view** will show:

  * Many line replacements
  * Tags changing rapidly
  * Miss counter continually rising
* The **D-Cache view** will show:

  * No activity (never accessed)

### For Test B (D-Cache Pressure):

* The **I-Cache view**:

  * One or two lines remain active and unchanged → always hit
* The **D-Cache view**:

  * Many block loads, evictions, new lines
  * Miss counter jumps almost every iteration

These visuals match the two extremes of cache pressure.

---

## 📊 Quantitative Interpretation

### Test A — I-Cache Misses Slow Down IF Stage

Pipeline stalls are visible in the **IF** stage:

* The CPU waits for each I-cache line fetch.
* Downstream stages run out of instructions.
* CPI rises due to fetch bubbles.

### Test B — D-Cache Misses Slow Down MEM Stage

Pipeline slows in the **MEM** stage:

* The CPU waits for D-cache miss to be serviced (often ~N cycles).
* IF still fetches ahead as long as the pipeline buffer allows.

### Summary Table

| Test                   | I-Cache Pressure | D-Cache Pressure | Notes                                            |
| ---------------------- | ---------------- | ---------------- | ------------------------------------------------ |
| **A: Unrolled (100×)** | 🔥 High          | ❄️ Low/None      | Code is huge → I-cache misses dominate           |
| **B: Compact Loop**    | ❄️ Low/None      | 🔥 High          | Data footprint is huge → D-cache misses dominate |

---

## 🧪 Experiment Workflow

### Experiment 1: Measure I-Cache Pressure (Test A)

1. Load `icache_pressure.asm`.
2. Use small I-cache (256B).
3. Run to completion.
4. Record from **Statistics**:

   * I-cache read count
   * I-cache misses
   * Hit rate
   * D-cache reads = 0
5. Observe frequent stalls in IF stage.

---

### Experiment 2: Measure D-Cache Pressure (Test B)

1. Load `dcache_pressure.asm`.
2. Keep same cache settings.
3. Run to completion.
4. Record:

   * D-cache read count
   * D-cache misses
   * Hit rate
   * I-cache misses ≈ 0
5. Observe stalls in MEM stage.

---

### Experiment 3: Compare I-Cache vs D-Cache Dominance

Compute:

* I-cache miss rate in Test A vs Test B
* D-cache miss rate in Test A vs Test B
* CPI differences between the two runs

Expected results:

* Test A → CPI inflated by I-cache stalls
* Test B → CPI inflated by D-cache stalls

---

## 📈 Why This Matters

### Harvard Architecture Advantage

Having a **separate I-cache and D-cache** means:

* Fetch and memory stages work **in parallel**
* No structural hazard between instruction fetching and data access
* Stalls happen **only** when the relevant cache misses

### Why Loop Unrolling Can Hurt I-Cache

* Unrolling increases code size.
* Larger code footprints increase I-cache miss rates.
* If I-cache is small, excessive unrolling can **slow execution**, even though branches are reduced.

### Why Compact Loops Are Efficient

* Tight loops fit entirely in I-cache.
* D-cache usage becomes the limiting factor.
* Most modern compiler optimizations strike a balance:

  * Unroll enough to hide latency
  * But not so much that I-cache blows up

---

## 📚 Key Concepts

| Concept                | Definition                                                               |
| ---------------------- | ------------------------------------------------------------------------ |
| I-Cache                | Cache supplying instruction bytes to the Fetch stage                     |
| D-Cache                | Cache supplying data to the MEM stage                                    |
| Modified Harvard Arch. | Separate instruction/data memory paths in L1                             |
| Structural Hazard      | Conflict for the same hardware resource (avoided by separate I/D caches) |
| Code Density           | Total size of instructions the program executes                          |
| Data Footprint         | Total data accessed during program execution                             |
| Cache Thrashing        | Rapid eviction/fill cycles when working set > cache size                 |

---

## 🚀 Extensions

Try these advanced variants:

* **Adjust Associativity**

  * Test 1-way vs 4-way associativity effects on I-cache or D-cache thrashing.

* **Increase Unrolling**

  * Try 200 addi’s and see I-cache meltdown.

* **Stride-Based Data Access**

  * Modify the D-cache program to access array with stride > 1 to see new miss patterns.

* **Unified Cache Simulation**

  * Emulate unified cache behavior by disabling I-cache and using only D-cache (if supported).

---

## 📄 License

This educational material is provided for architecture labs, assignments, and self-study.
Feel free to modify, extend, or include in your Ripes-based coursework.
