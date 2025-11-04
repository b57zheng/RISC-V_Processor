`ifndef _CONTROL_DEFS_VH
`define _CONTROL_DEFS_VH

`define TRUE          1'b1
`define FALSE         1'b0

/* PC select  ------------------------ */
`define PC_PLUS4      1'b0  
`define PC_ALU        1'b1  

/* ALU op encoding ----------------- */
`define ALU_ADD       4'b0000
`define ALU_SUB       4'b0001
`define ALU_AND       4'b0010
`define ALU_OR        4'b0011
`define ALU_XOR       4'b0100
`define ALU_SLT       4'b0101   // signed <
`define ALU_SLTU      4'b0110   // unsigned <
`define ALU_SLL       4'b0111
`define ALU_SRL       4'b1000
`define ALU_SRA       4'b1001
`define ALU_COPY_B    4'b1010   // pass B through for LUI

/* ALU operand selects --------------- */
// ASel
`define A_REG         1'b0      // rs1
`define A_PC          1'b1      // current PC
// BSel
`define B_REG         1'b0      // rs2
`define B_IMM         1'b1      // immediate

/* Writeback select --------------- */
`define WB_MEM        2'b00      // write load data
`define WB_ALU        2'b01      // write ALU result
`define WB_PC4        2'b10      // write PC+4 

/* Memory Read/Write --------------- */
`define MEM_READ      1'b0
`define MEM_WRITE     1'b1

/* Load/Store sizes ---------------- */
`define LS_B          2'b00
`define LS_H          2'b01
`define LS_W          2'b10
`define L_UNSIGNED    1'b1

/* Branch comparator mode ----------- */
`define BR_SIGNED     1'b0      // signed compares (SLT)
`define BR_UNSIGNED   1'b1      // unsigned compares (SLTU)

`endif // _CONTROL_DEFS_VH