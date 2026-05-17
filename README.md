# RISC-V Processor (Verilog)

## Overview
This project implements a **RV32I 5-stage pipelined processor** in Verilog under the guidance of Dr. Hiren Patel.  
The design follows the RISC-V base integer instruction set and is adapted for FPGA deployment in PD6.  
The current processor supports a fully functional **fetch‑decode‑execute‑memory‑writeback pipeline** with hazard bypassing and stalling logic.

## System Architecture
The pipelined datapath integrates the following components:
- **Instruction Memory** – BRAM-backed memory with a 1-cycle read latency and dynamic loading support.  
- **Register File** – BRAM-style register file with one-cycle reads and sequential write semantics.  
- **ALU / Execute Stage** – Handles arithmetic, logical, shift, and branch comparison operations.  
- **Memory Stage** – Supports `LW`, `SW`, and aligned/unaligned data-memory instructions.  
- **Writeback Stage** – Writes computed or loaded data back to the register file.  
- **Control Logic** – Pipeline control supporting RV32I instruction formats, branch handling, forwarding, and stalls.

## Simulation and Verification
Simulation is performed using **Verilator v4.210** and waveform inspection with **GTKWave**.  
Testbenches and golden trace comparisons are used to validate:
- Instruction decoding and control signal correctness  
- Pipeline register behavior and hazard resolution  
- Register file read/write timing with BRAM latency  
- ALU, branch, and memory execution behavior  
- End-to-end program execution  

### Example Commands
```bash
# Compile and simulate using Verilator
make run TEST=test_pd MEM_PATH=../benchmarks/rv32ui-p-addi.x

# View waveforms
make waves
```

## Tools and Environment
- **HDL:** Verilog (IEEE 1364)  
- **Simulator:** Verilator 4.210  
- **Waveform Viewer:** GTKWave  
- **FPGA Target:** Xilinx PYNQ-Z1 (Vivado 2022.1)  
- **Platform:** Ubuntu 20.04 LTS (ECE Linux servers)
