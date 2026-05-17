/*
---------------------------------------------------------------------------
Trace Format:
     1           2
[F]  pc_address  insn
     1           2      3    4    5    6      7         8       9
[D]  pc_address  opcode rd   rs1  rs2  funct3 funct7    imm    shamt
     1         2         3          4
[R]  addr_rs1  addr_rs2  data_rs1   data_rs2
     1           2           3
[E]  pc_address  alu_result  branch_taken
     1           2               3           4            5
[M]  pc_address  memory_address  read_write  access_size  memory_data
     1           2             3         4
[W]  pc_address  write_enable  write_rd  data_rd
---------------------------------------------------------------------------
*/

`include "control_defs.h"

module pd(
  input clock,
  input reset
);

/* Fetch ------------------------------------ */
reg [31:0] f_pc;
wire [31:0] f_insn;
// Delayed PC to align with synchronous IMEM output
reg [31:0] f_pc_q;
reg [31:0] mem_wb_pc;
reg        mem_wb_valid;
reg [31:0] mem_wb_dmem_data;
reg [1:0]  mem_wb_WBSel;
reg [4:0]  mem_wb_rd;
reg        mem_wb_RegWEn;
reg [1:0]  mem_wb_LoadSize;
reg        mem_wb_LoadUnsigned;
reg [31:0] mem_wb_alu_res;
reg [31:0] fwd_dmem_data_rs2;
wire e_branch_redirect;
wire e_jalr_redirect;
wire e_jal_redirect;
wire e_redirect;
wire [31:0] e_redirect_target;
wire imem_rw;
wire [31:0] imem_di;
wire [31:0] f_pc_plus4;
reg  [31:0] next_pc;
assign imem_rw = 1'b0;    // read only for now
assign imem_di = 32'b0;   // nothing to write for now
assign f_pc_plus4 = f_pc + 32'd4;
wire if_stall;        // Driven by hazard detection
wire if_flush;        // Driven by branch/jump resolution
wire if_bubble;       // Driven by hazard detection
// disable imem during hazards 
wire imem_en = !if_stall; 
//wire imem_en = 1'b1; 
imemory imemory_0 (
  // inputs
  .clock(clock),
  .address(f_pc),
  .data_in(imem_di),
  .read_write(imem_rw),
  .enable(imem_en),
  // outputs
  .data_out(f_insn)
);

// Next PC logic, branch resolved in Execute stage
always @(*) begin
  if (e_redirect) 
    next_pc = e_redirect_target;
  else 
    next_pc = f_pc_plus4;
end
// PC control mux
always @(posedge clock) begin
  if (reset) begin
    f_pc <= 32'h01000000;
  end else if (!if_stall) begin
    f_pc <= next_pc;
  end
end
// Capture the PC used for the instruction returned by IMEM
always @(posedge clock) begin
  if (reset) begin
    f_pc_q <= 32'h01000000;
  end else if (!if_stall) begin
    f_pc_q <= f_pc;
  end
end

// IF/ID Pipline Registers ----
reg [31:0] if_id_pc;
reg [31:0] if_id_insn;
reg        if_id_valid;
// IF pipline control wires
always @(posedge clock) begin
  if (reset) begin
    if_id_pc <= 32'h01000000;
    if_id_insn <= `NOP; 
    if_id_valid <= 1'b0;
  end else if (if_flush || if_bubble) begin
    if_id_pc <= f_pc_q;
    if_id_insn <= `NOP; 
    if_id_valid <= 1'b0;
  end else if (!if_stall) begin
    if_id_pc <= f_pc_q;
    if_id_insn <= f_insn;
    if_id_valid <= 1'b1;
  end
end


// IF/ID Pipline Registers ----

/* Fetch End ---------------------------------------- */



/* Decode ------------------------------------------- */
wire [31:0] d_insn;
assign d_insn = if_id_insn;
wire [31:0] d_pc;
assign d_pc = if_id_pc;
wire [6:0]  d_opcode;
wire [4:0]  d_rd;
wire [4:0]  d_rs1;
wire [4:0]  d_rs2;
wire [2:0]  d_funct3;
wire [6:0]  d_funct7;
wire [31:0] d_imm;
wire [4:0]  d_shamt;

// Control Signals
wire       c_PCSel;  
wire [2:0] c_ImmSel;
wire       c_RegWEn;  // Register File Write Enable
wire [3:0] c_ALUSel;  // ALU operation select
wire       c_ASel;    // A input to ALU select
wire       c_BSel;    // B input to ALU select
wire       c_MemRW;   // DMem Read/Write Select
wire [1:0] c_WBSel;   // Write Back Select
wire [1:0] c_LoadSize;
wire       c_LoadUnsigned;
wire [1:0] c_StoreSize;
wire       c_IsJALR;
wire       c_IsBranch;
decoder decoder_0 (
  // inputs
  .inst(d_insn),
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
wire [4:0] r_addr_rs1 = d_rs1;
wire [4:0] r_addr_rs2 = d_rs2;
wire [4:0] r_addr_rd  = d_rd;
wire [31:0] r_data_rs1;
wire [31:0] r_data_rs2;
reg [31:0] w_data_rd;
register_file register_file_0 (
  // inputs
  .clock(clock),
  .addr_rs1(r_addr_rs1),
  .addr_rs2(r_addr_rs2),
  .addr_rd(mem_wb_rd),
  .data_rd(w_data_rd),
  .write_enable(mem_wb_RegWEn &~ reset),
  // outputs
  .data_rs1(r_data_rs1),
  .data_rs2(r_data_rs2)
);
// Register File --------

// ID/EX Pipeline Registers ------
reg        id_ex_valid;
reg [31:0] id_ex_pc;
reg [31:0] id_ex_imm;
reg [31:0] id_ex_data_rs1;
reg [31:0] id_ex_data_rs2;
reg [4:0]  id_ex_rs1;
reg [4:0]  id_ex_rs2;
reg [4:0]  id_ex_rd;
reg        id_ex_RegWEn;
reg [2:0]  id_ex_funct3;
reg        id_ex_is_branch;
reg        id_ex_is_jalr;
reg        id_ex_ASel;
reg        id_ex_BSel;
reg [3:0]  id_ex_ALUSel;
reg        id_ex_PCSel;
reg        id_ex_MemRW;
reg [1:0]  id_ex_LoadSize;
reg        id_ex_LoadUnsigned;
reg [1:0]  id_ex_StoreSize;
reg [1:0]  id_ex_WBSel;
reg [31:0] fwd_data_rs1;
reg [31:0] fwd_data_rs2;
// ID pipline control wires
wire id_stall;   // driven by hazard detection
wire id_flush;   // driven by branch/jump resolution
wire id_bubble;  // driven by hazard detection
always @(posedge clock) begin
  if (reset) begin
    id_ex_valid        <= 1'b0;
    id_ex_pc           <= 32'b0;
    id_ex_imm          <= 32'b0;
    id_ex_data_rs1     <= 32'b0;
    id_ex_data_rs2     <= 32'b0;
    id_ex_rs1          <= 5'b0;
    id_ex_rs2          <= 5'b0;
    id_ex_rd           <= 5'b0;
    id_ex_RegWEn       <= 1'b0;
    id_ex_funct3       <= 3'b0;
    id_ex_is_branch    <= 1'b0;
    id_ex_is_jalr      <= 1'b0;
    id_ex_ASel         <= `A_REG;
    id_ex_BSel         <= `B_REG;
    id_ex_ALUSel       <= `ALU_ADD;
    id_ex_PCSel        <= `PC_PLUS4;
    id_ex_MemRW        <= `MEM_READ;
    id_ex_LoadSize     <= `LS_W;
    id_ex_LoadUnsigned <= 1'b0;
    id_ex_StoreSize    <= `LS_W;
    id_ex_WBSel        <= `WB_ALU;
  end else if (id_flush || id_bubble) begin
    id_ex_valid        <= 1'b0;
    id_ex_pc           <= d_pc;     
    id_ex_imm          <= 32'b0;
    id_ex_data_rs1     <= 32'b0;
    id_ex_data_rs2     <= 32'b0;
    id_ex_rs1          <= 5'b0;
    id_ex_rs2          <= 5'b0;
    id_ex_rd           <= 5'b0;
    id_ex_RegWEn       <= 1'b0;
    id_ex_funct3       <= 3'b0;
    id_ex_is_branch    <= 1'b0;
    id_ex_is_jalr      <= 1'b0;
    id_ex_ASel         <= `A_REG;
    id_ex_BSel         <= `B_REG;
    id_ex_ALUSel       <= `ALU_ADD;
    id_ex_PCSel        <= `PC_PLUS4;
    id_ex_MemRW        <= `MEM_READ;
    id_ex_LoadSize     <= `LS_W;
    id_ex_LoadUnsigned <= 1'b0;
    id_ex_StoreSize    <= `LS_W;
    id_ex_WBSel        <= `WB_ALU;
  end else if (!id_stall) begin
    id_ex_valid        <= if_id_valid;
    id_ex_pc           <= d_pc;
    id_ex_imm          <= d_imm;
    id_ex_data_rs1     <= r_data_rs1;
    id_ex_data_rs2     <= r_data_rs2;
    id_ex_rs1          <= d_rs1;
    id_ex_rs2          <= d_rs2;
    id_ex_rd           <= d_rd;
    id_ex_RegWEn       <= c_RegWEn;
    id_ex_funct3       <= d_funct3;
    id_ex_is_branch    <= c_IsBranch;
    id_ex_is_jalr      <= c_IsJALR;
    id_ex_ASel         <= c_ASel;
    id_ex_BSel         <= c_BSel;
    id_ex_ALUSel       <= c_ALUSel;
    id_ex_PCSel        <= c_PCSel;
    id_ex_MemRW        <= c_MemRW;
    id_ex_LoadSize     <= c_LoadSize;
    id_ex_LoadUnsigned <= c_LoadUnsigned;
    id_ex_StoreSize    <= c_StoreSize;
    id_ex_WBSel        <= c_WBSel;
  end
end
// ID/EX Pipeline Registers ------

/* Decode End ------------------------------------------- */



/* Execute ---------------------------------------------- */
reg [31:0] e_pc;
reg [31:0] e_pc_plus4;
// Pipeline register from ID/EX to Execute stage
always @(*) begin
  e_pc = id_ex_pc;
end

// BCU -------------------
wire e_branch_taken;
bcu bcu_0 (
  // inputs
  .is_branch(id_ex_is_branch),
  .funct3(id_ex_funct3),
  .rs1(fwd_data_rs1),
  .rs2(fwd_data_rs2),
  // outputs
  .branch_taken(e_branch_taken)
);
// BCU -------------------

// ALU -------------------
reg [31:0] e_alu_a;
reg [31:0] e_alu_b;
wire [31:0] e_alu_res;
always @(*) begin
  // Default values
  e_alu_a = 32'b0;
  e_alu_b = 32'b0;
  // A input select mux
  if (id_ex_ASel == `A_PC) begin
    e_alu_a = e_pc;
  end else if (id_ex_ASel == `A_REG) begin
    e_alu_a = fwd_data_rs1;
  end
  // B input select mux
  if (id_ex_BSel == `B_REG) begin
    e_alu_b = fwd_data_rs2;
  end else if (id_ex_BSel == `B_IMM) begin
    e_alu_b = id_ex_imm;
  end
end
alu alu_0 (
  // inputs
  .A(e_alu_a),
  .B(e_alu_b),
  .ALUSel(id_ex_ALUSel),
  // outputs
  .ALURes(e_alu_res)
);
// ALU -------------------

// Branch/Jump Resolve Logic --------
assign e_branch_redirect = id_ex_valid && id_ex_is_branch && e_branch_taken;
assign e_jalr_redirect   = id_ex_valid && id_ex_is_jalr;
assign e_jal_redirect    = id_ex_valid && !id_ex_is_branch && !id_ex_is_jalr && (id_ex_PCSel == `PC_ALU);
assign e_redirect        = e_branch_redirect | e_jalr_redirect | e_jal_redirect;
assign e_redirect_target = e_jalr_redirect ? (e_alu_res & ~32'd1)
                                           : e_alu_res;
assign if_flush = e_redirect;
assign id_flush = e_redirect;

// EX/MEM Pipeline Registers ------
reg        ex_mem_valid;
reg [31:0] ex_mem_pc;
reg [1:0]  ex_mem_LoadSize;
reg        ex_mem_LoadUnsigned;
reg [1:0]  ex_mem_StoreSize;
reg [31:0] ex_mem_alu_res;
reg [31:0] ex_mem_data_rs2;
reg        ex_mem_MemRW;
reg [1:0]  ex_mem_WBSel;
reg [4:0]  ex_mem_rs2;
reg [4:0]  ex_mem_rd;
reg        ex_mem_RegWEn;
// EX pipeline control wires
wire ex_stall;  // driven by hazard detection
wire ex_bubble;  // driven by hazard detection
always @(posedge clock) begin
  if (reset) begin
    ex_mem_valid        <= 1'b0;
    ex_mem_pc           <= 32'b0;
    ex_mem_LoadSize     <= `LS_W;
    ex_mem_LoadUnsigned <= 1'b0;
    ex_mem_StoreSize    <= `LS_W;
    ex_mem_alu_res      <= 32'b0;
    ex_mem_data_rs2     <= 32'b0;
    ex_mem_MemRW        <= `MEM_READ;
    ex_mem_WBSel        <= `WB_ALU;
    ex_mem_rs2          <= 5'b0;
    ex_mem_rd           <= 5'b0;
    ex_mem_RegWEn       <= 1'b0;
  end else if (ex_bubble) begin
    ex_mem_valid        <= 1'b0;
    ex_mem_pc           <= e_pc;
    ex_mem_LoadSize     <= `LS_W;
    ex_mem_LoadUnsigned <= 1'b0;
    ex_mem_StoreSize    <= `LS_W;
    ex_mem_alu_res      <= 32'b0;
    ex_mem_data_rs2     <= 32'b0;
    ex_mem_MemRW        <= `MEM_READ;
    ex_mem_WBSel        <= `WB_ALU;
    ex_mem_rs2          <= 5'b0;
    ex_mem_rd           <= 5'b0;
    ex_mem_RegWEn       <= 1'b0;
  end else if (!ex_stall) begin
    ex_mem_valid        <= id_ex_valid;
    ex_mem_pc           <= e_pc;
    ex_mem_LoadSize     <= id_ex_LoadSize;
    ex_mem_LoadUnsigned <= id_ex_LoadUnsigned;
    ex_mem_StoreSize    <= id_ex_StoreSize;
    ex_mem_alu_res      <= e_alu_res;
    ex_mem_data_rs2     <= fwd_data_rs2;
    ex_mem_MemRW        <= id_ex_MemRW;
    ex_mem_WBSel        <= id_ex_WBSel;
    ex_mem_rs2          <= id_ex_rs2;
    ex_mem_rd           <= id_ex_rd;
    ex_mem_RegWEn       <= id_ex_RegWEn;
  end
end
// EX/MEM Pipeline Registers ------

/* Execute End ----------------------------------------- */



/* Memory ---------------------------------------------- */
reg [31:0] m_pc;
wire [31:0] m_data;
reg  [31:0] m_data_q;
reg [1:0] m_access_size;
always @(*) begin
  m_access_size = (ex_mem_MemRW == `MEM_WRITE) ? ex_mem_StoreSize : ex_mem_LoadSize;
end

// Pipeline register from EX/MEM to Memory stage
always @(*) begin
  m_pc = ex_mem_pc;
end

// DMem -----------------
dmemory dmemory_0 (
  // inputs
  .clock(clock),
  .read_write(ex_mem_MemRW),
  .access_size(m_access_size),
  .address(ex_mem_alu_res),
  .data_in(fwd_dmem_data_rs2),
  // outputs
  .data_out(m_data)
);
// DMem -----------------

// MEM/WB Pipeline Registers ------
// MEM pipeline control wires
//wire mem_stall = ex_stall;
always @(posedge clock) begin
  if (reset) begin
    m_data_q           <= 32'b0;
    mem_wb_pc           <= 32'b0;
    mem_wb_valid        <= 1'b0;
    mem_wb_dmem_data    <= 32'b0;
    mem_wb_WBSel        <= `WB_ALU;
    mem_wb_rd           <= 5'b0;
    mem_wb_RegWEn       <= 1'b0;
    mem_wb_LoadSize     <= `LS_W;
    mem_wb_LoadUnsigned <= 1'b0;
    mem_wb_alu_res      <= 32'b0;
  end else begin
    mem_wb_pc           <= m_pc;
    mem_wb_valid        <= ex_mem_valid;
    m_data_q           <= m_data;
    mem_wb_dmem_data    <= m_data_q;
    mem_wb_WBSel        <= ex_mem_WBSel;
    mem_wb_rd           <= ex_mem_rd;
    mem_wb_RegWEn       <= ex_mem_RegWEn;
    mem_wb_LoadSize     <= ex_mem_LoadSize;
    mem_wb_LoadUnsigned <= ex_mem_LoadUnsigned;
    mem_wb_alu_res      <= ex_mem_alu_res;
  end
end

/* Memory End ---------------------------------------- */




/* Write Back ---------------------------------------- */
reg [31:0] w_pc;
// Pipeline register from EX/MEM to Memory stage
always @(*) begin
  w_pc = mem_wb_pc;
end

// Write Back Mux
always @(*) begin
  // Default
  w_data_rd = 32'b0;
  case (mem_wb_WBSel)
    `WB_MEM: begin
      case (mem_wb_LoadSize)
        `LS_B: begin
          if (mem_wb_LoadUnsigned) begin
            w_data_rd = {24'b0, mem_wb_dmem_data[7:0]};
          end else begin
            w_data_rd = {{24{mem_wb_dmem_data[7]}}, mem_wb_dmem_data[7:0]};
          end
        end
        `LS_H: begin
          if (mem_wb_LoadUnsigned) begin
            w_data_rd = {16'b0, mem_wb_dmem_data[15:0]};
          end else begin
            w_data_rd = {{16{mem_wb_dmem_data[15]}}, mem_wb_dmem_data[15:0]};
          end
        end
        `LS_W: begin
          w_data_rd = mem_wb_dmem_data;
        end
        default: begin
          w_data_rd = mem_wb_dmem_data;
        end
      endcase
    end
    `WB_ALU: begin
      w_data_rd = mem_wb_alu_res;
      // $display("WD ALU: WB PC %h rd x%0d WB Data %h mem_wb_valid %b Valid at time %0t", mem_wb_pc, mem_wb_rd, w_data_rd, mem_wb_valid, $time);
    end
    `WB_PC4: begin
      w_data_rd = w_pc + 32'd4;
    end
    default: begin
      w_data_rd = 32'b0;
    end
  endcase
end
/* Write Back End ------------------------------------- */



/* Forwarding Control Unit --------------------------- */
// MX/WX Forward Logic, priority MX > WX
always @(*) begin
  // Default no forwarding
  fwd_data_rs1 = id_ex_data_rs1;
  fwd_data_rs2 = id_ex_data_rs2;
  // MX Forward Logic
  // Only forward insn that write to reg file, check ex_mem_RegWEn
  if (ex_mem_RegWEn && (ex_mem_rd != 5'b0) && ex_mem_valid && (ex_mem_WBSel != `WB_MEM)) begin
    case (ex_mem_WBSel)
      `WB_ALU: begin
        // Forward ALU result
      if (id_ex_rs1 == ex_mem_rd) 
        fwd_data_rs1 = ex_mem_alu_res;
       
      if (id_ex_rs2 == ex_mem_rd) 
        fwd_data_rs2 = ex_mem_alu_res;
      end
      `WB_PC4: begin
        // Forward PC + 4
      if (id_ex_rs1 == ex_mem_rd) 
        fwd_data_rs1 = ex_mem_pc + 32'd4; 
      if (id_ex_rs2 == ex_mem_rd)
        fwd_data_rs2 = ex_mem_pc + 32'd4;
      end
      default: begin
        // Do nothing 
      end
    endcase
  end
  // WX Forward Logic
  // Only forward insn that write to reg file, check mem_wb_RegWEn
  if (mem_wb_RegWEn && (mem_wb_rd != 5'b0) && mem_wb_valid) begin
    // Exclude MX fowarding conditions
    if (!ex_mem_RegWEn || id_ex_rs1 != ex_mem_rd) begin
      if (id_ex_rs1 == mem_wb_rd) begin
        fwd_data_rs1 = w_data_rd;
        $display("WX forward: PC %h rs1 x%0d forwarded data %h at time %0t", mem_wb_pc, id_ex_rs1, w_data_rd, $time);
      end
    end
    if (!ex_mem_RegWEn || id_ex_rs2 != ex_mem_rd) begin
      if (id_ex_rs2 == mem_wb_rd) begin
        fwd_data_rs2 = w_data_rd;
        $display("WX forward: PC %h rs2 x%0d forwarded data %h at time %0t", mem_wb_pc, id_ex_rs2, w_data_rd, $time);
      end
    end
  end
end

// WM Forwarding Logic, S-type instructions only
always @(*) begin
  // Default no forwarding
  fwd_dmem_data_rs2 = ex_mem_data_rs2;
  // Only forward insn that write to reg file, check mem_wb_RegWEn
  if (mem_wb_valid && mem_wb_RegWEn && (mem_wb_rd != 5'b0)) begin
    if (ex_mem_MemRW == `MEM_WRITE && ex_mem_rs2 == mem_wb_rd) begin
      fwd_dmem_data_rs2 = w_data_rd; 
      $display("WM forward: store PC %h uses rs2 x%0d forwarded data %h at time %0t", ex_mem_pc, ex_mem_rs2, w_data_rd, $time);
    end
  end

  
end
/* Forwarding Control Unit End ----------------------- */



/* Hazard Resolve Unit ------------------------------- */
reg load_use_stall;
reg wd_stall;
// Track IF/ID contents to insert a bubble for synchronous RF read latency
reg last_if_id_valid;
reg [31:0] last_if_id_pc;
// Decode if_id fields
wire [4:0] if_id_rs1;
wire [4:0] if_id_rs2;
wire [6:0] if_id_opcode;
wire       if_id_isStore;
wire       if_id_uses_rs1;
wire       if_id_uses_rs2;
wire       r_latency_bubble;

assign if_id_rs1 = if_id_insn[19:15];
assign if_id_rs2 = if_id_insn[24:20];
assign if_id_opcode = if_id_insn[6:0];
assign if_id_isStore = (if_id_opcode == 7'b0100011);
assign if_id_uses_rs1 = !(if_id_opcode == 7'b0110111  // LUI
                        || if_id_opcode == 7'b0010111  // AUIPC
                        || if_id_opcode == 7'b1101111); // JAL
assign if_id_uses_rs2 = (if_id_opcode == 7'b0110011)   // R-type
                        || (if_id_opcode == 7'b1100011)   // Branch
                        || (if_id_opcode == 7'b0100011);  // Store
                       
// Detect new instruction arrival to force a one-cycle bubble for sync regfile read
assign r_latency_bubble = if_id_valid && (!last_if_id_valid || (if_id_pc != last_if_id_pc));

always @(posedge clock) begin
  if (reset || if_flush) begin
    last_if_id_valid <= 1'b0;
    last_if_id_pc    <= 32'b0;
  end else begin
    last_if_id_valid <= if_id_valid;
    last_if_id_pc    <= if_id_pc;
  end
end

always @(*) begin
  // Load-Use Hazard Detection
  load_use_stall = 1'b0;
  if (if_id_valid && id_ex_valid && (id_ex_WBSel == `WB_MEM) && id_ex_RegWEn) begin
    if ((if_id_uses_rs1 && (if_id_rs1 == id_ex_rd)) || 
        (if_id_uses_rs2 && !if_id_isStore && (if_id_rs2 == id_ex_rd))) begin
      load_use_stall = 1'b1;
      $display("Load-Use stall: IF/ID pc %h rs1 x%0d rs2 x%0d blocked by EX PC %h rd x%0d at time %0t",
      if_id_pc, if_id_rs1, if_id_rs2, id_ex_pc, id_ex_rd, $time);
    end
  end
  // Additional stall when load is in MEM stage (synchronous read latency)
  if (if_id_valid && ex_mem_valid && (ex_mem_WBSel == `WB_MEM) && ex_mem_RegWEn) begin
    if ((if_id_uses_rs1 && (if_id_rs1 == ex_mem_rd)) || 
        (if_id_uses_rs2 && (if_id_rs2 == ex_mem_rd))) begin
      load_use_stall = 1'b1;
    end
  end

  // Write Back - Decode Hazard Detection
  wd_stall = 1'b0;
  if (if_id_valid && mem_wb_valid && mem_wb_RegWEn && (mem_wb_rd != 5'b0)) begin
    if ((if_id_uses_rs1 && (mem_wb_rd == if_id_rs1)) ||
        (if_id_uses_rs2 && !if_id_isStore && (mem_wb_rd == if_id_rs2))) begin
      wd_stall = 1'b1;
      $display("WD stall: IF/ID pc %h rs1 x%0d rs2 x%0d blocked by WB PC %h rd x%0d at time %0t", 
      if_id_pc, if_id_rs1, if_id_rs2, mem_wb_pc, mem_wb_rd, $time);
    end
  end

end

assign if_stall = load_use_stall | wd_stall | r_latency_bubble;
assign id_stall = load_use_stall | wd_stall | r_latency_bubble;
assign ex_bubble = 1'b0;         
assign ex_stall = 1'b0;   

assign id_bubble = load_use_stall | wd_stall | r_latency_bubble; 
assign if_bubble = 1'b0; 


/* Hazard Resolve Unit End --------------------------- */

// SimpleIf.d
always @(posedge clock) begin
  if (!reset && ex_mem_pc == 32'h010000c4)
    $display("Hit fail PC 0x10000c4 at cycle %0t", $time);
  else if (!reset && ex_mem_pc == 32'h010000b8)
    $display("Hit pass PC 0x10000b8 at cycle %0t", $time);
end

always @(posedge clock) begin
  if (!reset) begin
    // stop if PC wraps below the start address
    if (f_pc < 32'h01000000)
      $finish;
    // or stop on an all-zero instruction (optional)
    if (if_id_valid && if_id_insn == 32'h00000000)
      $finish;
  end
end

endmodule
