./timescale.sv

#TB_lib
#../../../NPU_wrap_TB_lib/interface/axi_bus.sv  
#../../../NPU_wrap_TB_lib/driver.sv
#../../../NPU_wrap_TB_lib/API.sv

-f ../../FLISTS/tb_lib.f

#axi design
../RTL/TOP_device.v
../../AXI_slave_module/RTL/AXI_slave.v
../../axi_slave_mem_device/RTL/axi_slave_mem_device.v
../../AXI_master_module/RTL/AXI_master.v


./axi_test.sv

