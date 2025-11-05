# RISC-V Processor (Verilog)

## Overview
This project implements a **RV32I RISC-V processor** in Verilog under the guidance of Dr. Hiren Patel.  
The design follows the RISC-V base integer instruction set and progressively evolves toward a pipelined implementation.  
Currently, the processor supports a fully functional **single-cycle datapath** with fetch, decode, execute, memory, and write-back stages.

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
```

## Tools and Environment
- **HDL:** Verilog (IEEE 1364)  
- **Simulator:** Verilator 4.210  
- **Waveform Viewer:** GTKWave  
- **Target FPGA (future):** Xilinx PYNQ-Z1 (Vivado 2022.1)  
- **Platform:** Ubuntu 20.04 LTS (ECE Linux servers)  

## Future Work
- Implement 5-stage pipelined RISC-V processor with forwarding and stalling logic.  
- Map the design to FPGA (PD6) for hardware validation and performance measurement.  
- Develop SystemVerilog testbenches and add automated trace comparison scripts.  
