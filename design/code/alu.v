// Arithmitic Logic Unit
`include "control_defs.vh"

module alu #()
(
  input  wire [31:0] A,
  input  wire [31:0] B,
  input  wire [3:0]  ALUSel,

  output reg  [31:0] ALURes
);

// Combinational ALU
always @(*) begin
  case (ALUSel)
    `ALU_ADD:    ALURes = A + B;         
    `ALU_SUB:    ALURes = A - B;    
    `ALU_AND:    ALURes = A & B;  
    `ALU_OR:     ALURes = A | B;  
    `ALU_XOR:    ALURes = A ^ B;     
    `ALU_SLT:    ALURes = ($signed(A) < $signed(B)) ? 32'b1 : 32'b0; // SLT   
    `ALU_SLTU:   ALURes = (A < B) ? 32'b1 : 32'b0;         
    `ALU_SLL:    ALURes = A << B[4:0];     
    `ALU_SRL:    ALURes = A >> B[4:0];      
    `ALU_SRA:    ALURes = $signed(A) >>> B[4:0]; 
    `ALU_COPY_B: ALURes = B;
    default:     ALURes = 32'b0;
  endcase
end

endmodule