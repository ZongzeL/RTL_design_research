./timescale.sv

#TB_lib
#../../../NPU_wrap_TB_lib/interface/axi_bus.sv  
#../../../NPU_wrap_TB_lib/driver.sv
#../../../NPU_wrap_TB_lib/API.sv

#-f ../../FLISTS/tb_lib.f

#top design
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

../../BRAM_module/BRAM_wrap/BRAM_wrap_single.v
../../BRAM_module/BRAM_wrap/BRAM_wrap_four_byte.v
../../BRAM_module/RTL/bram.v

#tb
./tb.sv

