/*
AXI slave, HWPE master
direct connect AXI slave module's memory access signal to HWPE master signals

HWPE master is a "true" master, have only gnt, no ID. Do not need HWPE master ID signal.

*/

`timescale 1 ns / 1 ps

	module axi_slave_HWPE_M_mem_wrap #
	(
		parameter integer AXI_ID_WIDTH	= 1,
		parameter integer AXI_DATA_WIDTH	= 32,
        parameter integer AXI_STRB_WIDTH        = AXI_DATA_WIDTH/8,

		parameter integer AXI_ADDR_WIDTH	= 32, //ARES addr must be 32bit！
        parameter integer AXI_USER_WIDTH        = 10,

        //MEM
        parameter integer ADDR_MEM_SINGLE_WIDTH   = 12,
        parameter integer N_SLAVE          = 2,
        parameter integer ADDR_MEM_TOTAL_WIDTH    = ADDR_MEM_SINGLE_WIDTH+$clog2(N_SLAVE),


        //parameter integer DATA_MEM_LENGTH       = 16,
        //parameter integer OPT_MEM_ADDR_BITS     = $clog2(DATA_MEM_LENGTH),
	    

        parameter integer ADDR_LSB = $clog2(AXI_DATA_WIDTH/8), //2
        parameter integer ADDR_BASE_OFFSET = 0,

        parameter integer AXI_AR_FIFO_LENGTH = 8,

	    parameter integer ADDR_ST  = 'h0 + ADDR_BASE_OFFSET,
	    parameter integer ADDR_END  = 'h10000 + ADDR_BASE_OFFSET //0x1_0000 = 65536 bytes, or 16384 * 32 bits = 4096 * 4 * 32 bits
    )
	(

        //`include "AXI_IO_define.svh"
        //{{{
        input [AXI_ID_WIDTH-1:0]   AXI_slave_awid,
        input [AXI_ADDR_WIDTH-1:0] AXI_slave_awaddr,
        input [7:0]                AXI_slave_awlen,
        input [2:0]                AXI_slave_awsize,
        input [1:0]                AXI_slave_awburst,
        input                      AXI_slave_awlock,
        input [3:0]                AXI_slave_awcache,
        input [2:0]                AXI_slave_awprot,
        input [3:0]                AXI_slave_awqos,
        input [3:0]                AXI_slave_awregion,
        input [AXI_USER_WIDTH-1:0] AXI_slave_awuser,
        input                      AXI_slave_awvalid,
        output                     AXI_slave_awready,

        input [AXI_DATA_WIDTH-1:0] AXI_slave_wdata,
        input [AXI_STRB_WIDTH-1:0] AXI_slave_wstrb,
        input                      AXI_slave_wlast,
        input [AXI_USER_WIDTH-1:0] AXI_slave_wuser,
        input                      AXI_slave_wvalid,
        output                     AXI_slave_wready,
        input [AXI_ID_WIDTH-1:0]   AXI_slave_wid,
        
        output [AXI_ID_WIDTH-1:0]   AXI_slave_bid,
        output [1:0]                AXI_slave_bresp,
        output [AXI_USER_WIDTH-1:0] AXI_slave_buser,
        output                      AXI_slave_bvalid,
        input                       AXI_slave_bready,

        input [AXI_ID_WIDTH-1:0]   AXI_slave_arid,
        input [AXI_ADDR_WIDTH-1:0] AXI_slave_araddr,
        input [7:0]                AXI_slave_arlen,
        input [2:0]                AXI_slave_arsize,
        input [1:0]                AXI_slave_arburst,
        input                      AXI_slave_arlock,
        input [3:0]                AXI_slave_arcache,
        input [2:0]                AXI_slave_arprot,
        input [3:0]                AXI_slave_arqos,
        input [3:0]                AXI_slave_arregion,
        input [AXI_USER_WIDTH-1:0] AXI_slave_aruser,
        input                      AXI_slave_arvalid,
        output                     AXI_slave_arready,


        output [AXI_ID_WIDTH-1:0]   AXI_slave_rid,
        output [AXI_DATA_WIDTH-1:0] AXI_slave_rdata,
        output [1:0]                AXI_slave_rresp,
        output                      AXI_slave_rlast,
        output [AXI_USER_WIDTH-1:0] AXI_slave_ruser,
        output                      AXI_slave_rvalid,
        input                       AXI_slave_rready,

        //}}}

        output wire                                 HWPE_M_data_req_o,                   
        output reg [ADDR_MEM_TOTAL_WIDTH-1:0]       HWPE_M_data_add_o,
        output wire                                 HWPE_M_data_wen_o,
        output wire [AXI_DATA_WIDTH-1:0]            HWPE_M_data_wdata_o,
        output wire [AXI_STRB_WIDTH - 1:0]          HWPE_M_data_be_o,
        input  wire                                 HWPE_M_data_gnt_i, 
        input  wire                                 HWPE_M_data_r_valid_i,
        input  wire [AXI_DATA_WIDTH-1:0]            HWPE_M_data_r_rdata_i,      

 
        input wire  clk,
		input wire  rst_n
	);

    wire [AXI_DATA_WIDTH-1:0] AXI_slave_write_data; 
    wire [3:0]                AXI_slave_write_strb; 
    wire [AXI_ADDR_WIDTH-1:0] AXI_slave_w_opt_addr; 
    wire AXI_slave_write_valid; 

    wire  [AXI_DATA_WIDTH-1:0] AXI_slave_read_data; 
    wire  [AXI_ADDR_WIDTH-1:0] AXI_slave_r_opt_addr; 
    wire  AXI_slave_read_req;
    wire  AXI_slave_read_valid;

    //Instantiation of AXI_slave_module 
    //{{{
    pure_AXI_slave_design #(
		.AXI_ID_WIDTH	        (AXI_ID_WIDTH	     ), 
		.AXI_DATA_WIDTH	        (AXI_DATA_WIDTH	     ), 
		.AXI_ADDR_WIDTH	        (AXI_ADDR_WIDTH	     ), 
        .ADDR_BASE_OFFSET       (ADDR_BASE_OFFSET),
        .AR_FIFO_LENGTH         (AXI_AR_FIFO_LENGTH),
        .ADDR_ST                (ADDR_ST),
        .ADDR_END               (ADDR_END)

    ) AXI_SLAVE (
        //axi full data
        //{{{
		.awid           (AXI_slave_awid    ),
		.awaddr         (AXI_slave_awaddr),
		.awlen          (AXI_slave_awlen   ),
		.awsize         (AXI_slave_awsize  ),
		.awburst        (AXI_slave_awburst ),
		.awlock         (AXI_slave_awlock  ),
		.awcache        (AXI_slave_awcache ),
		.awprot         (AXI_slave_awprot  ),
		.awqos          (AXI_slave_awqos   ),
		.awregion       (AXI_slave_awregion),
		.awuser         (AXI_slave_awuser  ),
		.awvalid        (AXI_slave_awvalid ),
		.awready        (AXI_slave_awready ),
		.wdata          (AXI_slave_wdata    ),
		.wstrb          (AXI_slave_wstrb    ),
		.wlast          (AXI_slave_wlast    ),
		.wuser          (AXI_slave_wuser    ),
		.wvalid	        (AXI_slave_wvalid   ),
		.wready	        (AXI_slave_wready   ),
		.bid		    (AXI_slave_bid	    ),
		.bresp		    (AXI_slave_bresp	),
		.buser		    (AXI_slave_buser	),
		.bvalid	        (AXI_slave_bvalid   ),
		.bready	        (AXI_slave_bready   ),
		.arid		    (AXI_slave_arid	    ),
		.araddr	        (AXI_slave_araddr   ),
		.arlen		    (AXI_slave_arlen	),
		.arsize	        (AXI_slave_arsize   ),
		.arburst	    (AXI_slave_arburst  ),
		.arlock	        (AXI_slave_arlock   ),
		.arcache	    (AXI_slave_arcache  ),
		.arprot	        (AXI_slave_arprot   ),
		.arqos		    (AXI_slave_arqos	),
		.arregion	    (AXI_slave_arregion ),
		.aruser	        (AXI_slave_aruser   ),
		.arvalid	    (AXI_slave_arvalid  ),
		.arready	    (AXI_slave_arready  ),
		.rid		    (AXI_slave_rid	    ),
		.rdata		    (AXI_slave_rdata	),
		.rresp		    (AXI_slave_rresp	),
		.rlast		    (AXI_slave_rlast	),
		.ruser		    (AXI_slave_ruser	),
		.rvalid	        (AXI_slave_rvalid   ),
		.rready	        (AXI_slave_rready   ),
        //}}}
		
        //eight useful signals
        .write_data(AXI_slave_write_data),
        .write_strb(AXI_slave_write_strb),
        .w_opt_addr(AXI_slave_w_opt_addr),
        .write_valid(AXI_slave_write_valid),

        .read_data(AXI_slave_read_data),
        .r_opt_addr(AXI_slave_r_opt_addr),
        .read_req  (AXI_slave_read_req),
        .read_valid(AXI_slave_read_valid),
        
        .aw_ar_ready            (1), //slave mem, always ready to receive new instr

        .clk                    (clk),
		.rst_n                  (rst_n)
        
    ); 
    //}}}
 

//req_o
assign HWPE_M_data_req_o = AXI_slave_write_valid || AXI_slave_read_req;

//add_o
always @(*) begin
    if (AXI_slave_write_valid == 1) begin
        HWPE_M_data_add_o = AXI_slave_w_opt_addr;
    end
    else if (AXI_slave_read_req) begin
        HWPE_M_data_add_o = AXI_slave_r_opt_addr;
    end
    else begin
        HWPE_M_data_add_o = 0;
    end
end

assign HWPE_M_data_wen_o = AXI_slave_write_valid;
assign HWPE_M_data_wdata_o = AXI_slave_write_data;
assign HWPE_M_data_be_o = AXI_slave_write_strb;
assign AXI_slave_read_data[AXI_DATA_WIDTH-1:0] = HWPE_M_data_r_rdata_i[AXI_DATA_WIDTH-1:0];
assign AXI_slave_read_valid = HWPE_M_data_r_valid_i;



endmodule
