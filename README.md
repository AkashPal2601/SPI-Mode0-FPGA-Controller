# SPI Mode 0 Protocol — RTL Design, Self-Checking Verification & FPGA Implementation using Xilinx Vivado

A full-duplex **SPI Mode 0 (`CPOL = 0`, `CPHA = 0`)** hardware controller implemented in Verilog HDL, verified through a **3-tier self-checking testbench suite** (unit, subsystem, and FPGA wrapper), and implemented in Xilinx Vivado targeting device **`xc7a35tcpg236-1`**

---

## 1. Project Overview & Key Highlights

* **SPI Mode 0 Protocol (`CPOL = 0`, `CPHA = 0`):** Serial clock `SCLK` idles low (`0`) when inactive (CPOL = 0). Data shifts on the falling edge of `SCLK` and is sampled on the rising edge of `SCLK` during active transfers (CPHA = 0).
* **Modular Hierarchy:** Built from low-level blocks (`SPI_Master`, `SPI_Slave`, and peripheral conditioning/display logic) up to `SPI_Top` and `SPI_Top_FPGA`
* **Self-Checking Verification:** Goes beyond single-byte waveform checks by combining targeted corner cases, randomized test vectors, and `rst_n` / `start` stress testing across the two testbenches (`SPI_Top_tb.v`, and `SPI_Top_FPGA_tb.v`) with per-test pass/fail printouts and a final pass/fail scoreboard summary.
* **Post-Implementation Hardware Signoff:** Verified in Vivado post-implementation timing simulation and backed by clean plain-text `.rpt` timing, utilization, and power reports

---

## 2. Architecture & Elaborated Design Schematics

### Module Hierarchy

| Module / Block | Hierarchy Level | Responsibility & Key Signals |
| :--- | :--- | :--- |
| `SPI_Master` | Unit (Core) | Generates `SCLK` and slave select signaling, shifts out `MOSI`, samples `MISO`, advances `curr_state` / `next_state`, and asserts completion/status flags (`data_ready`), using a 4 state FSM Controller (IDLE, LOAD, TRANSMIT, STOP)|
| `SPI_Slave` | Unit (Core) | Operates in Mode 0 (`CPOL = 0`, `CPHA = 0`), drives `MISO`, samples `MOSI`, and transitions its own `curr_state` / `next_state` 3 state FSM Controller (IDLE, TRANSMIT, COMPUTE). Performs an easy-to-detect 1's complement operation on the received data and sends it back to the Master with a 1 data transfer cycle computation latency|
| `Debouncer` | Helper Module | Takes bouncy board pushbutton inputs and filters them to obtain a clean rectangular pulse |
| `Seven_Seg_Controller` | Helper Module | Dictates the multiplexing logic for the display controls of the on-board segment displays |
| `SPI_Top` | Subsystem | Integrates `SPI_Master` and `SPI_Slave` with top-level TX/RX data registers and control/status signals |
| `SPI_Top_FPGA_Wrapper` | Top FPGA | Wraps `SPI_Top` with board-level I/O, pushbutton input debouncing (`Debounce_start`), and display/indicator logic mapped via `.xdc` constraints[span_4](start_span)[span_4](end_span) |

### Elaborated Schematics

* **Top-Level Modular Elaborated Design Schematic:**
  ![Top-Level Modular Elaborated Schematic](docs/Schematics/[rtl_schematic_Topmost_SPI_Top_FPGA.png])
* **Master–Slave Integration Elaborated Design Schematic:**
  ![Master-Slave Integration Elaborated Schematic](docs/Schematics/[rtl_schematic_Top_Level_Master_Slave_Integration.png])

---

## 3. Repository Structure

| Path | Type | Description |
| :--- | :--- | :--- |
| `rtl/` | Directory | Synthesizable Verilog source files (`SPI_Master_Behav.v`, `SPI_Slave_Behav.v`, `SPI_Top_Behav.v`, `SPI_Top_FPGA.v`, and helper modules `Debouncer.v`, `Seven_Seg_Controller.v`) |
| `testbenches/` | Directory | Self-checking Verilog testbenches (`SPI_Master_Behav_tb.v`, `SPI_Top_Behav_tb.v`, `SPI_Top_FPGA_tb.v`, `Debouncer_tb.v`) |
| `constraints/` | Directory | Target board pinout and clock constraint files (`SPI_FPGA_Constraints.txt`) |
| `reports/` | Directory | Plain-text Vivado implementation reports (`.rpt`) generated via Tcl (`report_timing_summary`, `report_utilization`, `report_power`) |
| `docs/` | Directory | Elaborated schematics, post-implementation timing waveforms, and simulation console screenshots (`.png`) |
| `.gitignore` | File | Ignores Vivado project/run directories, temporary logs/databases, and heavy .wcfg files |
| `README.md` | File | Project documentation, verification breakdown, and FPGA implementation summary |

---

## 4. Self-Checking Verification Architecture

Rather than checking only a single 8-bit data transfer manually, each testbench is **self-checking**:
1. **Automated Reference Checking:** Expected outputs are compared automatically against actual DUT responses.
2. **Per-Test Console Feedback:** Each test case prints a `[PASS]` or `[FAIL]` status line as it runs.
3. **Cumulative Tally & Scoreboard Summary Banner:** Pass and fail counters are accumulated across the full run and printed in a final summary banner.
4. **Multi-Scenario Coverage:** Combines directed corner cases, pseudo-random vector streams, power-on initialization and `rst_n` / `start` stress testing.

## 5. Follow-Up Plans

1. A short video demonstration to cover the functioning of the design on real hardware FPGA board
2. Data width and Clock Frequency parameter sweeps to find range of operation of the circuit

<!--

### Testbench Suite Breakdown

| Testbench | Target Module | Directed Corner Cases | Randomized Vectors | Reset & Control Stress | Pass / Fail Reporting |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `testbenches/SPI_Master_tb.v` | `SPI_Master` | `8'h00`, `8'hFF`, `8'h55`, `8'hAA`, single-bit walk values, back-to-back transfers | Multi-transaction pseudo-random byte stream | Mid-frame `rst_n` recovery and `start` behavior checks | Per-test status + final pass/fail tally |
| `testbenches/SPI_Top_tb.v` | `SPI_Top` | Full-duplex boundary and alternating bit patterns | Randomized full-duplex TX/RX byte pairs | Reset and repeated back-to-back frame checks | Per-test status + final pass/fail tally |
| `testbenches/SPI_Top_FPGA_tb.v` | `SPI_Top_FPGA_Wrapper` | Corner-case transfers across top wrapper and status/display logic | Randomized stimulus vectors | `rst_n` and `start` stress testing (behavioral & post-implementation timing) | Per-test status + final pass/fail tally |

### Sample Console Log Output

```text
[PASS] Test 01 (Corner 8'h00 / 8'hFF): TX=00 RX_M=FF RX_S=00
[PASS] Test 02 (Corner 8'h55 / 8'hAA): TX=55 RX_M=AA RX_S=55
...
[PASS] Test 29 (Random Vector Stream): All randomized transfers matched expected values
[PASS] Test 30 (Reset & Start Stress): Clean recovery and subsequent transfer verified
==================================================
VERIFICATION SUMMARY: 30 PASSED, 0 FAILED
==================================================

-->