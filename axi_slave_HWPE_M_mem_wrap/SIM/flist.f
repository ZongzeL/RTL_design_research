./timescale.sv

#TB_lib
#../../../NPU_wrap_TB_lib/interface/axi_bus.sv  
#../../../NPU_wrap_TB_lib/driver.sv
#../../../NPU_wrap_TB_lib/API.sv

-f ../../FLISTS/tb_lib.f

#axi design

../../BRAM_module/BRAM_wrap/BRAM_wrap_single.v
../../BRAM_module/BRAM_wrap/BRAM_wrap_four_byte.v
../../BRAM_module/RTL/bram.v
../../FIFO/RTL/fifo.v

../RTL/axi_slave_mem_wrap.v
../../AXI_slave_module/RTL/AXI_slave.v
../../AXI_slave_module/RTL/AXI_slave_AR_module.v
../../AXI_slave_module/RTL/AXI_slave_AW_module.v
#../../AXI_master_module/RTL/AXI_master.v


./axi_test_four_byte_mem.sv

