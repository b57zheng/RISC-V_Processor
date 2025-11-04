# RISC-V Processor (Verilog)

## Overview
This project implements a **RV32I RISC-V processor** in Verilog.  
The design follows the RISC-V base integer instruction set and progressively evolves toward a pipelined implementation.  
Currently, the processor supports a fully functional **single-cycle datapath** with fetch, decode, execute, memory, and write-back stages.

## Development Progress
| Stage | Description | Status |
|:------|:-------------|:--------|
| 0 | Instruction memory & fetch stage | ✅ Complete |
| 1 | Decode stage (instruction field extraction) | ✅ Complete |
| 2 | Register file & execute (ALU, branch logic) | ✅ Complete |
| 3 | Memory & write-back stages, full single-cycle datapath | ✅ Complete |
| 4 | 5-stage pipelined design (with forwarding and bypassing) | ⏳ In progress |
| 5 | FPGA deployment (PYNQ-Z1) | ⏳ Pending |

## System Architecture
The single-cycle datapath integrates the following components:
- **Instruction Memory** – Byte-addressable memory supporting combinational reads and sequential writes.  
- **Register File** – Two combinational read ports, one sequential write port; initialized per RISC-V ABI (x2 = stack pointer).  
- **ALU / Execute Stage** – Handles arithmetic, logical, and branch comparison operations.  
- **Memory Stage** – Supports `LW`, `SW`, and related data-memory instructions.  
- **Writeback Stage** – Returns computed or loaded data to the register file.  
- **Control Logic** – Minimal single-cycle control supporting all RV32I instruction formats.

## Simulation and Verification
Simulation is performed using **Verilator v4.210** and waveform inspection with **GTKWave**.  
Testbenches and golden traces are provided via the course repository to validate:
- Instruction decoding correctness  
- Register file read/write timing  
- ALU and branch execution results  
- End-to-end datapath behavior  

### Example Commands
```bash
# Compile and simulate using Verilator
make run TEST=test_pd MEM_PATH=../benchmarks/rv32ui-p-addi.x

# View waveforms
make waves
