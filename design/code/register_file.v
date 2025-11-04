/*
Implement a register file as presented in class for the subset of the RISC-V ISA instructions decoded in
PD2. We discussed the register file datapath design in class. That is the register file you are required to
implement. The register file will be a synchronous component. Once again, reads in the register file
are combinational, and the writes are sequential. The timing behaviour of the register file should be as
follows: the output of the reads are available within the same clock cycle as when the address for the
registers is supplied, and the writes to the registers are only available to be read in the next clock cycle.
You should see a resemblance between your memory module implementation and your register file.
Your register file module must have the following ports, with the exact port names provided:

•clock (1 bit): input
•addr_rs1 (5 bits): input to select the first source register
•addr_rs2 (5 bits): input to select the second source register
•addr_rd (5 bits): input to select the destination register
•data_rd (32 bits): input to write into the destination register
•data_rs1 (32 bits): output of the contents of register specified by addr_rs1
•data_rs2 (32 bits): output of the contents of register specified by addr_rs2
•write_enable(1 bit): input to write the contents of destination register specified by addr_rd.

If write_enableis not asserted, then the register file does not do any writes. write_enable
must be active-high, that is, use 1 to denote a write.
Please initialize x2, the stack pointer, to 32'h01000000 + `MEM_DEPTH. All other registers should
be initialized to 0.
For this project, use an initial block instead of adding ports to the register file. The reason we are
doing this is that, in PD6, we will be mapping the register file onto a block RAM (BRAM) on the FPGA.
When we do this, Vivado will expect an initial block to initialize the contents of the memory, whether it
is specified directly in Verilog assignments or in an external file that we read with $readmemh(), as
shown in the Vivado manual. You can refer to the PD6 section in the project deliverables document on
Learn for more information on how we will be dealing with the register file.
You may encounter issues with write_enable being asserted during reset. To get around this, you
can have the reset logic embedded inside write_enable (i.e. write_enable must be 0 when
reset is high)
*/

module register_file #()
(
  input wire clock,
  input wire [4:0] addr_rs1,
  input wire [4:0] addr_rs2,
  input wire [4:0] addr_rd,
  input wire [31:0] data_rd,
  input wire write_enable,

  output reg [31:0] data_rs1,
  output reg [31:0] data_rs2 
);

// Register file memory
reg [31:0] regfile [0:31];
integer i;
initial begin
  for (i = 0; i < 32; i = i + 1) begin
    if (i == 2) begin
      // Initialize sp (x2) to stack top address
      regfile[i] = 32'h01000000 + `MEM_DEPTH; 
    end else begin
      // Initialize all other registers to 0
      regfile[i] = 32'b0;
    end
  end
  data_rs1 = 32'b0;
  data_rs2 = 32'b0;
end

// Combinational Read logic, x0 is always 0
always @(*) begin
  if (addr_rs1 == 5'b0) begin
    data_rs1 = 32'b0; 
  end else begin
    data_rs1 = regfile[addr_rs1];
  end
  if (addr_rs2 == 5'b0) begin
    data_rs2 = 32'b0; 
  end else begin
    data_rs2 = regfile[addr_rs2];
  end
end

// Sequential Write, ignore writes to x0
always @(posedge clock) begin
  if (write_enable && (addr_rd != 5'b0)) begin
    regfile[addr_rd] <= data_rd;
  end
end

endmodule
