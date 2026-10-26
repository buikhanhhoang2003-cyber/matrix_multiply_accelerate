# Codex Task — Implement FSM-Based 8×8 Matrix Multiplication Accelerator

You are an FPGA RTL engineer. Implement a complete, synthesizable **8×8 signed INT16 Matrix Multiplication Accelerator** using Verilog HDL.

The target FPGA is **Intel/Altera Cyclone IV EP4CE6**, but hardware pin assignments and the Quartus `.qsf` file will be added later.

**Do not implement PicoRV32, UART, or any board-specific pin assignments in this task.**

Work directly in the current repository. Inspect the existing project first and reuse any relevant code instead of unnecessarily replacing it.

## 1. Project Objective

Implement a standalone FSM-controlled matrix multiplier:

```text
Matrix A (8×8 INT16) ──┐
                       ├──> Matrix Controller FSM
Matrix B (8×8 INT16) ──┘           |
                                   v
                             2×2 PE Array
                             4 × INT16 MAC
                                   |
                                   v
                           Matrix C (8×8 INT35)
                                   |
                                   v
                             DONE / STATUS
```

The accelerator must calculate:

```text
C[i][j] = SUM(A[i][k] * B[k][j]), k = 0..7
```

Requirements:

- Matrix A: 8×8 signed INT16.
- Matrix B: 8×8 signed INT16.
- Matrix C: 8×8 signed INT35.
- 2×2 Processing Element Array.
- Four parallel signed MAC operations.
- Output-stationary accumulation.
- FSM-based control.
- No CPU required.
- No vendor-specific IP unless strictly necessary.

Use **Verilog-2001** for compatibility with Quartus.

## 2. Architecture

Implement these modules:

```text
rtl/
├── mac.v
├── pe_array.v
├── matrix_controller.v
├── matrix_buffer.v
├── matrix_accelerator.v
└── standalone_top.v

tb/
├── tb_mac.v
├── tb_pe_array.v
└── tb_matrix_accelerator.v

scripts/
├── golden_model.py
└── run_sim.sh

memory/
├── matrix_a.hex
└── matrix_b.hex

README.md
```

Adapt the file organization if the repository already has a suitable structure.

### 2.1 MAC Unit

Implement one signed INT16 multiply-accumulate unit.

- Signed 16×16 multiplication.
- Signed 35-bit accumulation.
- Synchronous clock.
- Reset/clear accumulator.
- Accumulate enable.
- Correct sign extension.
- Deterministic behavior after reset.

Avoid unnecessary pipeline complexity.

### 2.2 2×2 PE Array

Implement four MAC units operating in parallel.

For one 2×2 output tile:

```text
             B[k][j]     B[k][j+1]
                |             |
                v             v
A[i][k]   ---> PE00          PE01
A[i+1][k] ---> PE10          PE11
```

Broadcast A operands across columns and B operands across rows.

Each PE computes one output element.

Reuse the same PE Array for all 16 output tiles.

Do not instantiate 64 independent multipliers.

### 2.3 Matrix Controller FSM

Implement a simple FSM controlling all 16 tiles.

Suggested states:

```text
IDLE
  |
  v
INIT
  |
  v
LOAD
  |
  v
MAC
  |
  +---- k < 7 ----> LOAD
  |
  v
STORE
  |
  +---- Next tile ----> INIT
  |
  v
DONE
```

Responsibilities:

- Track tile row and column.
- Track accumulation index `k`.
- Generate correct A/B memory addresses.
- Clear PE accumulators at the beginning of each tile.
- Load operands.
- Execute MAC operations.
- Store four output results.
- Assert DONE after all 64 outputs are written.
- Support repeated START operations without resetting FPGA.

Keep the FSM simple and readable.

For synchronous memory, explicitly handle read latency. Do not assume operands become available immediately after changing addresses.

### 2.4 Matrix Buffers

Provide storage for:

```text
A: 64 × 16 bits
B: 64 × 16 bits
C: 64 × 35 bits
```

Use synthesizable Verilog arrays.

Support loading A and B through a simple write interface:

```text
input_write_enable
input_matrix_select
input_address
input_data
```

Provide a read interface for Matrix C.

Define the exact signal names and handshake consistently across modules.

A and B must not be permanently hard-coded inside the accelerator core.

Memory implementation must support the two A and two B operands needed by the 2×2 PE Array.

You may implement banking, preload registers, or additional read cycles. Choose the simplest architecture that is correct and practical for EP4CE6.

Avoid assuming that one simple dual-port RAM can supply four independent reads per cycle.

### 2.5 Matrix Accelerator Top

Implement a reusable module:

```verilog
module matrix_accelerator (
    input wire clk,
    input wire rst_n,
    input wire start,

    // Input matrix write interface
    // Output matrix read interface

    output wire busy,
    output wire done
);
```

Complete the memory access ports with well-defined widths.

Behavior:

- `start` is accepted when idle.
- `busy` is high while calculating.
- `done` remains asserted until the next accepted START or reset.
- All 64 output values must be valid when DONE is asserted.
- Repeated computation must not reuse stale accumulator values.

Keep this module independent of ROM, LED, UART, and PicoRV32.

### 2.6 Standalone Top

Implement `standalone_top.v` for the FSM-only phase.

It should:

- Load two predefined 8×8 matrices from simulation/synthesis-friendly initialization files or ROM.
- Start the accelerator.
- Wait for completion.
- Compare all 64 results against expected values.
- Generate `pass`, `fail`, and `done` outputs.

Make the initialization method explicit and compatible with simulation. Avoid relying on simulation-only initialization inside the accelerator.

Do not assign FPGA pins.

## 3. Testbench Requirements

Implement self-checking testbenches. A waveform-only test is insufficient.

### 3.1 MAC Testbench

Test:

- Positive multiplication.
- Negative multiplication.
- Negative × negative.
- Zero operands.
- Accumulation over multiple cycles.
- Accumulator clear.
- INT16 boundary values.

Use an independently calculated expected result.

### 3.2 PE Array Testbench

Verify that all four MACs produce correct and independent results.

Test:

- Operand broadcasting.
- Correct PE mapping.
- Accumulator clearing.
- Multiple MAC iterations.
- Mixed positive and negative values.

### 3.3 Full Accelerator Testbench

Required tests:

| Test ID | Description | Expected |
|---|---|---|
| TC01 | Zero matrices | All C elements are zero |
| TC02 | Identity × matrix | C equals input matrix |
| TC03 | Constant matrices A=2, B=3 | All C elements equal 48 |
| TC04 | Mixed positive and negative values | Correct signed results |
| TC05 | INT16 minimum/maximum | Correct 35-bit results |
| TC06 | Deterministic random matrices | Matches golden model |
| TC07 | Two consecutive START operations | Both runs produce correct results |

For every test:

1. Load both matrices.
2. Trigger START.
3. Wait for DONE with a timeout.
4. Read all 64 output elements.
5. Compare every element with an independent reference result.
6. Report PASS/FAIL.

Print a helpful mismatch message:

```text
FAIL: C[row][col]
Expected: ...
Actual: ...
```

The overall simulation must fail with a non-zero exit status if any test fails.

Do not compare against hard-coded values generated by the same RTL logic under test.

## 4. Python Golden Model

Implement `scripts/golden_model.py`.

Requirements:

- Generate deterministic test matrices.
- Calculate C = A × B using Python integer arithmetic or NumPy with a sufficiently wide integer type.
- Handle signed INT16 correctly.
- Validate the signed 35-bit output range.
- Generate input initialization files.
- Generate expected results for the testbench.
- Support a repeatable random seed.

The golden model must be independent of the Verilog implementation.

## 5. Simulation Script

Implement:

```bash
bash scripts/run_sim.sh
```

The script should:

1. Generate required test vectors.
2. Compile the MAC testbench.
3. Run the MAC tests.
4. Compile and run PE Array tests.
5. Compile and run the full accelerator tests.
6. Stop immediately if any test fails.
7. Print a final PASS message only if all tests succeed.

Prefer Icarus Verilog (`iverilog` and `vvp`).

Use available tools in the environment. If a simulator is unavailable, report this clearly and still provide the complete scripts. Do not claim tests passed without executing them.

Do not require a Quartus license or FPGA hardware for simulation.

## 6. RTL Coding Rules

Follow these rules:

- Use simple, synthesizable Verilog-2001.
- Keep each module focused on one responsibility.
- Prefer straightforward FSM logic.
- Avoid unnecessary helper modules and complicated abstractions.
- Avoid excessive fallback logic.
- Avoid unnecessary parameters and configuration options.
- Define signal widths explicitly.
- Handle signed arithmetic correctly.
- Use nonblocking assignments in sequential logic.
- Use blocking assignments in combinational logic.
- Avoid inferred latches.
- Avoid unsized constants where widths matter.
- Do not introduce hidden extra cycles without accounting for them.
- Avoid large combinational multiplication networks.
- Do not hard-code test data inside MAC or PE modules.
- Keep the accelerator reusable for future MMIO integration.
- Add comments only where the hardware behavior is not obvious.

Preserve a clear separation between:

```text
Datapath: MAC + PE Array
Control: FSM
Storage: Matrix Buffers
Integration: Accelerator Top
Verification: Testbenches
```

## 7. FPGA Constraints

Target device:

```text
Intel Cyclone IV EP4CE6
```

Resource considerations:

- Approximately 6,272 Logic Elements.
- 15 embedded 18×18 multipliers.
- 30 M9K memory blocks.

The initial design should use four signed 16×16 MAC multipliers.

Favor hardware resource efficiency and a reasonable operating frequency.

Do not implement PicoRV32.

Do not implement UART.

**Do not create a `.qsf` file or pin assignments. They will be added later when the actual board pinout is confirmed.**

A `.qpf` or other Quartus project setup is also not required at this stage.

## 8. Future Compatibility

The accelerator will later be integrated into a PicoRV32 SoC.

Therefore:

- Keep START/BUSY/DONE as a stable control interface.
- Make input and output buffers externally accessible.
- Do not place standalone ROM/checker logic inside the accelerator.
- Do not depend on specific FPGA pins.
- Allow multiple consecutive matrix multiplications.
- Make the interface suitable for a future MMIO adapter.

Do not implement the MMIO adapter yet.

## 9. README Documentation

Create or update `README.md` with:

1. Project overview.
2. Architecture diagram using Mermaid.
3. Module descriptions.
4. FSM state transitions.
5. Matrix memory organization.
6. Accelerator control interface.
7. Simulation instructions.
8. Test cases and expected results.
9. Known limitations.
10. Future PicoRV32 integration plan.

Explain the actual cycle behavior of the implemented design instead of claiming the ideal 128-cycle latency.

## 10. Execution Instructions

Implement the project, not just an architecture proposal.

Follow this sequence:

1. Inspect the repository.
2. Identify existing relevant RTL and tests.
3. Implement MAC and PE Array.
4. Implement memory and FSM.
5. Implement matrix accelerator integration.
6. Implement the standalone top.
7. Implement Python golden model.
8. Implement self-checking testbenches.
9. Run the simulation script.
10. Fix failures until all executable tests pass.
11. Review code for synthesis compatibility.
12. Update README.

Do not stop after generating skeleton modules or TODO placeholders.

Do not create unsupported claims about Quartus synthesis or FPGA resource utilization. If Quartus is unavailable, leave hardware synthesis and timing verification pending.

## 11. Expected Final Output

After implementation, provide:

- A short architecture summary.
- List of created or modified files.
- Explanation of the FSM and 2×2 PE dataflow.
- Actual simulation test results.
- Command to reproduce tests.
- Known limitations.
- Items remaining before FPGA hardware integration.

**Final success condition:**

```text
MAC Testbench:         PASS
PE Array Testbench:    PASS
Matrix Accelerator:    PASS
All 64 Output Values:  PASS
Repeated START:        PASS
```

The first development milestone is a fully simulated, reusable FSM-based matrix multiplication accelerator.

**Do not proceed with PicoRV32, UART, QSF, or TinyML unless explicitly requested later.**
