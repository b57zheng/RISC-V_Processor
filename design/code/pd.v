`include "control_defs.vh"

module pd(
  input clock,
  input reset
);

/* Fetch ------------------- */
reg [31:0] f_pc;
reg [31:0] f_insn;
wire imem_rw;
wire [31:0] imem_di;
assign imem_rw = 1'b0;    // read only for now
assign imem_di = 32'b0;   // nothing to write for now
imemory imemory_0 (
  // inputs
  .clock(clock),
  .address(f_pc),
  .data_in(imem_di),
  .read_write(imem_rw),
  // outputs
  .data_out(f_insn)
);
// PC control
always @(posedge clock) begin
  if (reset) begin
    f_pc <= 32'h01000000;
  end else begin
    // PC select logic based on control signals
    if (c_IsJALR) begin
      f_pc <= e_alu_res & ~32'd1; // JALR target address, LSB = 0
    end else if (b_branch_taken) begin
      f_pc <= e_alu_res;
    end else if (c_PCSel == `PC_ALU) begin
      f_pc <= e_alu_res;
    end else begin
      f_pc <= f_pc + 32'd4;
    end
  end
end
/* Fetch End ------------------ */

/* Decode --------------------- */
reg [31:0] d_pc = f_pc;
reg [6:0] d_opcode;
reg [4:0] d_rd;
reg [4:0] d_rs1;
reg [4:0] d_rs2;
reg [2:0] d_funct3;
reg [6:0] d_funct7;
reg [31:0] d_imm;
reg [4:0] d_shamt;

// Control Signals
reg       c_PCSel;  
reg [2:0] c_ImmSel;
reg       c_RegWEn;  // Register File Write Enable
reg [3:0] c_ALUSel;  // ALU operation select
reg       c_ASel;    // A input to ALU select
reg       c_BSel;    // B input to ALU select
reg       c_MemRW;   // DMem Read/Write Select
reg [1:0] c_WBSel;   // Write Back Select
reg [1:0] c_LoadSize;
reg       c_LoadUnsigned;
reg [1:0] c_StoreSize;
reg       c_IsJALR;
reg       c_IsBranch;
decoder decoder_0 (
  // inputs
  .pc(d_pc),
  .inst(f_insn),
  // outputs
  .opcode(d_opcode),
  .rd(d_rd),
  .rs1(d_rs1),
  .rs2(d_rs2),
  .funct3(d_funct3),
  .funct7(d_funct7),
  .imm(d_imm),
  .shamt(d_shamt),
  .PCSel(c_PCSel),
  .ImmSel(c_ImmSel),
  .RegWEn(c_RegWEn),
  .ALUSel(c_ALUSel),
  .ASel(c_ASel),
  .BSel(c_BSel),
  .MemRW(c_MemRW),
  .WBSel(c_WBSel),
  .LoadSize(c_LoadSize),
  .LoadUnsigned(c_LoadUnsigned),
  .StoreSize(c_StoreSize),
  .IsJALR(c_IsJALR),
  .IsBranch(c_IsBranch)
);

// Register File --------
reg [4:0] r_addr_rs1;
reg [4:0] r_addr_rs2;
reg [4:0] r_addr_rd;
reg [31:0] r_data_rd;
reg [31:0] r_data_rs1;
reg [31:0] r_data_rs2;
always @(*) begin
  // wire up data path
  r_addr_rs1 = d_rs1;
  r_addr_rs2 = d_rs2;
  r_addr_rd = d_rd;
end
register_file register_file_0 (
  // inputs
  .clock(clock),
  .addr_rs1(r_addr_rs1),
  .addr_rs2(r_addr_rs2),
  .addr_rd(r_addr_rd),
  .data_rd(r_data_rd),
  .write_enable(c_RegWEn &~ reset),
  // outputs
  .data_rs1(r_data_rs1),
  .data_rs2(r_data_rs2)
);
// Register File --------

/* Decode End ----------------- */

/* Execute -------------------- */
reg [31:0] e_pc = d_pc;
// BCU -------------------
reg b_branch_taken;
bcu bcu_0 (
  // inputs
  .is_branch(c_IsBranch),
  .funct3(d_funct3),
  .rs1(r_data_rs1),
  .rs2(r_data_rs2),
  // outputs
  .branch_taken(b_branch_taken)
);
// BCU -------------------

// ALU -------------------
reg [31:0] e_alu_a;
reg [31:0] e_alu_b;
reg [31:0] e_alu_res;
always @(*) begin
  // Default values
  e_alu_a = 32'b0;
  e_alu_b = 32'b0;
  // A input select mux
  if (c_ASel == `A_PC) begin
    e_alu_a = e_pc;
  end else if (c_ASel == `A_REG) begin
    e_alu_a = r_data_rs1;
  end
  // B input select mux
  if (c_BSel == `B_REG) begin
    e_alu_b = r_data_rs2;
  end else if (c_BSel == `B_IMM) begin
    e_alu_b = d_imm;
  end
end
alu alu_0 (
  // inputs
  .A(e_alu_a),
  .B(e_alu_b),
  .ALUSel(c_ALUSel),
  // outputs
  .ALURes(e_alu_res)
);
// ALU -------------------

/* Execute End ------------------- */

/* Memory ------------------------ */
reg [31:0] m_pc = e_pc;
reg [31:0] m_data;
reg [1:0] m_access_size;
always @(*) begin
  m_access_size = (c_MemRW == `MEM_WRITE) ? c_StoreSize : c_LoadSize;
end
// DMem -----------------
dmemory dmemory_0 (
  // inputs
  .clock(clock),
  .address(e_alu_res),
  .data_in(r_data_rs2),
  .read_write(c_MemRW),
  .access_size(m_access_size),
  // outputs
  .data_out(m_data)
);
// DMem -----------------

/* Memory End -------------------- */

/* Write Back -------------------- */
reg [31:0] w_pc = m_pc;
always @(*) begin
  // Default
  r_data_rd = 32'b0;
  case (c_WBSel)
    `WB_MEM: begin
      case (c_LoadSize)
        `LS_B: begin
          if (c_LoadUnsigned) begin
            r_data_rd = {24'b0, m_data[7:0]};
          end else begin
            r_data_rd = {{24{m_data[7]}}, m_data[7:0]};
          end
        end
        `LS_H: begin
          if (c_LoadUnsigned) begin
            r_data_rd = {16'b0, m_data[15:0]};
          end else begin
            r_data_rd = {{16{m_data[15]}}, m_data[15:0]};
          end
        end
        `LS_W: begin
          r_data_rd = m_data;
        end
        default: begin
          r_data_rd = m_data;
        end
      endcase
    end
    `WB_ALU: begin
      r_data_rd = e_alu_res;
    end
    `WB_PC4: begin
      r_data_rd = f_pc + 32'd4;
    end
    default: begin
      r_data_rd = 32'b0;
    end
  endcase
end

/* Write Back End ---------------- */


// Sync PC for single cycle data path, To be changed for pipelined design
always @(*) begin
  d_pc = f_pc;
  e_pc = d_pc;
  m_pc = e_pc;
  w_pc = m_pc;
end
endmodule
