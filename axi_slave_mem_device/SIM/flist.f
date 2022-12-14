./timescale.sv

#TB_lib
#../../../NPU_wrap_TB_lib/interface/axi_bus.sv  
#../../../NPU_wrap_TB_lib/driver.sv
#../../../NPU_wrap_TB_lib/API.sv

-f ../../FLISTS/tb_lib.f

#axi design
../RTL/axi_slave_mem_device.v
../../AXI_slave_module/RTL/AXI_slave.v
../../AXI_slave_module/RTL/AXI_slave_AW_module.v
../../AXI_slave_module/RTL/AXI_slave_AR_module.v
../../AXI_master_module/RTL/AXI_master.v
../../FIFO/RTL/fifo.v

./axi_test.sv

