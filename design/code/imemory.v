/*
Memory Module Specification
In this PD, you will create a behavioural main memory module that is byte-addressable.
That is, the memory should support addressing individual bytes (8 bits).
We model this module at the behavioural level, meaning that it does not have to be synthesizable.
The memory will have the following ports:

clock (1 bit)
address (32 bits)
data_in (32 bits): The data to be written into the memory at the provided address.
data_out (32 bits): The data response from the main memory to the address provided.
read_write (1 bit): Whether the memory is being read from or written to, use 0 to denote 
                    a read and 1 to denote a write.

Notice that the address space subset we use starts at address 0x01000000 and has a size of MEM_DEPTH bytes.
We provide you with a macro, MEM_DEPTH, which defines the size of the memory module in bytes.
You can use this macro when you instantiate the memory array; to use a macro in Verilog, use the backtick character (e.g. `MEM_DEPTH).
If you inspect any one of the *.d files in the RISC-V benchmarks, you will notice that all programs start at address 0x01000000.
For the project, we will treat this as the starting address of the memory, initialize the program counter (PC) to this value, and start fetching instructions from this PC.

Whenever a 32-bit address is supplied on the address line, the memory module should return 32 bits (four bytes) of data on data_out using little-endian ordering.
For example, if the input address is 0x01000000, you should return the bytes at addresses 0x01000000 through 0x01000003.
If the read_write input signal asserted, this indicates that the 32-bit value on data_in should be written to the memory at the specified address.
The main memory should have combinational reads and sequential writes.
This means that on a read operation, the output on data_out has the value at the specified address in the same clock cycle.
On a write operation, the new value is only available to be read in the next clock cycle.

Loading a Benchmark File
We will be using the rv32-benchmarks to test your design.
To test your core as you work through the project, you will use the *.x files in the benchmark suite.
We provide a macro, MEM_PATH, which points to the *.x file.
You can override the default value of this macro to supply different *.x file paths when running the make command (more information here).
Reading the contents of the file into your memory module can be tricky.
You will need to read the *.x file using $readmemh(`MEM_PATH, arr) in an initial block, where arr is a Verilog array.
What makes this process tricky is that $readmemh() will read the data in 32-bit blocks into the array.
Since we are trying to implement a byte-addressable memory where each element is 8 bits (one byte), this causes problems when used directly with $readmemh().
What you will find is that $readmemh() will simply truncate the 32-bit data before writing it to the memory.
To get around this, we recommend instantiating a temporary array which can be used with $readmemh() to capture all data from the source file without truncation.
We provide a macro, LINE_COUNT, to identify the number of lines within the .x file given by MEM_PATH.
You can use this macro to instantiate your temporary array to an appropriate size.
Next, we can copy each byte from this temporary array into the main memory array, within the initial block.
This approach allows us to capture the entire benchmark without any lost data while still making sure it is byte-addressable.
*/

module imemory #()
(
  input wire clock,
  input wire [31:0] address,
  input wire [31:0] data_in,
  input wire read_write,

  output reg [31:0] data_out 
);

// Arr to store instructions
reg [7:0] memory [0:(`MEM_DEPTH - 1)];   // byte memory
reg [31:0] arr [0:(`LINE_COUNT - 1)];    // 4byte tmp arr

`define MEM_START  32'h01000000
`define WRITE      1'b1

integer arr_i;
integer j;
integer mem_i;
reg [31:0] inst;
integer byte_addr;

initial begin
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
  byte_addr = address - `MEM_START;
  data_out = { memory[byte_addr + 3], memory[byte_addr + 2],
               memory[byte_addr + 1], memory[byte_addr] };
end

// Sequential Write
always @(posedge clock) begin
  byte_addr = address - `MEM_START;
  if (read_write) begin
    memory[byte_addr]     <= data_in[7:0];
    memory[byte_addr + 1] <= data_in[15:8];
    memory[byte_addr + 2] <= data_in[23:16];
    memory[byte_addr + 3] <= data_in[31:24];
  end
end

endmodule
