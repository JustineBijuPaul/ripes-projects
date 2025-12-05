# TLB Impact on Memory Access Time Demonstration for Ripes

An experiment (partly theoretical, partly simulated) showing how **TLB hits and misses** drastically affect **effective memory access time**, especially when your working set of pages exceeds the **TLB capacity**.

This project uses an access pattern that touches **5 distinct virtual pages** while assuming a **4-entry TLB**, causing **TLB thrashing** and exposing the cost of page table walks.

---

## 📁 Project Files

| File             | Description                                                                                         |
| ---------------- | --------------------------------------------------------------------------------------------------- |
| `tlb_thrash.asm` | RISC-V assembly that repeatedly accesses 5 pages with 4KB stride (designed to thrash a 4-entry TLB) |

> In a real RISC-V + MMU setup, this would exercise the **Sv32 page tables** and the **TLB**.
> In Ripes, you may treat this as a conceptual experiment, and/or use any MMU/TLB visualization if your selected CPU model supports it.

---

## 🎯 What This Demonstrates

* **Virtual-to-Physical Translation Cost**
  How address translation can add substantial latency to memory operations.

* **TLB as a Translation Cache**
  How the TLB avoids repeated page table walks for frequently used pages.

* **TLB Thrashing**
  When the number of frequently accessed pages exceeds TLB capacity, causing **every access** to become a TLB miss.

* **Impact on Effective Memory Access Time**
  How a TLB miss can add **hundreds of cycles** due to page table walks, even if the data itself is in the L1 cache.

* **Motivation for Huge Pages**
  Why HPC and OSes use **2MB / 1GB pages** to increase TLB reach and reduce miss frequency.

---

## 🔧 Ripes Setup Instructions (Conceptual)

> ⚠️ Note: Many educational CPU models (including some Ripes configs) **don’t implement full virtual memory or TLBs**.
> If your chosen Ripes processor supports TLB visualization, use it directly.
> If not, treat this as a **theoretical experiment** and focus on the **cycle analysis** and **TLB discussion** in your report.

### Step 1: Configure the Processor

1. Open **Ripes**.
2. Click the **Processor Selection** (chip icon).
3. Choose a **RISC-V 32-bit 5-stage core** (e.g., `RV32I 5-stage` / `RV32IM 5-stage`).
4. If there is a model with **MMU/TLB** support, prefer that one; otherwise, use a standard one and treat TLB as **theoretical**.

### Step 2: Memory & Page Assumptions

We assume:

* Page Size = **4KB** (Sv32 standard).
* TLB capacity = **4 entries** (small, illustrative).
* The `.align 12` directive aligns data to **4KB page boundaries**, ensuring each `pageX` label starts on a **new page**.

Ripes itself may not simulate page tables/page walks; we will **model their cost analytically**.

---

## 📝 The Assembly Code

### TLB Thrashing Access Pattern

This code deliberately accesses **5 pages**, each 4KB apart, in a fixed sequence, which is larger than the **4-entry TLB capacity** we assume.

```asm
.data
    .align 12           # Align to 4KB page boundary (2^12 = 4096)

page1:
    .word 1
    .space 4092         # Fill remainder of page 1 (total 4096 bytes)

page2:
    .word 2
    .space 4092         # Page 2

page3:
    .word 3
    .space 4092         # Page 3

page4:
    .word 4
    .space 4092         # Page 4

page5:
    .word 5             # Page 5 (5th distinct page)

.text
.globl main
main:
    la   s0, page1      # Start from Page 1
    li   t0, 4096       # Stride = 4KB (page size)

loop_tlb:
    # Access Page 1
    lw   zero, 0(s0)    # TLB Entry 1 (on first touch)
    add  s0, s0, t0     # Move to Page 2 (s0 += 4096)

    # Access Page 2
    lw   zero, 0(s0)    # TLB Entry 2
    add  s0, s0, t0     # Move to Page 3

    # Access Page 3
    lw   zero, 0(s0)    # TLB Entry 3
    add  s0, s0, t0     # Move to Page 4

    # Access Page 4
    lw   zero, 0(s0)    # TLB Entry 4 (TLB now full)
    add  s0, s0, t0     # Move to Page 5

    # Access Page 5
    lw   zero, 0(s0)    # Access Page 5 -> requires 5th TLB entry
                        # In a 4-entry TLB with LRU, this evicts Page 1

    # Loop back to Page 1
    la   s0, page1      # Reset pointer to Page 1
    j    loop_tlb       # Repeat forever (continuous thrashing)
```

### What the Code Does

* Memory layout:

  * `page1`, `page2`, `page3`, `page4`, `page5` are each on **distinct 4KB pages**.
* Access pattern in each loop:

  * Pages: **1 → 2 → 3 → 4 → 5 → (repeat)**.
* With a **4-entry TLB** and **LRU replacement**:

  * After the first 5 accesses (compulsory misses), the TLB holds pages 2,3,4,5.
  * Next iteration:

    * Access Page 1 → miss (evict some other page, say Page 2).
    * Access Page 2 → miss (Page 2 was evicted).
    * Access Page 3 → miss, etc.

Result: **Every access becomes a TLB miss** in steady state → TLB thrashing.

---

## ✅ Expected Behavior

### Functional

* The program just performs **loads (`lw zero, 0(s0)`)** and loops forever.
* It doesn’t modify registers or memory in a meaningful way.
* The sole purpose is to repeatedly touch **5 distinct pages** at 4KB intervals.

### TLB Behavior (Conceptual)

Assuming:

* TLB capacity = **4 entries**
* Replacement = **LRU**

Per iteration:

1. Access Page 1
2. Access Page 2
3. Access Page 3
4. Access Page 4
5. Access Page 5

After warming up, before iteration N:

* TLB contains four of the five pages (e.g., 2,3,4,5).
* The one you’re about to access first (Page 1) is always **not in the TLB**.

So in steady state:

* **Each access** is a **TLB miss**.
* No page stays in the TLB long enough to be reused before being evicted.

This is the **TLB analogue** of cache thrashing.

---

## 📊 Cycle / AMAT Analysis

We’ll analyze **translation cost** abstractly.

### Basic Timing Model

Let:

* TLB Hit time for translation: ≈ **1 cycle** (fast).
* Main Memory access time (for a data access): **N cycles** (e.g., N = 100).
* Page table walk: in Sv32, a TLB miss requires:

  * Access to **Level-1 PTE**
  * Access to **Level-0 PTE**

So on a **TLB miss** we do:

* 2 **extra memory accesses** (each ~N cycles).
* Then the **actual data access** (which may be in L1 cache or memory, we’ll separate those concepts).

We can define:

* **TLB Hit:**

  $$
  \text{Cost} \approx 1 \text{ (translation)} + \text{Cache Access Time}
  $$

* **TLB Miss:**

  $$
  \text{Cost} \approx 1 \text{ (TLB lookup)} + 2 \times N \text{ (PTE loads)} + \text{Cache Access Time}
  $$

If we approximate:

* Memory access latency N = 100 cycles
* Cache access time small compared to 200 cycles

Then:

* **TLB Hit** ≈ 1 + CacheTime
* **TLB Miss** ≈ 1 + 2×100 + CacheTime ≈ **1 + 200 + CacheTime**

So each TLB miss adds roughly **200 cycles** beyond the cache access itself.

### In Our TLB-Thrashing Loop

* We simulate 5-page pattern with 4-entry TLB.
* After warm-up, **each of the 5 loads per loop** is a TLB miss.

So **effective per-load cost** becomes dominated by the page table walk:

* Approx per access:
  $$
  \approx 200 \text{ (TLB miss overhead)} + \text{cache/memory access}
  $$

Even if the **data itself** hits in L1 cache, we already paid a huge **translation penalty**.

**Effect on bandwidth:**

* Without TLB misses:

  * You pay only cache hit latency per access.
* With every access being a TLB miss:

  * You pay ~200 extra cycles per access.
  * Effective throughput drops by roughly **two orders of magnitude**.

This is why **TLB performance** is absolutely crucial in real systems, especially for workloads spanning many pages.

---

## 🔍 How to “Observe” in Ripes

Because most Ripes cores are **bare-metal without virtual memory**, you may not see:

* Explicit TLB hit/miss counters.
* Page table walks.

However, for purposes of an assignment/report, you can:

1. Use the **assembly pattern** above as the code for “TLB thrashing.”
2. In your writeup:

   * Explain theoretically what a TLB would do **if virtual memory were enabled**.
   * Show the **cycle cost** difference using the formulas above.
3. If your Ripes version / CPU has:

   * A **TLB visualization** or
   * A **“virtual memory” mode**

   then:

   * Run this code and inspect TLB entries and hit/miss stats.
   * You should see the TLB entries constantly **churning** as pages are evicted and reinserted.

---

## 🧪 Experiment Workflow (Conceptual)

### Experiment 1: Working Set Fits in TLB (Good Case)

Modify the experiment to use **only 4 pages** instead of 5:

* Remove `page5` or stop loop at Page 4.

Pattern: 1 → 2 → 3 → 4 → 1 → 2 → 3 → 4 …

* With a 4-entry TLB:

  * First iteration: 4 compulsory misses.
  * After that: **all hits** (no page is evicted).

**Result:**

* TLB Miss Rate ≈ 4 / (4 + many hits) → tends toward **0%**.
* Translation overhead per access ≈ **TLB hit cost** only.

---

### Experiment 2: Working Set Exceeds TLB (Bad Case)

Use the original **5-page** loop:

* Pages: 1 → 2 → 3 → 4 → 5 → repeat.
* TLB capacity: 4 entries.

After warm-up:

* **Every access** is a TLB miss (thrashing).

**Result:**

* TLB Miss Rate ≈ **100%**.
* Translation overhead per access ≈ **hit + 2 memory accesses**.

---

### Experiment 3: Compare Effective Latency

Assign:

* Memory access time N = 100 cycles.
* Cache access ≈ 1–3 cycles (small).

Then compare:

1. **Good case (4 pages):**

   * TLB hits after warm-up.
   * Per access: ~1 + CacheTime ≈ a few cycles.

2. **Bad case (5 pages):**

   * Every access is a TLB miss.
   * Per access: ~1 + 2×100 + CacheTime ≈ **200+ cycles**.

Compute **slowdown**:

$$
\text{Slowdown} \approx \frac{200 + \text{CacheTime}}{1 + \text{CacheTime}} \approx 200\text{x (roughly)}
$$

You can report:

> “Exceeding TLB capacity can slow down memory-intensive loops by **two orders of magnitude**, even when all data fits in the cache.”

---

## 📈 Why This Works

### TLB as a Cache for Translations

* Physical memory is accessed via **Physical Addresses (PA)**.
* Programs use **Virtual Addresses (VA)**.
* The Page Table maps **VPN → PPN** (Virtual Page Number → Physical Page Number).
* Without a TLB:

  * Each access would require **page table walks** (multiple memory reads).
* With a TLB:

  * Recent translations are cached.
  * A **TLB hit** avoids the walk entirely.

### TLB Thrashing

* When the number of **distinct pages** in active use exceeds TLB capacity:

  * Old entries are constantly evicted.
  * By the time you revisit a page, its entry is gone.
  * Every access triggers a page table walk → **TLB miss storm**.

This is analogous to cache thrashing, but at the **page translation** level.

### Huge Pages & TLB Reach

* **TLB reach** = (Number of TLB entries) × (Page size).
* Example:

  * 4KB pages, 512-entry TLB → reach = 2MB.
  * 2MB pages, 512-entry TLB → reach = 1GB.
* Larger pages drastically **increase TLB coverage** over the address space, reducing miss frequency.
* This is why HPC workloads often use **huge pages** (2MB, 1GB) to avoid TLB bottlenecks.

---

## 📚 Key Concepts

| Concept                            | Definition                                                                       |
| ---------------------------------- | -------------------------------------------------------------------------------- |
| Virtual Address (VA)               | Address used by the program; translated by MMU/TLB into a physical address       |
| Physical Address (PA)              | Actual location in main memory                                                   |
| Page Table                         | Data structure mapping VPNs to PPNs                                              |
| TLB (Translation Lookaside Buffer) | Small associative cache storing recent VPN→PPN translations                      |
| TLB Hit                            | Translation found in TLB; no page table walk needed                              |
| TLB Miss                           | Translation not in TLB; requires page table walk (multiple memory accesses)      |
| TLB Thrashing                      | Repeated eviction and reloading of TLB entries due to working set > TLB capacity |
| TLB Reach                          | Total memory region that can be covered by TLB = entries × page size             |
| Huge Pages                         | Pages larger than the base size (e.g., 2MB, 1GB) used to increase TLB reach      |

---

## 🚀 Extensions

To deepen the study:

* **Vary Page Count**

  * Try 3 pages, 4 pages, 5 pages, 6 pages against a 4-entry TLB in your analysis.
  * Determine **where** thrashing begins.

* **Simulate Different TLB Sizes**

  * Re-analyze assuming 8-entry or 16-entry TLBs.

* **Mix Sequential and Random**

  * Combine sequential access within a page with random jumps across pages.

* **Link to Real Systems**

  * Look up typical TLB sizes and page sizes for x86-64 or modern RISC-V cores.
  * Estimate TLB reach for real CPUs.

---

## 📄 License

This material is intended for **education** (labs, assignments, self-study).
You’re welcome to **copy, adapt, and integrate** it into your own Ripes experiments, reports, and course projects.
