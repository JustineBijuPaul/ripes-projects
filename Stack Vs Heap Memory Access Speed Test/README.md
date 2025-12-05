# Stack vs. Heap Memory Access Speed Test for Ripes

An experiment demonstrating why **stack memory** is accessed much faster than **heap memory**, especially in pipelined CPUs with caches.

This project contrasts:

* A **stack-friendly** access pattern with excellent locality
* A **heap-based pointer-chasing** pattern with poor locality

It shows visually (and analytically) why stack-based code runs faster in real CPUs.

---

## 📁 Project Files

| File               | Description                                                      |
| ------------------ | ---------------------------------------------------------------- |
| `stack_access.asm` | Fast local-variable accesses using the stack (sp-relative loads) |
| `heap_access.asm`  | Pointer-chasing linked-node access simulating heap fragmentation |

Each program is run separately under identical Ripes cache settings to compare performance and locality behavior.

---

## 🎯 What This Demonstrates

* **Stack Memory Characteristics**

  * Always near the **top of memory** being accessed
  * Accesses cluster tightly → great spatial locality
  * Loads/stores relative to `sp` typically hit L1 cache

* **Heap Memory Characteristics**

  * Dynamically allocated, often fragmented
  * Linked structures create **pointer chasing**
  * Each node may be on a different cache line/page
    → very poor locality → more stalls and cache misses

* **Pipeline Behavior**

  * Stack loads have low latency
  * Heap loads depend on pointer loads → long-latency dependency stalls
  * Heap traversal = many unresolved RAW hazards

This experiment makes the locality gap obvious.

---

## 🔧 Ripes Setup Instructions (Common)

### Step 1: Choose a Pipelined RISC-V Core

1. Open **Ripes**.
2. Click the **Processor Selection** (chip icon).
3. Select:

   * **RV32I 5-stage**
     or
   * **RV32IM 5-stage**
     (supports pipeline hazards + caches)

### Step 2: Configure L1 Caches

Use typical values:

* **I-Cache:** 1KB
* **D-Cache:** 1KB
* Block Size: 16 bytes
* Associativity: 1 way or 2 ways

These settings highlight the difference between:

* Stack = “hot” memory region
* Heap = scattered memory region

---

## 📝 The Assembly Code

---

# Version A — Stack Access (Optimized & Local)

This code simulates compiler-generated stack frames and local variable access.

```asm
.text
.globl main
main:
    # Create a 16-byte stack frame
    addi sp, sp, -16

    # Save frame pointer and return address
    sw ra, 12(sp)
    sw s0, 8(sp)

    # Local variable
    li t0, 42
    sw t0, 4(sp)        # Store to stack (L1 write)

    lw t1, 4(sp)        # Fast load from same stack line (L1 hit)

    # Exit
    li a7, 10
    ecall
```

### What This Code Does

* Accesses memory **only near the current `sp`**.
* All stack slots (`sp + offsets`) reside on the **same 64B or 32B cache line**.
* **sw t0, 4(sp)** places data in the line → immediately warms the D-cache.
* **lw t1, 4(sp)** almost guarantees an **L1 hit**.

### Cache Behavior

| Cache   | Expected Behavior                         |
| ------- | ----------------------------------------- |
| D-Cache | Almost 0 misses → extremely high locality |
| I-Cache | Minimal footprint, fits entirely          |

Stack accesses are the fastest memory operations in typical RISC-V code.

---

# Version B — Heap Access (Pointer Chasing)

This code simulates a **linked list** allocated on the heap, where each node is far from the previous.

```asm
.data
# Simulate heap nodes scattered across memory
node1_value: .word 10
node1_next:  .word node2_value

.space 256              # separation (fragmentation)

node2_value: .word 20
node2_next:  .word node3_value

.space 256

node3_value: .word 30
node3_next:  .word 0      # End of list

.text
.globl main
main:
    la s0, node1_value    # s0 = pointer to heap node 1 (value + next pointer)

heap_loop:
    lw s1, 4(s0)          # Load 'next' pointer (must wait for s1)
    beq s1, x0, end       # If next == NULL, stop

    lw t2, 0(s1)          # Load value of next node (dependent load!)
    mv s0, s1             # Move to next node
    j heap_loop

end:
    li a7, 10
    ecall
```

### What This Code Does

* The pointer `s0` moves to heap nodes in **widely separated memory regions**.
* Every iteration executes:

  1. Load next pointer: `lw s1, 4(s0)`
  2. Stall until that address is known
  3. Load next node: `lw t2, 0(s1)`
* If node1 and node2 are in **different cache lines**, both loads may miss.
* This is classic **pointer chasing latency**.

### Cache Behavior

| Cache   | Expected Behavior                             |
| ------- | --------------------------------------------- |
| D-Cache | Many misses (nodes scattered) → poor locality |
| I-Cache | Excellent locality (loop is small)            |

Heap traversal suffers greatly due to dependency stalls + poor locality.

---

## 🔍 Ripes Visualization

### What to observe:

#### For `stack_access.asm`:

* D-cache:

  * Only one or two cache lines touched
  * Nearly all **hits**
* I-cache:

  * Small footprint, stable
* Pipeline:

  * No stalls except initial fill

#### For `heap_access.asm`:

* D-cache:

  * Frequent block loads and evictions
  * Misses on each new node
* Pipeline:

  * RAW hazard: `lw s1` → stall → `lw t2`
  * Notice bubbles in EX/MEM stage
* I-cache:

  * Perfect hit rate (loop is tiny)

---

## 📊 Cycle-Level Analysis

### Stack Access — Fast Path (Hot Cache Line)

* **sw t0, 4(sp)** loads the stack line into the D-cache.
* **lw t1, 4(sp)** hits immediately afterward.
* Cache latency: ~1–3 cycles.
* No dependent pipeline stalls.
* Excellent temporal & spatial locality.

### Heap Access — Slow Path (Pointer Chasing)

Two problems:

---

### **1. Dependency Stall (RAW Hazard)**

```asm
lw s1, 4(s0)     # must complete before...
lw t2, 0(s1)     # ...we know address!
```

The CPU *must* wait for the first load to complete → unavoidable stall.

---

### **2. Cache Misses on Heap Nodes**

Each node is **far apart**, likely on different cache lines:

* First load → might miss
* Second load → also might miss
* Miss penalty = 30–100 cycles depending on your Ripes configuration

---

### Combined Impact

Stack:

* One L1 hit each time → **few cycles total**

Heap:

* Miss for pointer + miss for next node
* * dependency stall
* → **tens to hundreds of cycles per iteration**

---

## 📌 Why This Happens

### 🧱 The Stack Is Compact & Predictable

* Grows downward in a contiguous region.
* Always near recent accesses (great temporal locality).
* Compiler computes addresses as `sp + imm`.
* Used constantly → lives in L1 cache.

### 🌪 The Heap Is Fragmented

* Allocator spreads objects around.
* Pointer chasing forces:

  * Dependent loads
  * Cache misses
  * Page/TLB misses (in real systems)

### 🚀 Result

Stack operations are extremely fast both in theory and in practice.
Heap-linked structures are dramatically slower due to:

* Dependency stalls
* Poor cache locality
* Many cache misses

---

## 🧪 Experiment Workflow

### Experiment 1 — Stack Access

1. Load `stack_access.asm`.
2. Run in Ripes.
3. Observe:

   * Almost no D-cache misses
   * Smooth pipeline activity

### Experiment 2 — Heap Access

1. Load `heap_access.asm`.
2. Run to completion or step through.
3. Observe:

   * Many D-cache misses
   * Bubbles after every `lw s1, 4(s0)`
   * Higher overall cycle count

### Experiment 3 — Compare Performance

Record from Ripes Statistics:

* D-cache read count
* D-cache misses
* Hit rate
* Total cycles
* CPI

Expected trend:

| Metric         | Stack    | Heap        |
| -------------- | -------- | ----------- |
| D-Cache Misses | Very low | Very high   |
| Stalls         | Minimal  | Frequent    |
| CPI            | ~1.0     | Much higher |
| Total Cycles   | Very low | Much higher |

---

## 📈 Final Conclusion

> **Stack memory is faster not because “the stack is magic,” but because it has *excellent locality* and predictable addresses.**
>
> **Heap memory is slower because pointer chasing destroys locality and forces dependent cache misses.**

This difference is so large that modern compilers aggressively move variables to the stack when possible, and optimized systems avoid pointer chasing in hot loops.

---

## 📚 Key Concepts

| Concept           | Definition                                                                |
| ----------------- | ------------------------------------------------------------------------- |
| Stack             | LIFO region accessed via sp; contiguous & cache-friendly                  |
| Heap              | Dynamically allocated memory, often fragmented and pointer-heavy          |
| Pointer Chasing   | Dependency chain of loads where each address depends on the previous load |
| Temporal Locality | Reusing recently accessed data                                            |
| Spatial Locality  | Accessing data stored close together                                      |
| RAW Hazard        | Read-After-Write dependency causing a pipeline stall                      |

---

## 🚀 Extensions

Try:

* Increasing heap fragmentation with more `.space` gaps
* Making a 10-node list and measuring miss count
* Using a struct with larger size to span multiple cache lines
* Changing cache size or associativity and repeating experiments
* Comparing array traversal (good locality) vs linked list (poor locality)

---

## 📄 License

This educational material is free to use for labs, assignments, and research demonstrations.
