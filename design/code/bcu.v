// Branch Control Unit
`include "control_defs.vh"

module bcu #()
(
  input wire is_branch,
  input wire [2:0] funct3,
  input  wire [31:0] rs1,
  input  wire [31:0] rs2,

  output reg branch_taken
);

// Branch Compare
wire BrEq;
wire BrLT;
wire BrLTU;
assign BrEq  = (rs1 == rs2);
assign BrLT  = ($signed(rs1) < $signed(rs2));
assign BrLTU = (rs1 < rs2);

// Combinational Branch Control Logic
always @(*) begin
  // Default not taken
  branch_taken = `FALSE;
  if (is_branch) begin
    case (funct3)
      3'b000: branch_taken = BrEq;          // BEQ
      3'b001: branch_taken = !BrEq;         // BNE
      3'b100: branch_taken = BrLT;          // BLT
      3'b101: branch_taken = !BrLT;         // BGE
      3'b110: branch_taken = BrLTU;         // BLTU
      3'b111: branch_taken = !BrLTU;        // BGEU
      default: branch_taken = `FALSE;
    endcase
  end
end

endmodule
