# Function Call Overhead Analysis for Ripes

A comprehensive analysis of **function call overhead** in pipelined processors using the [Ripes](https://github.com/mortbopet/Ripes) RISC-V simulator.

This project measures the cost of `jal`/`jalr` instructions and stack frame operations on a 5-stage pipeline, comparing against an inlined version to quantify the overhead.

---

## 📁 Project Files

| File | Description |
|------|-------------|
| `func_call.asm` | Program with function calls and stack frame operations |
| `func_inline.asm` | Equivalent program with inlined code (no calls) |

---

## 🎯 What This Demonstrates

- **Function call mechanics**: `jal` (jump and link) and `jalr` (return)
- **Stack frame operations**: Prologue (save registers) and epilogue (restore registers)
- **Control hazards**: Pipeline flushes caused by jumps and returns
- **Overhead quantification**: Cycles and instructions lost to calling convention

---

## 🔬 Understanding Function Call Overhead

### Components of Function Call Cost

```
┌─────────────────────────────────────────────────────────────┐
│                  FUNCTION CALL OVERHEAD                     │
├─────────────────────────────────────────────────────────────┤
│  1. CALLER SIDE                                             │
│     └── jal ra, func     (1 instruction + control hazard)   │
│                                                             │
│  2. CALLEE PROLOGUE                                         │
│     ├── addi sp, sp, -N  (allocate stack frame)            │
│     ├── sw ra, N-4(sp)   (save return address)             │
│     └── sw s0, N-8(sp)   (save callee-saved registers)     │
│                                                             │
│  3. FUNCTION BODY                                           │
│     └── (actual work)                                       │
│                                                             │
│  4. CALLEE EPILOGUE                                         │
│     ├── lw s0, N-8(sp)   (restore callee-saved registers)  │
│     ├── lw ra, N-4(sp)   (restore return address)          │
│     ├── addi sp, sp, N   (deallocate stack frame)          │
│     └── jalr x0, 0(ra)   (return + control hazard)         │
└─────────────────────────────────────────────────────────────┘
```

### Pipeline Impact

Each `jal` and `jalr` causes a **control hazard** in the 5-stage pipeline:

```
jal:    IF   ID   EX   MEM   WB
next:        IF   --   --    (FLUSHED - wrong path)
target:           IF   ID    EX   MEM   WB
```

---

## 🔧 Ripes Setup Instructions

### Step 1: Load the Program

1. Open **Ripes** (or [ripes.me](https://ripes.me))
2. Go to the **Editor** tab
3. Set **Input type: Assembly**
4. Paste the code (see below)
5. Click the **hammer icon** to assemble

### Step 2: Select Processor

1. Go to the **Processor** tab
2. Click the **CPU/chip icon** (Select Processor)
3. Select: **`RISC-V 5-Stage Processor`** (with hazard detection + forwarding)
4. Click **Reset**

### Step 3: Run the Program

1. In the **Program** view, set a **breakpoint** at the `end:` label
2. Open **Registers** pane (watch x2, x6, x7, x10, ra, s0)
3. Open **Statistics** pane (Cycles, Instructions, CPI)
4. Click **Run** - execution stops at `end:`

---

## 📝 Assembly Code: Function Call Version

```asm
##############################################################
# Function Call Overhead Demo (Ripes RV32I)
#
# Goal:
#   - Measure overhead of jal/jalr + stack frame in a 5-stage pipeline
#   - main() calls func() many times
#
# main:
#   for i in [0 .. ITER-1]:
#       x10 = func(x10)
#
# func:
#   Prologue: save ra and s0 on stack
#   Body:     x10 = x10 + 1
#   Epilogue: restore s0, ra; return with jalr
##############################################################

    .data
ITER:      .word 100        # Number of function calls
RESULT:    .word 0          # Store final x10 here

    .text
    .globl _start
_start:
    ##########################################################
    # 1. Setup stack pointer and loop variables
    ##########################################################
    # Ripes usually initializes x2 (sp) to 0x10000000 (or similar),
    # but we set it manually to be explicit and safe.
    #
    # NOTE: Adjust the stack base address if your Ripes config differs.
    ##########################################################
    lui   x2, 0x10010       # x2 = 0x10010_000 (example stack base)
                            # (upper bits only; low 12 bits = 0)

    la    x5, ITER          # x5 = &ITER
    lw    x6, 0(x5)         # x6 = ITER (loop count)
    addi  x10, x0, 0        # x10 = 0 (argument / accumulator)
    addi  x7, x0, 0         # x7 = loop counter i = 0

##############################################################
# main loop: call func() ITER times
##############################################################
loop:
    # Call func with x10 as input/output
    jal   ra, func          # ra = return address, jump to func

    addi  x7, x7, 1         # i++
    blt   x7, x6, loop      # if (i < ITER) continue loop

    # After loop: x10 should be ITER (each func adds 1)

    # Store result to memory
    la    x8, RESULT
    sw    x10, 0(x8)

    # Done
end:
    nop                     # Put breakpoint here in Ripes

##############################################################
# func(x10):
#   Prologue:
#       sp -= 8
#       sw ra, 4(sp)
#       sw s0, 0(sp)
#
#   Body:
#       s0 = x10
#       x10 = s0 + 1
#
#   Epilogue:
#       lw s0, 0(sp)
#       lw ra, 4(sp)
#       sp += 8
#       ret  (jalr x0, 0(ra))
##############################################################
func:
    # Prologue: create stack frame, save ra and s0
    addi  x2, x2, -8        # sp -= 8
    sw    ra, 4(x2)         # store return address at [sp+4]
    sw    s0, 0(x2)         # store s0 at [sp]

    # Body: s0 = x10; x10 = x10 + 1
    add   s0, x10, x0       # s0 = x10
    addi  x10, s0, 1        # x10 = s0 + 1

    # Epilogue: restore s0 and ra, destroy frame, return
    lw    s0, 0(x2)         # restore s0
    lw    ra, 4(x2)         # restore ra
    addi  x2, x2, 8         # sp += 8

    jalr  x0, 0(ra)         # return; PC = ra
```

> **Note:** If your Ripes version doesn't recognize `s0`, use `x8` instead (they're the same register in RV32I).

---

## 📝 Assembly Code: Inline Version (No Calls)

For comparison, here's the equivalent program with the function body inlined:

```asm
##############################################################
# Inline Version (No Function Calls)
# Same computation, but without jal/jalr or stack operations
##############################################################

    .data
ITER:      .word 100
RESULT:    .word 0

    .text
    .globl _start
_start:
    la    x5, ITER
    lw    x6, 0(x5)         # x6 = ITER
    addi  x10, x0, 0        # x10 = 0 (accumulator)
    addi  x7, x0, 0         # x7 = loop counter i = 0

loop_inline:
    # --- INLINE VERSION OF func() ---
    # No prologue, no epilogue, no jal/jalr
    addi  x10, x10, 1       # x10 = x10 + 1 (the actual work)
    # ---------------------------------

    addi  x7, x7, 1         # i++
    blt   x7, x6, loop_inline

    la    x8, RESULT
    sw    x10, 0(x8)

end:
    nop
```

---

## ✅ Expected Output

### With ITER = 100:

#### Register Values at End

| Register | Value | Description |
|----------|-------|-------------|
| `x6` | 100 | ITER (loop bound) |
| `x7` | 100 | Loop counter (stopped when x7 == x6) |
| `x10` | 100 | Result: 100 calls × (+1 each) |
| `x2` (sp) | Original value | Stack pointer restored |
| `ra` | Code address | Last return address |
| `s0` (x8) | 0 | Restored original value |

#### Memory Values

| Label | Value | Description |
|-------|-------|-------------|
| `RESULT` | 100 | Final value of x10 |

### Sanity Checks

1. **Loop correctness:** `x7 == x6 == ITER`
2. **Function result:** `x10 == ITER` (each call increments by 1)
3. **Stack correctness:** `x2` at end equals initial value (balanced push/pop)

---

## 📊 Performance Analysis

### Measuring Overhead

From the **Statistics** panel, record for both versions:

| Metric | Function Call Version | Inline Version |
|--------|----------------------|----------------|
| Cycles | Cycles_call | Cycles_inline |
| Instructions | Instr_call | Instr_inline |
| CPI | CPI_call | CPI_inline |

### Overhead Calculations

**Extra cycles per call:**
$$\text{Overhead}_{\text{cycles}} = \frac{\text{Cycles}_{\text{call}} - \text{Cycles}_{\text{inline}}}{\text{ITER}}$$

**Extra instructions per call:**
$$\text{Overhead}_{\text{instr}} = \frac{\text{Instr}_{\text{call}} - \text{Instr}_{\text{inline}}}{\text{ITER}}$$

### Expected Results (Approximation)

| Metric | Function Calls | Inline | Difference |
|--------|----------------|--------|------------|
| **Cycles** | ~1500 | ~500 | ~1000 extra |
| **Instructions** | ~1200 | ~400 | ~800 extra |
| **CPI** | ~1.25 | ~1.25 | Similar |

**Per-call overhead:**
- ~10 extra cycles
- ~8 extra instructions (prologue + epilogue + jal + jalr)

---

## 🔍 Understanding the Overhead Sources

### Instruction Overhead Per Call

| Operation | Instructions | Purpose |
|-----------|--------------|---------|
| `jal ra, func` | 1 | Jump to function |
| `addi sp, sp, -8` | 1 | Allocate stack frame |
| `sw ra, 4(sp)` | 1 | Save return address |
| `sw s0, 0(sp)` | 1 | Save callee-saved register |
| `lw s0, 0(sp)` | 1 | Restore callee-saved register |
| `lw ra, 4(sp)` | 1 | Restore return address |
| `addi sp, sp, 8` | 1 | Deallocate stack frame |
| `jalr x0, 0(ra)` | 1 | Return to caller |
| **Total Overhead** | **8** | Per function call |

### Cycle Overhead (Pipeline Effects)

| Source | Extra Cycles | Reason |
|--------|--------------|--------|
| `jal` | 2 | Control hazard (pipeline flush) |
| `jalr` | 2 | Control hazard (pipeline flush) |
| `sw` instructions | 0-1 | Possible stalls |
| `lw` instructions | 1 each | Load-use hazards |
| **Total per call** | ~8-10 | Varies with forwarding |

---

## 🧠 Stack Frame Visualization

### During Function Execution

```
High Address
┌─────────────────┐
│                 │
│  (caller's      │
│   stack frame)  │
│                 │
├─────────────────┤ ← SP before call
│   ra (4 bytes)  │ sp + 4
├─────────────────┤
│   s0 (4 bytes)  │ sp + 0
├─────────────────┤ ← SP during func (after prologue)
│                 │
│  (available     │
│   stack space)  │
│                 │
└─────────────────┘
Low Address
```

### Stack Operations Timeline

```
Before call:    SP = 0x10010000
                ↓
Prologue:       addi sp, sp, -8     → SP = 0x1000FFF8
                sw ra, 4(sp)        → [0x1000FFFC] = ra
                sw s0, 0(sp)        → [0x1000FFF8] = s0
                ↓
Function body:  (work happens)
                ↓
Epilogue:       lw s0, 0(sp)        → s0 = [0x1000FFF8]
                lw ra, 4(sp)        → ra = [0x1000FFFC]
                addi sp, sp, 8      → SP = 0x10010000 (restored!)
                jalr x0, 0(ra)      → return
```

---

## 📋 Lab Report Template

### Aim
To measure the overhead of function calls (jal/jalr and stack operations) in a pipelined RISC-V processor.

### Theory
Function calls in RISC-V require:
1. **jal**: Jump to function, save return address in `ra`
2. **Prologue**: Save caller-saved registers and return address to stack
3. **Epilogue**: Restore registers from stack
4. **jalr**: Return to caller using saved address

Each jump causes a control hazard (2-cycle flush), and stack operations add instruction overhead.

### Apparatus
- Ripes RISC-V Simulator
- Two test programs: function call version and inline version

### Procedure
1. Run function call version, record Cycles, Instructions, CPI
2. Run inline version with same computation
3. Calculate per-call overhead
4. Analyze pipeline effects

### Observations

| Version | Cycles | Instructions | CPI |
|---------|--------|--------------|-----|
| Function Calls | ___ | ___ | ___ |
| Inline | ___ | ___ | ___ |
| **Difference** | ___ | ___ | ___ |

**Per-call overhead:**
- Cycles: ___ / ITER = ___ cycles/call
- Instructions: ___ / ITER = ___ instr/call

### Result
Function call overhead is approximately ___ cycles and ___ instructions per call.

### Discussion
1. **Control hazards**: `jal` and `jalr` cause pipeline flushes (~4 cycles total)
2. **Stack operations**: 4 memory instructions (2 stores, 2 loads) add overhead
3. **When to inline**: Small, frequently-called functions benefit from inlining
4. **Trade-offs**: Inlining increases code size but improves performance

---

## 🚀 Extensions

### 1. Nested Function Calls

Add a helper function called from `func`:

```asm
func:
    # prologue...
    jal ra, helper      # Nested call!
    # epilogue...

helper:
    # More overhead!
    jalr x0, 0(ra)
```

### 2. Vary ITER

Test with different iteration counts:

| ITER | Total Overhead | Per-Call Overhead |
|------|----------------|-------------------|
| 10 | ___ | ___ |
| 100 | ___ | ___ |
| 1000 | ___ | ___ |

### 3. More Callee-Saved Registers

Expand the stack frame to save more registers:

```asm
func:
    addi sp, sp, -20    # Larger frame
    sw ra, 16(sp)
    sw s0, 12(sp)
    sw s1, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)
    # ...more overhead!
```

### 4. Single-Cycle vs. Pipelined

Compare overhead on:
- `RISC-V Single Cycle Processor`
- `RISC-V 5-Stage Processor`

---

## 📚 Key Concepts

| Concept | Definition |
|---------|------------|
| **jal** | Jump And Link - jumps to target, saves return address in rd |
| **jalr** | Jump And Link Register - jumps to address in rs1, saves return address |
| **Stack Frame** | Memory allocated on stack for function's local data and saved registers |
| **Prologue** | Code at function entry that sets up stack frame |
| **Epilogue** | Code at function exit that tears down stack frame |
| **Callee-Saved** | Registers that a function must preserve (s0-s11 in RISC-V) |
| **Caller-Saved** | Registers that caller must save if needed across calls (a0-a7, t0-t6) |
| **Control Hazard** | Pipeline stall caused by branch/jump instructions |

---

## 📚 RISC-V Calling Convention Summary

### Register Usage

| Register | ABI Name | Usage | Saved By |
|----------|----------|-------|----------|
| x0 | zero | Hardwired zero | - |
| x1 | ra | Return address | Caller |
| x2 | sp | Stack pointer | Callee |
| x5-x7 | t0-t2 | Temporaries | Caller |
| x8 | s0/fp | Saved/Frame pointer | Callee |
| x9 | s1 | Saved register | Callee |
| x10-x11 | a0-a1 | Arguments/Return values | Caller |
| x12-x17 | a2-a7 | Arguments | Caller |
| x18-x27 | s2-s11 | Saved registers | Callee |
| x28-x31 | t3-t6 | Temporaries | Caller |

---

## 📚 References

- [Ripes GitHub Repository](https://github.com/mortbopet/Ripes)
- [RISC-V Specification](https://riscv.org/specifications/)
- [RISC-V Calling Convention](https://riscv.org/wp-content/uploads/2015/01/riscv-calling.pdf)
- Patterson & Hennessy, *Computer Organization and Design*

---

## 📄 License

This educational material is provided for learning purposes. Feel free to use and modify for your coursework and labs.
