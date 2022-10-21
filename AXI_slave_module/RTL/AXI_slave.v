/*
不管master还是slave，他们的任务就是把外面发来的读写指令（addr, len, strb，burst）翻译成自己内部对应的那种指令，他们只负责拦截不属于自己的指令，不负责翻译。
作为slave，所谓的拦截就是外面给它起了一个非法的aw/ar，它根本不相应。那么如何阻止外面发非法的aw/ar，或者外面已经发了，如何停止，那是外面的事。
slave接了那个aw/ar，就要忠实的翻译成对应的r/w_opt_addr，至于top怎么用那是top的事。


*/

`timescale 1 ns / 1 ps

	module pure_AXI_slave_design #
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

	    parameter integer ADDR_ST  = 'h0 + ADDR_BASE_OFFSET,
	    parameter integer ADDR_END  = 'h400 + ADDR_BASE_OFFSET
    )
	(

        //`include "AXI_IO_define.svh"
        //{{{
        input  wire [AXI_ID_WIDTH-1:0]   awid,
        input  wire [AXI_ADDR_WIDTH-1:0] awaddr,
        input  wire [7:0]                awlen,
        input  wire [2:0]                awsize,
        input  wire [1:0]                awburst,
        input  wire                      awlock,
        input  wire [3:0]                awcache,
        input  wire [2:0]                awprot,
        input  wire [3:0]                awqos,
        input  wire [3:0]                awregion,
        input  wire [AXI_USER_WIDTH-1:0] awuser,
        input  wire                      awvalid,
        output wire                      awready,

        input  wire [AXI_DATA_WIDTH-1:0] wdata,
        input  wire [AXI_STRB_WIDTH-1:0] wstrb,
        input  wire                      wlast,
        input  wire [AXI_USER_WIDTH-1:0] wuser,
        input  wire                      wvalid,
        output wire                      wready,
        input  wire [AXI_ID_WIDTH-1:0]   wid,
        
        output wire [AXI_ID_WIDTH-1:0]   bid,
        output wire [1:0]                bresp,
        output wire [AXI_USER_WIDTH-1:0] buser,
        output wire                      bvalid,
        input  wire                      bready,

        input  wire [AXI_ID_WIDTH-1:0]   arid,
        input  wire [AXI_ADDR_WIDTH-1:0] araddr,
        input  wire [7:0]                arlen,
        input  wire [2:0]                arsize,
        input  wire [1:0]                arburst,
        input  wire                      arlock,
        input  wire [3:0]                arcache,
        input  wire [2:0]                arprot,
        input  wire [3:0]                arqos,
        input  wire [3:0]                arregion,
        input  wire [AXI_USER_WIDTH-1:0] aruser,
        input  wire                      arvalid,
        output wire                      arready,


        output wire  [AXI_ID_WIDTH-1:0]   rid,
        output wire  [AXI_DATA_WIDTH-1:0] rdata,
        output wire  [1:0]                rresp,
        output wire                       rlast,
        output wire  [AXI_USER_WIDTH-1:0] ruser,
        output wire                       rvalid,
        input  wire                       rready,

        //}}}
       
        //eight useful signals
        output wire [AXI_DATA_WIDTH - 1 : 0]   write_data,
        output wire [3 : 0]                    write_strb,
        output wire [AXI_ADDR_WIDTH - 1 : 0]   w_opt_addr,
        output wire write_valid,
 
        output wire [AXI_ADDR_WIDTH - 1 : 0]   r_opt_addr,
        output wire read_req,
        input  wire [AXI_DATA_WIDTH - 1 : 0]   read_data,
	    input  wire read_valid, 

        input aw_ar_ready,


 
        input wire  clk,
		input wire  rst_n
	);


 


    //Instantiation of AXI_slave_AW_module 
    //{{{
    pure_AXI_slave_AW_module #(
		.AXI_ID_WIDTH	        (AXI_ID_WIDTH	     ), 
		.AXI_DATA_WIDTH	        (AXI_DATA_WIDTH	     ), 
		.AXI_ADDR_WIDTH	        (AXI_ADDR_WIDTH	     ), 
        .ADDR_BASE_OFFSET       (ADDR_BASE_OFFSET),
        .ADDR_ST                (ADDR_ST),
        .ADDR_END               (ADDR_END)

    ) AXI_SLAVE_AW (
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
        //}}}
		
        //eight useful signals
        .write_data     (write_data),
        .write_strb     (write_strb),
        .w_opt_addr     (w_opt_addr),
        .write_valid    (write_valid),

        .aw_ar_ready    (aw_ar_ready),

        .clk                    (clk),
		.rst_n                  (rst_n)
        
    ); 
    //}}}
	
    //Instantiation of AXI_slave_AR_module 
    //{{{
    pure_AXI_slave_AR_module #(
		.AXI_ID_WIDTH	        (AXI_ID_WIDTH	     ), 
		.AXI_DATA_WIDTH	        (AXI_DATA_WIDTH	     ), 
		.AXI_ADDR_WIDTH	        (AXI_ADDR_WIDTH	     ), 
        .ADDR_BASE_OFFSET       (ADDR_BASE_OFFSET),
        .ADDR_ST                (ADDR_ST),
        .ADDR_END               (ADDR_END)

    ) AXI_SLAVE_AR (
        //axi full data
        //{{{
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
		
        .read_data  (read_data),
        .r_opt_addr (r_opt_addr),
        .read_req   (read_req),
        .read_valid (read_valid),
        
        .aw_ar_ready            (aw_ar_ready),

        .clk                    (clk),
		.rst_n                  (rst_n)
        
    ); 
    //}}}








endmodule





