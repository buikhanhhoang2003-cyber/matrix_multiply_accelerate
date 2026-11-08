# UART-controlled 8×8 systolic matrix multiplier

Enter two **8×8 signed integer matrices** over a USB-to-TTL UART adapter, then print **C = A × B** in your terminal. A small **2×2 systolic array** computes all 16 output tiles on the Cyclone IV **EP4CE6E22C8** at 50 MHz.

## Controls and status display

Use the **red DIP switch block**, with only one switch ON at a time. Leave pushbuttons S1–S4 released, since they share the DIP inputs.

| DIP selection | DIG1 shows | UART operation |
| --- | --- | --- |
| All OFF | Blank | Idle; retain completed A and B |
| **1 ON** | **1** | Prompt `A:64`, then receive 64 values for matrix A |
| **2 ON** | **2** | Prompt `B:64`, then receive 64 values for matrix B |
| **3 ON** | **3** | Compute and print all 64 values of C, followed by `DONE` |
| 4 | — | Unused |

The displayed number identifies the selected stage and remains visible until the stage changes. UART messages report readiness, completion and errors. Reset clears the matrix-ready flags, blanks the display, and sends `READY`.

The separate user LEDs show which matrices are ready:

| LED | Turns ON when | Turns OFF when |
| --- | --- | --- |
| **LED1** | All 64 values of **A** are stored | Starting a replacement A or resetting |
| **LED2** | All 64 values of **B** are stored | Starting a replacement B or resetting |
| **LED3** | **C** has finished computing and is ready to print | Starting a replacement A/B, starting another multiplication, or resetting |
| LED4 | Unused; always OFF | — |

These indicators accumulate: after A and B are loaded, LED1 and LED2 are both ON; after multiplication, all three are ON. They remain ON with the DIP switches OFF. LED3 is cleared whenever an input matrix is replaced, so it cannot indicate a result for stale inputs. All LEDs are OFF after reset. The LEDs are active low internally.

Selections are debounced for 10 ms. If multiple switches are ON, priority is **3 > 2 > 1**. Turning a higher-priority switch OFF can select a lower switch that is still ON and start a new input transaction; using one switch at a time avoids this.

## 1. Connect your USB-to-TTL adapter

Confirm that the adapter's **TXD signal uses 3.3 V logic** before connecting it. A pin marked `3V3` may only be a power output; check the adapter's signal-level setting. A 5 V TXD needs level shifting.

| Adapter pin | Board connection | Purpose |
| --- | --- | --- |
| **RXD** | Header pad **114**, P1 contact **7** (`uart_tx`) | Receive prompts and C on the PC |
| **TXD** | Header pad **111**, P1 contact **4** (`gpio`) | Send matrix values to the FPGA |
| **GND** | Board **GND**, e.g. P1 contact 1 or 2 | Common signal ground |
| **VCC / 5V / 3V3** | **Leave disconnected** | Power the board separately |

**111** and **114** are FPGA pin numbers printed beside the expansion header, not header contact numbers. Check the pad labels and supplied schematic for your PCB revision. Wire colors vary between adapters.

The [FPGA-UART-TX reference](../../FPGA-UART-TX/README.md) demonstrates transmission on pin 114. This project receives on spare pin 111. **Keep adapter TXD off pin 115:** the onboard MAX3232 already drives that pin. The DB9 connector is unused by this build, and no MAX3232 modification is required.

With board power and the adapter USB disconnected, attach the three signal wires and connect the USB-Blaster to the **JTAG** header. Set all DIP switches OFF. Power the board through its USB power connector or a suitable 5 V adapter, then connect the UART adapter to the PC. The board's own USB connector supplies power; the separate UART adapter provides the COM port.

According to the board manual, pressing the red power selector selects USB power and releasing it selects the DC adapter; verify this on your revision. Disconnect power and the UART adapter before rewiring. Connect/remove the JTAG cable while the board is powered off.

## 2. Compile and program

Copy this complete directory to the computer running Quartus, including the updated baud generator and new matrix core. Open [my_uart_top.qpf](my_uart_top.qpf), with device **EP4CE6E22C8** and top-level entity **my_uart_top**.

The synthesis file list in [my_uart_top.qsf](my_uart_top.qsf) must contain all five files:

```text
my_uart_top.v
my_uart_rx.v
my_uart_tx.v
speed_select.v
matrix_systolic.v
```

Run **Processing > Start Compilation**. In **Tools > Programmer**, select USB-Blaster, use **JTAG** mode, load the newly built `output_files/my_uart_top.sof`, select **Program/Configure**, and click **Start**. The board must be powered during programming. The `.sof` configuration is volatile and must be programmed again after a power cycle.

Command-line compilation, when Quartus is on your PATH:

```bash
cd /home/hoangb/workspace/matrix_multiply_accelerate/main_software_rtl
quartus_sh --flow compile my_uart_top
```

The project still sources the full [cyclone_iv_board_v3.qsf](cyclone_iv_board_v3.qsf), copied unchanged from:

```text
/home/hoangb/workspace/Altera-Cyclone-IV-board-V3.0/cyclone_iv_board_v3.qsf
```

That file supplies device settings and all 88 board assignments. Project HDL files and timing-file selection stay in `my_uart_top.qsf`; importing the board QSF alone does not add the RTL sources. Assignments for peripherals absent from the top level may produce ignored-assignment warnings. Check warnings about any port actually used by this design. Unused FPGA pins are configured as input tri-state.

## 3. Open the serial terminal

Select your USB-to-TTL adapter's actual COM port or Linux serial device.

| Setting | Value |
| --- | --- |
| Baud rate | **9600** |
| Data bits / parity / stop bits | **8 / None / 1** |
| Hardware/software flow control | **None** |
| Send format | **Text / ASCII** |
| Local echo | **On**, to see your typing; the FPGA also prints each completed matrix as a table |
| Local line editing | Enable in PuTTY if you want Backspace editing before Enter |

Press and release the board's reset button on pin 25 after opening the terminal. Expect `READY` and a blank display.

## 4. Enter A, enter B, then print C

1. Turn **DIP1 ON**, leaving the others OFF. DIG1 shows **1**. **Wait for `A:64`.**
2. Type or paste **64 integers**, in row order: all eight values of row 0, then row 1, and so on. Press Enter after the final value. **LED1 turns ON** and the FPGA prints `Matrix A:` followed by eight formatted rows. Wait for **`A OK`** after the table.
3. Turn DIP1 OFF. Wait for `IDLE`, then turn **DIP2 ON**. DIG1 shows **2**. **Wait for `B:64`.**
4. Send 64 integers for B in the same order. Press Enter. **LED2 turns ON** and the FPGA prints `Matrix B:` and its eight rows. Wait for **`B OK`** after the table.
5. Turn DIP2 OFF. Wait for `IDLE`, then turn **DIP3 ON**. DIG1 shows **3**. **LED3 turns ON when computation finishes**. The terminal prints `Matrix C:`, eight result rows, and **`DONE`**.
6. Leave DIP3 ON to retain the displayed stage. To print the same multiplication again, turn DIP3 OFF, wait for `IDLE`, then turn it ON again. A and B remain stored.

A run occurs once per DIP3 selection. Selecting DIP1 or DIP2 again starts a replacement matrix from element 0 and invalidates that matrix until all 64 values arrive. Changing selection during an incomplete entry discards it. Switch changes during computation/output are applied after the response finishes.

Each matrix is printed as **8 rows of 8 values**, with a space between values and **CR+LF (`0x0D 0x0A`) after every row**. A blank line and the matrix label separate the tables. A and B are printed after their 64th value is committed, so pasting values on one long line still produces a clear 8×8 table. The printed values are read back from FPGA memory, not copied from the input text. Wait for the complete table and its acknowledgement before sending the next matrix.

### Input format and errors

- Each value is a signed decimal integer in **−32768 through 32767**, with an optional `+` or `-` sign.
- Separate values with spaces, commas, tabs, or line breaks. Eight values per line is convenient but not mandatory.
- **The 64th number needs a delimiter:** press Enter after it to commit the final value.
- Use exactly 64 values per matrix and wait for the acknowledgement before continuing. Extra data after completion and data sent during computation/output are ignored.
- Fractional numbers, hex notation and raw Backspace/control bytes are invalid. Use the terminal's local line editing or prepare/paste the matrix.

| UART message | Meaning / action |
| --- | --- |
| `READY` | Reset complete; select a stage |
| `A:64` / `B:64` | Ready for 64 values of the selected matrix |
| `Matrix A:` / `Matrix B:` | Eight rows read back from the completed input matrix |
| `A OK` / `B OK` | All 64 values stored and the input matrix table printed |
| `Matrix C:` | Eight rows of multiplication results follow |
| `ERR NUMBER` | Invalid token or INT16 overflow; switch OFF, wait for `IDLE`, reselect, and resend the whole matrix |
| `ERR INPUT` | DIP3 selected before both matrices are complete; finish loading A/B before running |
| `DONE` | All eight result rows transmitted |

### Copy-and-paste example

Load this identity matrix as **A**:

```text
1 0 0 0 0 0 0 0
0 1 0 0 0 0 0 0
0 0 1 0 0 0 0 0
0 0 0 1 0 0 0 0
0 0 0 0 1 0 0 0
0 0 0 0 0 1 0 0
0 0 0 0 0 0 1 0
0 0 0 0 0 0 0 1
```

After `A OK`, select B and load:

```text
1 2 3 4 5 6 7 8
9 10 11 12 13 14 15 16
17 18 19 20 21 22 23 24
25 26 27 28 29 30 31 32
33 34 35 36 37 38 39 40
41 42 43 44 45 46 47 48
49 50 51 52 53 54 55 56
57 58 59 60 61 62 63 64
```

Press Enter after the final row if your paste does not include a trailing newline. The terminal shows separate `Matrix A:` and `Matrix B:` tables as you finish loading them. When you select DIP3, **C must equal B**, shown under `Matrix C:` with the same eight rows, followed by `DONE`.

## 5. How multiplication works

For each output position:

```text
C[row,col] = A[row,0]*B[0,col] + A[row,1]*B[1,col] + ... + A[row,7]*B[7,col]
```

The existing `software/matrix_baseline.sv` uses fixed MIF input memories and a single MAC. The board application uses [matrix_systolic.v](matrix_systolic.v), with runtime-written A/B memories and **four signed 16×16 MACs**. Its **35-bit signed accumulators** preserve the full sum of eight products, including results outside the signed 32-bit range. Output is signed decimal text without saturation or truncation.

A 2×2 tile computes `C[r,c]`, `C[r,c+1]`, `C[r+1,c]`, and `C[r+1,c+1]`. A values move right; B values move down:

```mermaid
flowchart TD
    A0["A row r"] --> P00["PE00"]
    A1["A row r+1, delayed 1 step"] --> P10["PE10"]
    B0["B column c"] --> P00
    B1["B column c+1, delayed 1 step"] --> P01["PE01"]
    P00 -->|A| P01
    P00 -->|B| P10
    P01 -->|B| P11["PE11"]
    P10 -->|A| P11
```

The second row/column is skewed by one step so matching `k` values meet in each PE. Ten consecutive processing clocks cover eight input terms and two pipeline-drain steps. After each tile, the four sums are stored and the next tile starts with cleared accumulators. Sixteen tiles produce the entire 8×8 C matrix.

A is banked by row parity, B by column parity, and C by both parities. Synchronous reads and look-ahead prefetch supply two A values and two B values per clock. The core uses 13 clocks per tile including clear/read/store, or **208 clocks per multiplication** (about **4.16 μs at 50 MHz**). UART input/output takes much longer. M9K attributes request embedded memories; confirm actual DSP/RAM use and 50 MHz timing in Quartus reports.

The core's synchronous read port selects **C=0, A=1, B=2** using `read_matrix`. `read_data` corresponds to `read_addr` and the selector sampled on the preceding rising edge. Input readback is used while the core is idle; during computation, its input-bank read ports serve the systolic datapath. One shared decimal formatter prints all three matrices without duplicating matrix storage.

## 6. Pin map and project files

| Function | Top-level port | FPGA pins |
| --- | --- | --- |
| 50 MHz clock | `clk_50mhz` | 23 |
| Reset, active low | `reset_n` | 25 |
| DIP1–4 / shared pushbuttons | `key_n[3:0]` | `[0]=88`, `[1]=89`, `[2]=90`, `[3]=91` |
| TTL transmit to adapter RXD | `uart_tx` | 114 |
| TTL receive from adapter TXD | `gpio` | 111 |
| Ready LEDs, active low | `led_n[3:0]` | `[0]=87`, `[1]=86`, `[2]=85`, `[3]=84` |
| Digit selects, active low | `digit_n[3:0]` | 133, 135, 136, 137 |
| Segments a,b,c,d,e,f,g,dp | `seg_n[7:0]` | 128,121,125,129,132,126,124,127 |

Only DIG1 is enabled for stage 1/2/3; the other digits and decimal point stay off. Idle/reset blanks all digits. The full QSF retains the stock `uart_rx` assignment on pin 115, but that port is unused here. Pin 111 is occupied by TTL reception when planning future features. Read each peripheral's voltage and shared-pin comments before adding its top-level ports; the supplied board schematic is labeled V2.1.

| File | Purpose |
| --- | --- |
| [my_uart_top.v](my_uart_top.v) | Switch debounce, UART parser, A/B/C table printing, ready LEDs and stage digit |
| [matrix_systolic.v](matrix_systolic.v) | Banked A/B/C memories, matrix readback and 2×2 systolic datapath |
| [my_uart_rx.v](my_uart_rx.v), [my_uart_tx.v](my_uart_tx.v) | UART byte reception/transmission |
| [speed_select.v](speed_select.v) | UART timing; default 5208 clock cycles per bit |
| [my_uart_top.sdc](my_uart_top.sdc) | 50 MHz and asynchronous-interface timing constraints |
| [matrix_systolic_tb.sv](matrix_systolic_tb.sv) | Arithmetic, A/B/C readback, signed values, repeated runs and reset tests |
| [my_uart_top_tb.v](my_uart_top_tb.v) | UART tables, CR/LF rows, input errors, ready LEDs, switches and status digit |

## 7. Simulation

With Icarus Verilog installed, run from this directory:

```bash
iverilog -g2012 -Wall -s matrix_systolic_tb -o /tmp/matrix_core_tb \
  matrix_systolic_tb.sv matrix_systolic.v
vvp /tmp/matrix_core_tb

iverilog -g2012 -Wall -s my_uart_top_tb -o /tmp/matrix_uart_tb \
  my_uart_top_tb.v my_uart_top.v my_uart_rx.v my_uart_tx.v \
  speed_select.v matrix_systolic.v
vvp /tmp/matrix_uart_tb
```

The UART test shortens the baud and debounce intervals to keep simulation fast. Hardware defaults remain 9600 baud and 10 ms. Both tests use independent dot-product oracles, cover zero/identity/signed extremes, and fail with `$fatal` on an error. Testbench files are excluded from synthesis.

Both testbenches passed with **Icarus Verilog 12.0**. The synthesis sources also passed Verilog-2005 elaboration. Quartus fitting, resource use, 50 MHz timing and physical-board operation still require verification on your setup.

## Troubleshooting

- **Error 12006 / undefined module:** open the supplied `.qpf` and check **Project > Add/Remove Files in Project** for all five synthesis files. `speed_select.v` and `matrix_systolic.v` must both be present. Importing only the board QSF adds pin assignments, not RTL sources.
- **Unknown `CLKS_PER_BIT` parameter:** copy the updated `speed_select.v` along with the other files; the original vendor version has no parameter.
- **No terminal output:** check adapter RXD → 114, GND, selected COM port, 9600/8N1, board power and the newly programmed `.sof`; press reset after opening the terminal.
- **No `A OK` / `B OK`:** check for exactly 64 values, the trailing Enter, TXD → 111, and 3.3 V logic. The acknowledgement follows the full matrix table, so allow it to finish printing. Wait for the matrix prompt before sending.
- **Wrong stage or unexpected reload:** keep only one DIP switch ON and leave S1–S4 released. DIP4 has no function.
- **No new C after DONE:** DIP3 must go OFF and ON again to request a new result.
- **Wrong segments:** check the fitted pins, common-anode polarity and your PCB revision.
- **Ready LEDs stay OFF:** a stage number alone does not mean a matrix is ready. LED1/2 require all 64 valid values, and LED3 requires a successful multiplication. Check UART errors and the LED pin assignments above.
