
/*
We are going to simplify the memory stage for ourselves by creating another memory module similar
to the one we created for PD1. This makes sense because both instruction and data are loaded into
the memory. The difference in the memory stage will be that we will not be wiring the read_write to
only read. This is because we want to perform the operation specified by the instructions: for a store,
we perform a write, and for a load, we perform a read. Note that you have memory operations that
perform loads and stores on byte and half-word data sizes. When loading bytes and half-words, you
can retrieve the full word from the data memory, then strip out the required data in the memory stage.
There are some additions you will have to make in order for the data memory to work correctly.

•Loads: For a given address, retrieve the four byte word that contains the corresponding byte or
half-word, and return it on the data output lines. The correct 32-bit value can then be organized
as per the specification in the processor pipeline.

•Stores: To perform a half-word or byte stores, we need to make minor modifications to the
memory interface. Please add a 2-bit access_size port that indicates the size of the ac-
cess to the memory. The encoding of size should follow the RISC-V ISA specification. Thus an
access_size of 0 is equivalent to a byte access and an access_size of 2 is equivalent to
a 4-byte (word) access. For example, a store of access_size of two bytes (half-word) would
select the appropriate two bytes provided in the input, and write it to the memory.

Note that there is also a PC+4 component in the memory stage. You should implement that here or in
the writeback stage.
*/
`include "control_defs.vh"

module dmemory #()
(
  input wire clock,
  input wire [31:0] address,
  input wire [31:0] data_in,
  input wire read_write,
  input wire [1:0] access_size, // 00: byte, 01: half-word, 10: word

  output reg [31:0] data_out
);

// Arr to store
reg [7:0] memory [0:(`MEM_DEPTH - 1)];   // byte memory
reg [31:0] arr [0:(`LINE_COUNT - 1)];    // 4byte tmp arr

`define MEM_START  32'h01000000

integer arr_i;
integer j;
integer mem_i;
reg [31:0] inst;
integer byte_addr;

initial begin
  // Initialize memory to zero
  for (mem_i = 0; mem_i < `MEM_DEPTH; mem_i = mem_i + 1) begin
    memory[mem_i] = 8'b0;
  end
  // Load from .x file to arr
  $readmemh(`MEM_PATH, arr);
  mem_i = 0;
  for (arr_i = 0; arr_i < `LINE_COUNT; arr_i = arr_i + 1) begin
    inst = arr[arr_i];
    for (j = 0; j < 4; j = j + 1) begin
      memory[mem_i] = inst[7:0];
      inst = inst >> 8;
      mem_i = mem_i + 1;
    end
  end
end


// Combinational read
always @(*) begin
  byte_addr = (address - `MEM_START); // align 
  data_out = { memory[byte_addr + 3], memory[byte_addr + 2],
                memory[byte_addr + 1], memory[byte_addr] };
end

// Sequential Write
always @(posedge clock) begin
  if (read_write == `MEM_WRITE) begin
    byte_addr = (address - `MEM_START); // align
    case (access_size)
      2'b00: begin // byte
        memory[byte_addr] <= data_in[7:0];
      end
      2'b01: begin // half-word
        memory[byte_addr]     <= data_in[7:0];
        memory[byte_addr + 1] <= data_in[15:8];
      end
      2'b10: begin // word
        memory[byte_addr]     <= data_in[7:0];
        memory[byte_addr + 1] <= data_in[15:8];
        memory[byte_addr + 2] <= data_in[23:16];
        memory[byte_addr + 3] <= data_in[31:24];
      end
      default: begin
        memory[byte_addr] <= data_in[7:0];
      end
    endcase
  end
end

endmodule
