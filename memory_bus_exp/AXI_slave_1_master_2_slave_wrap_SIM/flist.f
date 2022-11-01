./timescale.sv

#TB_lib
-f ../../FLISTS/tb_lib.f

#top, axi_slave_HWPE_mem_wrap
../../axi_slave_HWPE_M_mem_wrap/RTL/axi_slave_HWPE_M_mem_wrap.v
../../AXI_slave_module/RTL/AXI_slave.v
../../AXI_slave_module/RTL/AXI_slave_AW_module.v
../../AXI_slave_module/RTL/AXI_slave_AR_module.v
../../FIFO/RTL/fifo.v

#HWPE XBAR
../../L2_tcdm_hybrid_interco/RTL/XBAR_L2/XBAR_L2.sv
../../L2_tcdm_hybrid_interco/RTL/XBAR_L2/one_master_two_slave_XBAR_L2_wrap.v
#../../L2_tcdm_hybrid_interco/RTL/XBAR_L2/XBAR_L2.v
../../L2_tcdm_hybrid_interco/RTL/XBAR_L2/RequestBlock_L2_1CH.sv     
../../L2_tcdm_hybrid_interco/RTL/XBAR_L2/ArbitrationTree_L2.sv      
../../L2_tcdm_hybrid_interco/RTL/XBAR_L2/RR_Flag_Req_L2.sv      
../../L2_tcdm_hybrid_interco/RTL/XBAR_L2/FanInPrimitive_Req_L2.sv   
../../L2_tcdm_hybrid_interco/RTL/XBAR_L2/AddressDecoder_Resp_L2.sv  

../../L2_tcdm_hybrid_interco/RTL/XBAR_L2/ResponseBlock_L2.sv
../../L2_tcdm_hybrid_interco/RTL/XBAR_L2/AddressDecoder_Req_L2.sv   
../../L2_tcdm_hybrid_interco/RTL/XBAR_L2/ResponseTree_L2.sv
../../L2_tcdm_hybrid_interco/RTL/XBAR_L2/FanInPrimitive_Resp_L2.sv  

#BRAM model
../../BRAM_module/HWPE_M_BRAM_S_wrap/HWPE_M_BRAM_S_wrap_single.v
../../BRAM_module/RTL/bram.v



#tb
./tb.sv

