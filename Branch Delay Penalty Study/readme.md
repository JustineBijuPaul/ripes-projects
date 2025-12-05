# Branch Delay Penalty Study for Ripes

A comprehensive study of **Control Hazards** and **Branch Penalties** in pipelined processors using the [Ripes](https://github.com/mortbopet/Ripes) RISC-V simulator.

This experiment visualizes how branch mispredictions cause pipeline flushes and "bubbles" (wasted cycles), and compares static vs. dynamic branch prediction strategies.

---

## 📁 Project Files

| File | Description |
|------|-------------|
| `count_evens.asm` | Test program that counts even numbers in an array (creates branch-heavy workload) |

---

## 🎯 What This Demonstrates

- **Control Hazards**: Pipeline stalls caused by branch instructions
- **Pipeline Flush**: Discarding speculatively fetched instructions after misprediction
- **Branch Prediction**: Static (Assume Not Taken) vs. Dynamic (2-bit Saturating Counter)
- **Performance Impact**: Measuring cycles lost due to branch penalties

---

## 🔬 Understanding Control Hazards

In a 5-stage pipeline, the processor fetches instructions **speculatively** before knowing if a branch is taken. If the prediction is wrong:

1. The pipeline must **flush** incorrectly fetched instructions
2. **Bubbles** (wasted cycles) are inserted
3. The correct instruction is fetched from the branch target

```
Branch Misprediction Timeline:
Cycle 1: BEQ in IF
Cycle 2: BEQ in ID, Wrong Inst in IF
Cycle 3: BEQ in EX (Decision Made!), Wrong Inst in ID, Another Wrong in IF
         ↓ FLUSH! ↓
Cycle 4: Correct Target in IF, Bubble in ID, Bubble in EX
```

---

## 🔧 Ripes Setup Instructions (Crucial)

### Step 1: Select Processor

1. Open **Ripes**
2. Click the **Processor Selection** icon
3. Select **RISC-V 32-bit**
4. Choose **5-Stage Processor** (Forwarding enabled for realism)

### Step 2: Configure Clock Mode

- Set to **Manual** or **Slow Auto-Clock** to observe flushes in real-time

### Step 3: Key Visualization

- In the processor diagram, watch the **IF/ID pipeline register**
- When a branch is mispredicted, it turns **RED** (indicating a flush)
- You'll see "bubbles" propagate through the pipeline

---

## 📝 Assembly Code

This program counts even numbers in an array, creating two types of branches:

1. **Conditional Branch (`bne`)**: Data-dependent, hard to predict
2. **Loop Branch (`beq`/`j`)**: Taken every iteration except the last

```asm
.data
    # 10 numbers: Mix of Odds and Evens
    # This forces the "Is it Even?" branch to switch behavior frequently
    array:  .word 12, 5, 8, 11, 20, 31, 42, 53, 60, 75 
    result: .word 0

.text
.globl main

main:
    la   a0, array      # Base address of array
    li   t0, 10         # Loop counter (N=10)
    li   t1, 0          # Current index (i)
    li   s0, 0          # Even number counter (Result)

loop:
    beq  t1, t0, end    # 1. LOOP EXIT BRANCH: Taken only once at the end
    
    lw   t2, 0(a0)      # Load array[i]
    
    # Check if Odd or Even
    andi t3, t2, 1      # Get Last Bit (1=Odd, 0=Even)
    
    # 2. CONDITIONAL BRANCH: "The Decision Maker"
    # If t3 != 0 (Odd), jump to 'skip'. 
    # If the predictor guesses wrong here, we lose 2-3 cycles!
    bne  t3, zero, skip 
    
    addi s0, s0, 1      # Increment Even Counter (Only if Even)

skip:
    addi a0, a0, 4      # Move array pointer
    addi t1, t1, 1      # i++
    
    # 3. UNCONDITIONAL JUMP (implicit loop back)
    j    loop           

end:
    la   a1, result
    sw   s0, 0(a1)      # Store result
    nop
```

---

## 🧪 Experiments

### Experiment A: Static Prediction (High Penalty)

**Setting:** Default Ripes configuration (assumes "Not Taken" for all branches)

**Behavior:**
- At `j loop` (jump back), the processor assumes we continue straight
- But we *always* jump back (except at exit)
- **Result:** Processor fetches wrong instruction, realizes mistake in EX stage, flushes pipeline

**What to Observe:**
1. Watch the IF/ID register turn **RED** after each `j loop`
2. Count the bubbles inserted into the pipeline
3. Note the high CPI in Statistics

---

### Experiment B: Dynamic Prediction (Low Penalty)

**Setting:** If your Ripes version has a **Branch Prediction** component, enable **2-bit Saturating Counter**

**Behavior:**
- **First Iteration:** Predicts wrong → Penalty paid
- **Second Iteration:** Predictor learns "this loop always jumps back"
- **Subsequent Iterations:** Predicts "Taken" → Correct fetch immediately
- **Result:** No flushes on loop jump!

**What to Observe:**
1. First iteration shows flush (learning phase)
2. Subsequent iterations have no flush on `j loop`
3. Note the lower CPI in Statistics

---

## ✅ Expected Output

### Functional Verification

Check the `result` variable in memory:

**Array:** `{12, 5, 8, 11, 20, 31, 42, 53, 60, 75}`

**Even numbers:** 12, 8, 20, 42, 60

**Expected Result:** `5`

### Register Values at End

| Register | Value | Description |
|----------|-------|-------------|
| `t0` | 10 | Loop count |
| `t1` | 10 | Final index |
| `s0` | 5 | Even number count |
| `a0` | addr+40 | Array pointer (past end) |

---

## 📊 Performance Comparison

### Statistics Tab Results

| Metric | Experiment A (Static) | Experiment B (Dynamic) |
|--------|----------------------|------------------------|
| **Total Cycles** | ~140 cycles | ~110 cycles |
| **Branch Hazards** | High | Low |
| **CPI** | **> 1.5** | **~ 1.1** |

### Why the Difference?

| Branch Type | Static Prediction | Dynamic Prediction |
|-------------|-------------------|-------------------|
| `j loop` (always taken) | Wrong every time → Flush | Learns after 1st iteration → No flush |
| `beq t1, t0, end` (taken once) | Correct 9 times, wrong once | Similar behavior |
| `bne t3, zero, skip` (data-dependent) | Random correctness | Can track pattern |

---

## 📈 Penalty Calculation

### Branch Penalty Formula

In a 5-stage RISC-V pipeline (decision made in EX stage):

$$\text{Penalty} = 2 \text{ cycles per misprediction}$$

### Cycles Lost Analysis

For 10 loop iterations:

**Without Prediction (Static "Not Taken"):**
$$\text{Cycles Lost} = 10 \times 2 = 20 \text{ cycles (just from } \texttt{j loop}\text{)}$$

Plus additional penalties from:
- `beq t1, t0, end` misprediction (1 time)
- `bne t3, zero, skip` mispredictions (variable)

**With Dynamic Prediction:**
$$\text{Cycles Lost} \approx 2 + 2 = 4 \text{ cycles}$$
- First `j loop` (learning)
- Final `beq` exit (pattern change)

---

## 🔍 Visualizing the Flush

### How to See Pipeline Flushes

1. Set clock to **Manual** mode
2. Step through execution one cycle at a time
3. Watch for:
   - **RED** pipeline registers (flush signal)
   - Instructions disappearing from pipeline stages
   - "NOP" or "Bubble" appearing in stages

### Pipeline Diagram: Misprediction

```
Cycle:  1     2     3     4     5     6     7
j loop: IF    ID    EX
next:         IF    ID   [FLUSH]
next+1:             IF   [FLUSH]
correct:                  IF    ID    EX   MEM   WB
                    ↑
            2 cycles wasted (bubbles)
```

### Pipeline Diagram: Correct Prediction

```
Cycle:  1     2     3     4     5     6
j loop: IF    ID    EX    MEM   WB
target:       IF    ID    EX    MEM   WB  ← No flush!
```

---

## 🧠 Branch Prediction Strategies

### Static Prediction

| Strategy | Rule | Best For |
|----------|------|----------|
| Always Not Taken | Predict fall-through | Forward branches (if statements) |
| Always Taken | Predict jump | Backward branches (loops) |
| BTFN | Backward=Taken, Forward=Not | Mixed code |

### Dynamic Prediction

| Predictor | State Machine | Accuracy |
|-----------|---------------|----------|
| 1-bit | Taken/Not Taken | Low (flip-flops on every change) |
| 2-bit Saturating | 4 states with hysteresis | High (tolerates occasional misprediction) |

#### 2-bit Saturating Counter States

```
Strong Not Taken → Weak Not Taken → Weak Taken → Strong Taken
       00       ←→       01       ←→     10    ←→      11
```

---

## 🚀 Software Solutions

### Loop Unrolling

Reduce branch frequency by processing multiple elements per iteration:

```asm
# Process 2 elements per iteration (50% fewer branches)
loop:
    # Element 0
    lw   t2, 0(a0)
    andi t3, t2, 1
    bne  t3, zero, skip0
    addi s0, s0, 1
skip0:
    # Element 1
    lw   t2, 4(a0)
    andi t3, t2, 1
    bne  t3, zero, skip1
    addi s0, s0, 1
skip1:
    addi a0, a0, 8      # Move 2 elements
    addi t1, t1, 2      # i += 2
    blt  t1, t0, loop
```

**Benefit:** Fewer `j loop` executions = fewer potential mispredictions

### Branch-Free Code

Replace branches with conditional moves (where possible):

```asm
# Instead of:
bne  t3, zero, skip
addi s0, s0, 1

# Use:
xori t3, t3, 1        # Flip: 1→0, 0→1
add  s0, s0, t3       # Add 0 or 1 (no branch!)
```

---

## 📋 Lab Report Template

### Aim
To study the impact of branch penalties on pipeline performance and compare static vs. dynamic branch prediction.

### Apparatus
- Ripes RISC-V Simulator
- Test program: Even number counter

### Procedure
1. Run program with static prediction (default)
2. Record cycles, CPI, and flush count
3. Enable dynamic prediction (if available)
4. Record metrics and compare

### Observations

| Metric | Static Prediction | Dynamic Prediction |
|--------|-------------------|-------------------|
| Total Cycles | ___ | ___ |
| CPI | ___ | ___ |
| Flushes Observed | ___ | ___ |

### Result

$$\text{Cycles Saved} = \text{Cycles}_{\text{static}} - \text{Cycles}_{\text{dynamic}} = \_\_\_$$

$$\text{Improvement} = \frac{\text{Cycles Saved}}{\text{Cycles}_{\text{static}}} \times 100\% = \_\_\_\%$$

### Discussion
- Branch penalties occur because decisions are made in EX stage
- Static prediction fails on always-taken loops
- Dynamic prediction learns patterns and reduces penalties
- Software techniques (unrolling, branch-free code) can also help

---

## 📚 Key Concepts

| Concept | Definition |
|---------|------------|
| **Control Hazard** | Pipeline stall caused by branch/jump instructions |
| **Branch Penalty** | Cycles wasted due to misprediction |
| **Pipeline Flush** | Discarding incorrectly fetched instructions |
| **Branch Prediction** | Hardware guess about branch direction |
| **Speculative Execution** | Fetching instructions before branch is resolved |
| **2-bit Saturating Counter** | Predictor that requires two wrong predictions to change state |

---

## 📚 References

- [Ripes GitHub Repository](https://github.com/mortbopet/Ripes)
- [RISC-V Specification](https://riscv.org/specifications/)
- Patterson & Hennessy, *Computer Organization and Design*

---

## 📄 License

This educational material is provided for learning purposes. Feel free to use and modify for your coursework and labs.
