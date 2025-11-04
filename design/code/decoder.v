/*
In this PD, you will be using the data output from the instruction memory and decoding it in the
decode stage. Make sure to copy your imemory implementation from PD1. The decode stage splits
the instruction word into its respective fields. This allows the hardware to identify the instruction, its
operands, and generate any control signals that may be necessary to drive other datapath components.
This decode stage must be combinational. Connect the decode stage to the fetch logic. The decode
stage should support all the instructions shown in the table below:

Notice that not all instructions in the table have a value for all fields. For those values, you may assign
any value and we will treat it as a don’t care. Make sure to properly sign extend and pad the immediate
value field.
*/
`include "control_defs.vh"

// Include Imm Gen and Control Gen
module decoder #()
(
  input wire [31:0] pc,
  input wire [31:0] inst,

  // Field Decoded
  output reg [6:0] opcode,
  output reg [4:0] rd,
  output reg [4:0] rs1,
  output reg [4:0] rs2,
  output reg [2:0] funct3,
  output reg [6:0] funct7,
  output reg [31:0] imm,
  output reg [4:0] shamt,

  // Control Signals
  output reg       PCSel,   
  output reg [2:0] ImmSel,
  output reg       RegWEn,  // Register File Write Enable
  output reg [3:0] ALUSel,  // ALU operation select
  output reg       ASel,    // A input to ALU select
  output reg       BSel,    // B input to ALU select
  output reg       MemRW,   // DMem Read/Write Select
  output reg [1:0] WBSel,   // Write Back Select
  output reg [1:0] LoadSize,
  output reg       LoadUnsigned,
  output reg [1:0] StoreSize,
  output reg       IsJALR,
  output reg       IsBranch
);

// Combinational decode
always @(*) begin
  // Default most common case
  opcode  = inst[6:0];
  rd      = inst[11:7];       // Destination reg
  funct3  = inst[14:12];      
  rs1     = inst[19:15];      // Source 1 reg 
  rs2     = inst[24:20];      // Source 2 reg
  shamt   = inst[24:20];      // Shift amount
  funct7  = inst[31:25];
  imm     = 32'b0;

  PCSel        = `PC_PLUS4;
  RegWEn       = `FALSE;
  ALUSel       = `ALU_ADD;
  ASel         = `A_REG;
  BSel         = `B_REG;
  MemRW        = `MEM_READ;
  WBSel        = `WB_ALU;
  LoadSize     = `LS_W;
  LoadUnsigned = `FALSE;
  StoreSize    = `LS_W;
  IsJALR       = `FALSE;
  IsBranch     = `FALSE;
  
  case (opcode)
    // R-type --------------------------------------------
    7'b0110011: begin  // Arithmetic
      imm = 32'b0;
      RegWEn = `TRUE;  // Write Reg file
      case (funct3)
        3'b000: ALUSel = (funct7[5] == 1'b0) ? `ALU_ADD : `ALU_SUB;
        3'b001: ALUSel = `ALU_SLL;
        3'b010: ALUSel = `ALU_SLT;
        3'b011: ALUSel = `ALU_SLTU;
        3'b100: ALUSel = `ALU_XOR;
        3'b101: ALUSel = (funct7[5] == 1'b0) ? `ALU_SRL : `ALU_SRA;
        3'b110: ALUSel = `ALU_OR;
        3'b111: ALUSel = `ALU_AND;
      endcase
    end
    // I-type --------------------------------------------
    7'b1100111: begin  // JALR
      imm    = {{20{inst[31]}}, inst[31:20]}; 
      PCSel  = `PC_ALU;
      RegWEn = `TRUE;  // Write Reg file      
      IsJALR = `TRUE;
      ALUSel = `ALU_ADD;
      BSel   = `B_IMM;
      WBSel  = `WB_PC4; 
    end
    7'b0000011: begin  // Load
      imm = {{20{inst[31]}}, inst[31:20]}; 
      RegWEn = `TRUE;  
      ALUSel = `ALU_ADD;
      BSel   = `B_IMM;
      WBSel  = `WB_MEM;
      case (funct3) 
        3'b000: LoadSize = `LS_B;
        3'b001: LoadSize = `LS_H;
        3'b010: LoadSize = `LS_W;
        3'b100: begin
          LoadSize       = `LS_B;
          LoadUnsigned   = `TRUE;
        end
        3'b101: begin
          LoadSize       = `LS_H;
          LoadUnsigned   = `TRUE;
        end
        default: begin
          LoadSize       = `LS_W;
          LoadUnsigned   = `FALSE;
        end
      endcase
    end
    7'b0010011: begin  // Arithmetic Immediate
      if (funct3 == 3'b001 || funct3 == 3'b101) begin
        imm = {27'b0, shamt};
      end else begin
        imm = {{20{inst[31]}}, inst[31:20]};
      end
      RegWEn = `TRUE;  
      BSel   = `B_IMM;
      case (funct3)
        3'b000: ALUSel = `ALU_ADD;
        3'b010: ALUSel = `ALU_SLT;
        3'b011: ALUSel = `ALU_SLTU;
        3'b100: ALUSel = `ALU_XOR;
        3'b110: ALUSel = `ALU_OR;
        3'b111: ALUSel = `ALU_AND;
        3'b001: ALUSel = `ALU_SLL;
        3'b101: ALUSel = (funct7[5] == 1'b0) ? `ALU_SRL : `ALU_SRA;
      endcase
    end
    // S-type --------------------------------------------
    7'b0100011: begin  // Store
      imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
      RegWEn = `FALSE;
      ALUSel = `ALU_ADD;
      BSel   = `B_IMM;
      MemRW  = `MEM_WRITE;
      case (funct3)
        3'b000: StoreSize = `LS_B;
        3'b001: StoreSize = `LS_H;
        3'b010: StoreSize = `LS_W;
        default: StoreSize = `LS_W;
      endcase
    end
    // B-type -------------------------------------------
    7'b1100011: begin  // Branch
      imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], 
              inst[11:8], 1'b0};
      IsBranch = `TRUE;
      ASel   = `A_PC;
      BSel   = `B_IMM;
      ALUSel = `ALU_ADD;
      PCSel  = `PC_PLUS4;  // Default not taken
      // Branch control logic taken over by bcu
    end
    // U-type -------------------------------------------
    7'b0110111: begin  // LUI
      imm    = {inst[31:12], 12'b0};
      RegWEn = `TRUE;  
      ALUSel = `ALU_COPY_B;
      ASel   = `A_REG;
      BSel   = `B_IMM;
      WBSel  = `WB_ALU;
    end
    7'b0010111: begin  // AUIPC
      imm = {inst[31:12], 12'b0};
      RegWEn = `TRUE;
      ALUSel = `ALU_ADD;
      ASel   = `A_PC;
      BSel   = `B_IMM;
      WBSel  = `WB_ALU;
    end
    // J-type -------------------------------------------
    7'b1101111: begin  // JAL
      imm = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], 
              inst[30:21], 1'b0};
      PCSel  = `PC_ALU;
      RegWEn = `TRUE;
      ALUSel = `ALU_ADD;
      ASel   = `A_PC;
      BSel   = `B_IMM;
      WBSel  = `WB_PC4;
    end
    default: begin
      imm = 32'b0;
    end
  endcase
end

endmodule