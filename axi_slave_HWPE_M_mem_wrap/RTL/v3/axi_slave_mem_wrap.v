/*
不管master还是slave，他们的任务就是把外面发来的读写指令（addr, len, strb，burst）翻译成自己内部对应的那种指令，他们只负责拦截不属于自己的指令，不负责翻译。
作为slave，所谓的拦截就是外面给它起了一个非法的aw/ar，它根本不相应。那么如何阻止外面发非法的aw/ar，或者外面已经发了，如何停止，那是外面的事。
slave接了那个aw/ar，就要忠实的翻译成对应的r/w_opt_addr，至于top怎么用那是top的事。


*/

`timescale 1 ns / 1 ps

	module axi_slave_mem_wrap #
	(
		parameter integer AXI_ID_WIDTH	= 1,
		parameter integer AXI_DATA_WIDTH	= 32,
        parameter integer AXI_STRB_WIDTH        = AXI_DATA_WIDTH/8,

		parameter integer AXI_ADDR_WIDTH	= 32, //ARES addr 一定要设成32bit！
        parameter integer AXI_USER_WIDTH        = 10,

        parameter integer DATA_MEM_LENGTH       = 16,
        parameter integer OPT_MEM_ADDR_BITS     = $clog2(DATA_MEM_LENGTH),
	    parameter integer ADDR_LSB = $clog2(AXI_DATA_WIDTH/8), //2
        parameter integer ADDR_BASE_OFFSET = 0,

        parameter integer AXI_AR_FIFO_LENGTH = 8,

	    parameter integer ADDR_ST  = 'h0 + ADDR_BASE_OFFSET,
	    parameter integer ADDR_END  = 'h400 + ADDR_BASE_OFFSET
    )
	(

        //`include "AXI_IO_define.svh"
        //{{{
        input [AXI_ID_WIDTH-1:0]   awid,
        input [AXI_ADDR_WIDTH-1:0] awaddr,
        input [7:0]                awlen,
        input [2:0]                awsize,
        input [1:0]                awburst,
        input                      awlock,
        input [3:0]                awcache,
        input [2:0]                awprot,
        input [3:0]                awqos,
        input [3:0]                awregion,
        input [AXI_USER_WIDTH-1:0] awuser,
        input                      awvalid,
        output                     awready,

        input [AXI_DATA_WIDTH-1:0] wdata,
        input [AXI_STRB_WIDTH-1:0] wstrb,
        input                      wlast,
        input [AXI_USER_WIDTH-1:0] wuser,
        input                      wvalid,
        output                     wready,
        input [AXI_ID_WIDTH-1:0]   wid,
        
        output [AXI_ID_WIDTH-1:0]   bid,
        output [1:0]                bresp,
        output [AXI_USER_WIDTH-1:0] buser,
        output                      bvalid,
        input                       bready,

        input [AXI_ID_WIDTH-1:0]   arid,
        input [AXI_ADDR_WIDTH-1:0] araddr,
        input [7:0]                arlen,
        input [2:0]                arsize,
        input [1:0]                arburst,
        input                      arlock,
        input [3:0]                arcache,
        input [2:0]                arprot,
        input [3:0]                arqos,
        input [3:0]                arregion,
        input [AXI_USER_WIDTH-1:0] aruser,
        input                      arvalid,
        output                     arready,


        output [AXI_ID_WIDTH-1:0]   rid,
        output [AXI_DATA_WIDTH-1:0] rdata,
        output [1:0]                rresp,
        output                      rlast,
        output [AXI_USER_WIDTH-1:0] ruser,
        output                      rvalid,
        input                       rready,

        //}}}

        output wire                         data_req_o,                   
        output reg [AXI_ADDR_WIDTH-1:0]     data_add_o,
        output wire                         data_wen_o,
        output wire [AXI_DATA_WIDTH-1:0]    data_wdata_o,
        output wire [AXI_STRB_WIDTH - 1:0]  data_be_o,
        input  wire                         data_gnt_i, 
        input  wire                         data_r_valid_i,
        input  wire [AXI_DATA_WIDTH-1:0]    data_r_rdata_i,      

 
        input wire  clk,
		input wire  rst_n
	);

    localparam integer ADDR_INPUT_ST    = ADDR_BASE_OFFSET >> ADDR_LSB;	
    localparam integer ADDR_INPUT_END   = (ADDR_BASE_OFFSET + 'h100) >> ADDR_LSB;	
   
    wire [AXI_DATA_WIDTH-1:0] AXI_slave_write_data; 
    wire [3:0]                AXI_slave_write_strb; 
    wire [AXI_ADDR_WIDTH-1:0] AXI_slave_w_opt_addr; 
    wire AXI_slave_write_valid; 

    reg  [AXI_DATA_WIDTH-1:0] AXI_slave_read_data; 
    wire [AXI_ADDR_WIDTH-1:0] AXI_slave_r_opt_addr; 
    wire  AXI_slave_read_req;
    reg  AXI_slave_read_valid;

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
		.awid           (awid    ),
		.awaddr         (awaddr),
		.awlen          (awlen   ),
		.awsize         (awsize  ),
		.awburst        (awburst ),
		.awlock         (awlock  ),
		.awcache        (awcache ),
		.awprot         (awprot  ),
		.awqos          (awqos   ),
		.awregion       (awregion),
		.awuser         (awuser  ),
		.awvalid        (awvalid ),
		.awready        (awready ),
		.wdata          (wdata    ),
		.wstrb          (wstrb    ),
		.wlast          (wlast    ),
		.wuser          (wuser    ),
		.wvalid	        (wvalid   ),
		.wready	        (wready   ),
		.bid		    (bid	    ),
		.bresp		    (bresp	),
		.buser		    (buser	),
		.bvalid	        (bvalid   ),
		.bready	        (bready   ),
		.arid		    (arid	    ),
		.araddr	        (araddr   ),
		.arlen		    (arlen	),
		.arsize	        (arsize   ),
		.arburst	    (arburst  ),
		.arlock	        (arlock   ),
		.arcache	    (arcache  ),
		.arprot	        (arprot   ),
		.arqos		    (arqos	),
		.arregion	    (arregion ),
		.aruser	        (aruser   ),
		.arvalid	    (arvalid  ),
		.arready	    (arready  ),
		.rid		    (rid	    ),
		.rdata		    (rdata	),
		.rresp		    (rresp	),
		.rlast		    (rlast	),
		.ruser		    (ruser	),
		.rvalid	        (rvalid   ),
		.rready	        (rready   ),
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
assign data_req_o = AXI_slave_write_valid || AXI_slave_read_req;

//add_o
always @(*) begin
    if (AXI_slave_write_valid == 1) begin
        data_add_o = AXI_slave_w_opt_addr;
    end
    else if (AXI_slave_read_req) begin
        data_add_o = AXI_slave_r_opt_addr;
    end
    else begin
        data_add_o = 0;
    end
end

assign data_wen_o = AXI_slave_write_valid;
assign data_wdata_o = AXI_slave_write_data;
assign data_be_o = AXI_slave_write_strb;
assign AXI_slave_read_data[AXI_DATA_WIDTH-1:0] = data_r_rdata_i[AXI_DATA_WIDTH-1:0];
assign AXI_slave_read_valid = data_r_valid_i;



endmodule
