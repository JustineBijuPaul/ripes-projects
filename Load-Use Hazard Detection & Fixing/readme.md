# Load-Use Hazard Detection & Fixing for Ripes

A comprehensive guide to understanding, visualizing, and fixing the **most critical bottleneck** in pipelined processors: the **Load-Use Hazard**.

This project demonstrates what happens when you load a value (`lw`) and try to use it in the very next instruction—the data isn't ready in time, forcing the CPU to pause.

---

## 📁 Project Files

| File | Description |
|------|-------------|
| `hazard_demo.asm` | Original code with intentional Load-Use hazard |
| `hazard_fixed.asm` | Optimized code with instruction scheduling fix |

---

## 🎯 What This Demonstrates

- **Load-Use Hazard**: The unavoidable delay when using data immediately after loading
- **Hardware Solutions**: Forwarding (data bypassing) to reduce stalls
- **Software Solutions**: Instruction scheduling to eliminate stalls entirely
- **A/B Testing**: Same code, different processor configurations

---

## 🔬 Understanding Load-Use Hazards

### The Problem

In a 5-stage pipeline, a `lw` instruction doesn't have its data until the **end of the MEM stage**. If the next instruction needs that data in the **EX stage**, there's a timing conflict:

```
Timeline WITHOUT Forwarding:
Cycle:    1     2     3     4     5     6     7
lw t2:    IF    ID    EX    MEM   WB
                            ↓ Data available here
addi t3:        IF    ID    --    --    EX    MEM   WB
                      ↑ Needs t2 here!
                      STALL for 2+ cycles
```

```
Timeline WITH Forwarding:
Cycle:    1     2     3     4     5     6
lw t2:    IF    ID    EX    MEM   WB
                            ↓ Forward data here
addi t3:        IF    ID    --    EX    MEM   WB
                      ↑ Still need 1 cycle stall
```

Even with forwarding, **1 stall cycle is unavoidable** because data arrives at the *end* of MEM but is needed at the *start* of EX.

---

## 🔧 Ripes Setup Instructions

### The A/B Test

You will run the **same code** on two different processor configurations to see the difference.

### Configuration A: No Forwarding (Baseline)

1. Open **Ripes**
2. Click the **Processor Selection** icon
3. Select **RISC-V 32-bit**
4. Choose: **`5-Stage Processor w/o Forwarding`**

**Expected Result:** CPU must wait for data to be fully written back to register file before reading it again (2-3 cycle stalls).

### Configuration B: With Forwarding (Hardware Fix)

1. Click the **Processor Selection** icon
2. Choose: **`5-Stage Processor (w/ Forwarding)`**

**Expected Result:** CPU grabs data as soon as it leaves MEM stage and "forwards" it to ALU (only 1 cycle stall).

---

## 📝 Assembly Code: The Hazard Generator

This code intentionally places an `add` instruction immediately after a `lw` to trigger the hazard:

```asm
.data
    # Input: 5 integers
    source: .word 10, 20, 30, 40, 50
    # Output: Destination for results
    dest:   .word 0, 0, 0, 0, 0

.text
.globl main

main:
    la   a0, source     # Address of Source
    la   a1, dest       # Address of Destination
    li   t0, 5          # Loop count (N=5)
    li   t1, 0          # Iterator i=0

loop:
    beq  t1, t0, end    # Exit if i == 5
    
    # --- THE HAZARD ZONE ---
    lw   t2, 0(a0)      # 1. Load data from Memory (Takes time)
    
    # HAZARD: We need t2 IMMEDIATELY.
    # In 'No Forwarding' mode: CPU pauses for ~2-3 cycles.
    # In 'Forwarding' mode: CPU pauses for 1 cycle (Load delay).
    
    addi t3, t2, 100    # 2. Use t2 immediately (Add 100)
    # -----------------------

    sw   t3, 0(a1)      # Store result
    
    addi a0, a0, 4      # Next source address
    addi a1, a1, 4      # Next dest address
    addi t1, t1, 1      # i++
    
    j    loop

end:
    nop
```

---

## 🧪 Experiments

### Scenario A: No Forwarding (The "Stall" Approach)

**What to Observe:**

1. Watch the **Pipeline** diagram
2. When `lw` is in the **EX** stage, `addi` is in the **ID** stage
3. The pipeline inserts **Bubbles (NOPs)**
4. The `addi` instruction stays stuck in Decode for multiple cycles

**Visual in Pipeline View:**

```
Cycle:  1    2    3    4    5    6    7    8    9
lw:     IF   ID   EX   MEM  WB
addi:        IF   ID   --   --   EX   MEM  WB
                  ↑ STUCK! Waiting for t2
             Bubbles inserted here
```

**Performance:**
- **Cycles:** ~60-70 cycles
- **CPI:** > 1.5 (High - Bad)
- **Stalls per loop:** 2-3 bubbles

---

### Scenario B: With Forwarding (Hardware Fix)

**What to Observe:**

1. In the processor diagram, see the **data forwarding line** connecting MEM output back to EX input
2. Still see exactly **1 Stall Cycle** (unavoidable for Load-Use)

**Why 1 Cycle Still?**

The data is retrieved at the *end* of the MEM cycle. The next instruction needs it at the *start* of the EX cycle. There is physically no way to travel back in time!

```
Cycle:  1    2    3    4    5    6    7
lw:     IF   ID   EX   MEM  WB
                       ↓ Data forwarded here
addi:        IF   ID   --   EX   MEM  WB
                  ↑ 1 cycle stall (unavoidable)
```

**Performance:**
- **Cycles:** ~45-50 cycles
- **CPI:** ~1.2 (Better)
- **Stalls per loop:** 1 bubble

---

### Scenario C: Software Fix (Instruction Scheduling)

Since hardware forwarding cannot completely cure a Load-Use hazard, the ultimate fix is **Code Reordering**.

**The Technique:** Move an independent instruction into the "Load Delay Slot" to fill the wait time.

```asm
loop:
    beq  t1, t0, end
    
    lw   t2, 0(a0)      # 1. Load Start
    
    # --- THE FIX ---
    # We move the pointer increment UP. 
    # This instruction does not depend on t2.
    # It executes while t2 is being fetched from memory.
    addi a0, a0, 4      
    # ---------------
    
    addi t3, t2, 100    # Now t2 is ready! Zero stalls.
    
    sw   t3, 0(a1)
    
    addi a1, a1, 4      # (Moved a0 increment up, kept a1 here)
    addi t1, t1, 1
    
    j    loop
```

**How It Works:**

```
Cycle:  1    2    3    4    5    6    7
lw t2:       IF   ID   EX   MEM  WB
                            ↓ Data ready
addi a0:          IF   ID   EX   MEM  WB  ← Independent! No hazard!
addi t3:               IF   ID   EX   MEM  WB  ← t2 is now ready!
                            ↑ No stall needed!
```

**Performance:**
- **Cycles:** ~35-40 cycles (Lowest possible)
- **CPI:** ~1.0 (Ideal)
- **Stalls per loop:** 0 bubbles

---

## ✅ Expected Output

### Functional Verification

Check the `dest` array in memory:

**Input:** `source = {10, 20, 30, 40, 50}`

**Operation:** Each element + 100

**Expected Output:** `dest = {110, 120, 130, 140, 150}`

> ⚠️ **All three scenarios must produce the same correct output!** The optimization only affects performance, not correctness.

### Register Values at End

| Register | Value | Description |
|----------|-------|-------------|
| `t0` | 5 | Loop count |
| `t1` | 5 | Iterator at exit |
| `a0` | source+20 | Past end of source array |
| `a1` | dest+20 | Past end of dest array |

---

## 📊 Performance Comparison

### Summary Table

| Method | Total Cycles | Stalls per Loop | CPI | Quality |
|--------|--------------|-----------------|-----|---------|
| **No Forwarding** | ~60-70 | 2-3 bubbles | >1.5 | ❌ Worst |
| **Forwarding (HW)** | ~45-50 | 1 bubble | ~1.2 | ⚠️ Good |
| **Reordering (SW)** | ~35-40 | 0 bubbles | ~1.0 | ✅ Best |

### Speedup Calculations

$$\text{Speedup}_{\text{Forwarding vs No-Forwarding}} = \frac{65}{47} \approx 1.38\times$$

$$\text{Speedup}_{\text{Reordering vs No-Forwarding}} = \frac{65}{37} \approx 1.76\times$$

$$\text{Speedup}_{\text{Reordering vs Forwarding}} = \frac{47}{37} \approx 1.27\times$$

---

## 🔍 Visualizing in Ripes

### How to See the Stalls

1. Set clock to **Manual** mode
2. Step through one cycle at a time
3. Watch for:
   - **Bubble/NOP** appearing in pipeline stages
   - Instruction stuck in ID stage while waiting
   - Forwarding paths highlighted (in forwarding mode)

### Pipeline Register Colors

| Color | Meaning |
|-------|---------|
| **Green** | Valid instruction in stage |
| **Red** | Flush/Stall signal |
| **Gray/Empty** | Bubble (NOP) |

---

## 🧠 Why This Matters

### The Load-Use Hazard is Special

Unlike ALU-ALU hazards (which forwarding can fully resolve), Load-Use hazards **always** have at least 1 cycle penalty because:

1. **Memory is slow**: Data isn't available until end of MEM stage
2. **Timing conflict**: EX stage needs data at the *beginning* of the cycle
3. **Physics limitation**: Can't forward data backward in time

### Solutions Hierarchy

```
┌─────────────────────────────────────────────────┐
│           LOAD-USE HAZARD SOLUTIONS             │
├─────────────────────────────────────────────────┤
│                                                 │
│  1. NO SOLUTION (Stall everything)              │
│     └── Worst: 2-3 cycle penalty               │
│                                                 │
│  2. HARDWARE: Forwarding                        │
│     └── Better: 1 cycle penalty (unavoidable)  │
│                                                 │
│  3. SOFTWARE: Instruction Scheduling            │
│     └── Best: 0 cycle penalty (hide latency)   │
│                                                 │
│  4. COMPILER: Automatic Scheduling              │
│     └── Same as #3, done automatically         │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## 📋 Lab Report Template

### Aim
To study Load-Use hazards in pipelined processors and compare hardware (forwarding) vs. software (scheduling) solutions.

### Theory
A Load-Use hazard occurs when an instruction tries to use a value immediately after it's loaded from memory. The data isn't available until the MEM stage completes, but the dependent instruction needs it in the EX stage.

### Apparatus
- Ripes RISC-V Simulator
- Test program with intentional Load-Use hazard

### Procedure
1. Run hazard code on 5-Stage Processor w/o Forwarding
2. Record cycles and observe stalls
3. Run same code on 5-Stage Processor w/ Forwarding
4. Record cycles and observe reduced stalls
5. Apply instruction scheduling fix
6. Record cycles and verify zero stalls

### Observations

| Configuration | Cycles | Stalls/Loop | CPI |
|---------------|--------|-------------|-----|
| No Forwarding | ___ | ___ | ___ |
| With Forwarding | ___ | ___ | ___ |
| With Scheduling | ___ | ___ | ___ |

### Result
- Forwarding reduced stalls from ___ to ___ per loop
- Scheduling eliminated stalls completely
- Overall speedup: ___×

### Discussion
1. Load-Use hazards are unavoidable in pipelined processors
2. Hardware forwarding reduces but doesn't eliminate the penalty
3. Software scheduling can hide the latency completely
4. Modern compilers perform this optimization automatically

---

## 🚀 Extensions

### 1. Multiple Loads in Sequence

```asm
lw   t2, 0(a0)      # Load 1
lw   t3, 4(a0)      # Load 2
add  t4, t2, t3     # Uses both!
```

How do you schedule this?

### 2. Longer Latency Loads

What if memory took 3 cycles instead of 1? How would you modify the scheduling?

### 3. Cache Miss Simulation

In real systems, cache misses cause much longer delays. How would the code change?

---

## 📚 Key Concepts

| Concept | Definition |
|---------|------------|
| **Load-Use Hazard** | RAW hazard where loaded data is needed immediately |
| **Data Forwarding** | Hardware that bypasses register file to reduce stalls |
| **Load Delay Slot** | The instruction slot after a load where hazard occurs |
| **Instruction Scheduling** | Reordering code to hide latency |
| **Bubble/NOP** | Empty pipeline cycle inserted during stall |
| **CPI** | Cycles Per Instruction - lower is better |

---

## 📚 References

- [Ripes GitHub Repository](https://github.com/mortbopet/Ripes)
- [RISC-V Specification](https://riscv.org/specifications/)
- Patterson & Hennessy, *Computer Organization and Design*

---

## 📄 License

This educational material is provided for learning purposes. Feel free to use and modify for your coursework and labs.
