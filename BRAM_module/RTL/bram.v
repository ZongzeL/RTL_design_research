/*
这个文件是给VCS 跑仿真用的，替代xilinx的ip Block Memory Generator
不用写成可综合，也不会把它放进真正的design里面去
原文件：/home/ares/Tool/Xilinx/Vivado/2020.2/data/ip/xilinx/blk_mem_gen_v8_4/simulation/blk_mem_gen_v8_4.v 
vivado 生成文件： /home/ares/FPGA_proj/my_vivado_projects/zcu102/zcu102_npu_pro_axi_bus_driver/zcu102_npu_pro_axi_bus_driver.srcs/sources_1/bd/design_1/ip/design_1_blk_mem_gen_0_1/design_1_blk_mem_gen_0_1.xci
暂时不知道怎么用
Doc: pg058-blk-mem-gen.pdf
*/
`timescale 1 ns / 1 ps

module blk_mem_gen_0 #
//{{{
(
    parameter integer DATA_WIDTH	= 64,
    parameter integer ADDR_WIDTH	= 10,
    parameter integer MEM_LENGTH	= 16
)
(

    input [ADDR_WIDTH - 1 : 0] ADDRA,
    input CLKA,
    input [DATA_WIDTH - 1 : 0] DINA,
    output wire [DATA_WIDTH - 1 : 0] DOUTA,
    input ENA,
    input WEA


);

    reg [DATA_WIDTH - 1 : 0] data_mem [MEM_LENGTH - 1 : 0];
    reg [ADDR_WIDTH - 1 : 0] addr_buff_0; 
    reg [ADDR_WIDTH - 1 : 0] addr_buff_1;
    
    assign DOUTA = data_mem[addr_buff_1];


always @(posedge CLKA) begin
    if (ENA == 1 && WEA == 1) begin
        data_mem[ADDRA] <= DINA;
    end
end


always @(posedge CLKA) begin
    addr_buff_0 <= ADDRA;
end

always @(posedge CLKA) begin
    addr_buff_1 <= addr_buff_0;
end



endmodule
//}}}

module blk_mem_gen_1 #
//{{{
(
    parameter integer DATA_WIDTH	= 64,
    parameter integer ADDR_WIDTH	= 10,
    parameter integer MEM_LENGTH	= 16
)
(

    input [ADDR_WIDTH - 1 : 0] ADDRA,
    input CLKA,
    input [DATA_WIDTH - 1 : 0] DINA,
    output wire [DATA_WIDTH - 1 : 0] DOUTA,
    input ENA,
    input WEA


);
    reg [DATA_WIDTH - 1 : 0] data_mem [MEM_LENGTH - 1 : 0];
    
    assign DOUTA = data_mem[ADDRA];

always @(posedge CLKA) begin
    if (ENA == 1 && WEA == 1) begin
        data_mem[ADDRA] <= DINA;
    end
end
endmodule
//}}}


module blk_mem_gen_four_byte #
//{{{
(
    parameter integer DATA_WIDTH	= 64,
    parameter integer ADDR_WIDTH	= 32,
    parameter integer MEM_LENGTH	= 16
)
(

    input [ADDR_WIDTH - 1 : 0] ADDRA,
    input CLKA,
    input [DATA_WIDTH - 1 : 0] DINA,
    output wire [DATA_WIDTH - 1 : 0] DOUTA,
    input ENA,
    input [3:0] WEA


);

    reg [DATA_WIDTH - 1 : 0] data_mem [MEM_LENGTH - 1 : 0];
    reg [ADDR_WIDTH - 1 : 0] addr_buff_0; 
    reg [ADDR_WIDTH - 1 : 0] addr_buff_1;
    
    assign DOUTA = data_mem[addr_buff_1>>2];


always @(posedge CLKA) begin
    if (ENA == 1 && WEA[0:0] == 1) begin
        data_mem[ADDRA>>2][7:0] <= DINA[7:0];
    end
    if (ENA == 1 && WEA[1:1] == 1) begin
        data_mem[ADDRA>>2][15:8] <= DINA[15:8];
    end
    if (ENA == 1 && WEA[2:2] == 1) begin
        data_mem[ADDRA>>2][23:16] <= DINA[23:16];
    end
    if (ENA == 1 && WEA[3:3] == 1) begin
        data_mem[ADDRA>>2][31:24] <= DINA[31:24];
    end
end


always @(posedge CLKA) begin
    addr_buff_0 <= ADDRA;
end

always @(posedge CLKA) begin
    addr_buff_1 <= addr_buff_0;
end



endmodule
//}}}

