/* Your Code Below! Enable the following define's
 * and replace ??? with actual wires */
// ----- signals -----
// You will also need to define PC properly
`define F_PC                f_pc
`define F_INSN              f_insn

`define D_PC                d_pc
`define D_OPCODE            if_id_insn[6:0]
`define D_RD                if_id_insn[11:7]
`define D_RS1               if_id_insn[19:15]
`define D_RS2               if_id_insn[24:20]
`define D_FUNCT3            if_id_insn[14:12]
`define D_FUNCT7            if_id_insn[31:25]
`define D_IMM               d_imm
`define D_SHAMT             d_shamt

`define R_WRITE_ENABLE      mem_wb_RegWEn
`define R_WRITE_DESTINATION mem_wb_rd
`define R_WRITE_DATA        w_data_rd
`define R_READ_RS1          r_addr_rs1
`define R_READ_RS2          r_addr_rs2
`define R_READ_RS1_DATA     r_data_rs1
`define R_READ_RS2_DATA     r_data_rs2

`define E_PC                e_pc
`define E_ALU_RES           e_alu_res
`define E_BR_TAKEN          e_branch_taken

`define M_PC                m_pc
`define M_ADDRESS           ex_mem_alu_res
`define M_RW                ex_mem_MemRW
`define M_SIZE_ENCODED      m_access_size
`define M_DATA              fwd_dmem_data_rs2

`define W_PC                w_pc
`define W_ENABLE            mem_wb_RegWEn
`define W_DESTINATION       mem_wb_rd
`define W_DATA              w_data_rd

`define IMEMORY             imemory_0
`define DMEMORY             dmemory_0

// ----- signals -----

// ----- design -----
`define TOP_MODULE                 pd
// ----- design -----
