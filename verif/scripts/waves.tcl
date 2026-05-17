#!/usr/bin/env tclsh

set sigs {
  top.clkg.clk
  top.dut.reset
  top.dut.core.f_pc
  top.dut.core.d_pc
  top.dut.core.e_pc
  top.dut.core.m_pc
  top.dut.core.w_pc
  top.dut.core.f_insn
  top.dut.core.d_insn
  top.dut.core.load_use_stall
  top.dut.core.wd_stall
  top.dut.core.mem_wb_rd
  top.dut.core.w_data_rd
  top.dut.core.mem_wb_valid
  top.dut.core.ex_mem_data_rs2
  top.dut.core.fwd_dmem_data_rs2
  top.dut.core.mem_wb_RegWEn
   
}

set num_added [gtkwave::addSignalsFromList $sigs]
puts "Added $num_added signals:"
puts $sigs

# Zoom full view
gtkwave::/Time/Zoom/Zoom_Full
gtkwave::setZoomFactor -2
