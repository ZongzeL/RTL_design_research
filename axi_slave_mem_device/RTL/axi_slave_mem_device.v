/*
    这个东西本质上不是AXI slave，是一个带AXI slave的device。AXI slave模块把收到的合法的addr range里的ar/aw传过来，不负责翻译。那么翻译的过程就应该在这里。
    


*/

`timescale 1 ns / 1 ps

	module axi_slave_mem_device #
    (
		parameter integer AXI_ID_WIDTH	= 1,
		parameter integer AXI_DATA_WIDTH	= 32,
        parameter integer AXI_STRB_WIDTH        = AXI_DATA_WIDTH/8,

		parameter integer AXI_ADDR_WIDTH	= 32, //ARES addr 一定要设成32bit！
        parameter integer AXI_USER_WIDTH        = 10,

        parameter integer DATA_MEM_LENGTH       = 64,
        parameter integer OPT_MEM_ADDR_BITS     = $clog2(DATA_MEM_LENGTH),
	    parameter integer ADDR_LSB = $clog2(AXI_DATA_WIDTH/8), //2
        parameter integer ADDR_BASE_OFFSET = 0,
	    parameter integer ADDR_ST  = 'h0 + ADDR_BASE_OFFSET,
	    parameter integer ADDR_END  = 'h400 + ADDR_BASE_OFFSET
    )
	(
        input wire  clk,
		input wire  rst_n,

        //`include "AXI_IO_define.svh"
        //{{{
        input wire [AXI_ID_WIDTH-1:0]    AXI_slave_awid,
        input wire [AXI_ADDR_WIDTH-1:0]  AXI_slave_awaddr,
        input wire [7:0]                 AXI_slave_awlen,
        input wire [2:0]                 AXI_slave_awsize,
        input wire [1:0]                 AXI_slave_awburst,
        input wire                       AXI_slave_awlock,
        input wire [3:0]                 AXI_slave_awcache,
        input wire [2:0]                 AXI_slave_awprot,
        input wire [3:0]                 AXI_slave_awqos,
        input wire [3:0]                 AXI_slave_awregion,
        input wire [AXI_USER_WIDTH-1:0]  AXI_slave_awuser,
        input wire                       AXI_slave_awvalid,
        output wire                      AXI_slave_awready,

        input wire [AXI_DATA_WIDTH-1:0]  AXI_slave_wdata,
        input wire [AXI_STRB_WIDTH-1:0]  AXI_slave_wstrb,
        input wire                       AXI_slave_wlast,
        input wire [AXI_USER_WIDTH-1:0]  AXI_slave_wuser,
        input wire                       AXI_slave_wvalid,
        output wire                      AXI_slave_wready,
        input wire [AXI_ID_WIDTH-1:0]    AXI_slave_wid,
        
        output wire [AXI_ID_WIDTH-1:0]   AXI_slave_bid,
        output wire [1:0]                AXI_slave_bresp,
        output wire [AXI_USER_WIDTH-1:0] AXI_slave_buser,
        output wire                      AXI_slave_bvalid,
        input wire                       AXI_slave_bready,

        input wire [AXI_ID_WIDTH-1:0]    AXI_slave_arid,
        input wire [AXI_ADDR_WIDTH-1:0]  AXI_slave_araddr,
        input wire [7:0]                 AXI_slave_arlen,
        input wire [2:0]                 AXI_slave_arsize,
        input wire [1:0]                 AXI_slave_arburst,
        input wire                       AXI_slave_arlock,
        input wire [3:0]                 AXI_slave_arcache,
        input wire [2:0]                 AXI_slave_arprot,
        input wire [3:0]                 AXI_slave_arqos,
        input wire [3:0]                 AXI_slave_arregion,
        input wire [AXI_USER_WIDTH-1:0]  AXI_slave_aruser,
        input wire                       AXI_slave_arvalid,
        output wire                      AXI_slave_arready,


        output wire [AXI_ID_WIDTH-1:0]   AXI_slave_rid,
        output wire [AXI_DATA_WIDTH-1:0] AXI_slave_rdata,
        output wire [1:0]                AXI_slave_rresp,
        output wire                      AXI_slave_rlast,
        output wire [AXI_USER_WIDTH-1:0] AXI_slave_ruser,
        output wire                      AXI_slave_rvalid,
        input wire                       AXI_slave_rready 

        //}}}
	);

    localparam integer ADDR_INPUT_ST    = ADDR_BASE_OFFSET >> ADDR_LSB;	
    localparam integer ADDR_INPUT_END   = (ADDR_BASE_OFFSET + 'h100) >> ADDR_LSB;	
    
    reg [AXI_DATA_WIDTH-1:0] in_data[0 : DATA_MEM_LENGTH - 1];
   
    wire [AXI_DATA_WIDTH-1:0] AXI_slave_write_data; 
    wire [3:0]                AXI_slave_write_strb; 
    wire [AXI_ADDR_WIDTH-1:0] AXI_slave_w_opt_addr; 
    wire AXI_slave_write_valid; 

    reg  [AXI_DATA_WIDTH-1:0] AXI_slave_read_data; 
    wire [AXI_ADDR_WIDTH-1:0] AXI_slave_r_opt_addr; 
    wire  AXI_slave_ar_flag;
    reg  AXI_slave_read_valid;


    //Instantiation of AXI_slave_module 
    //{{{
    pure_AXI_slave_design #(
		.AXI_ID_WIDTH	        (AXI_ID_WIDTH	     ), 
		.AXI_DATA_WIDTH	        (AXI_DATA_WIDTH	     ), 
		.AXI_ADDR_WIDTH	        (AXI_ADDR_WIDTH	     ), 
        .ADDR_BASE_OFFSET       (ADDR_BASE_OFFSET),
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
        .ar_flag  (AXI_slave_ar_flag),
        .read_valid(AXI_slave_read_valid),
        
        .aw_ar_ready            (1), //slave mem, always ready to receive new instr

        .clk                    (clk),
		.rst_n                  (rst_n)
        
    ); 
    //}}}

//read_data
//组合逻辑，这个是最安全的。
//{{{
always @(AXI_slave_r_opt_addr or rst_n or AXI_slave_ar_flag) begin
    if ( rst_n == 1'b0 ) begin
        AXI_slave_read_data = 0;
        AXI_slave_read_valid = 0;
    end
    else begin
        if (AXI_slave_ar_flag == 1) begin
            if (AXI_slave_w_opt_addr >= ADDR_INPUT_ST &&
                AXI_slave_w_opt_addr < ADDR_INPUT_END
            ) begin
                AXI_slave_read_data = in_data[AXI_slave_r_opt_addr - ADDR_INPUT_ST];
            end
            AXI_slave_read_valid = 1;
        end
        else begin
            AXI_slave_read_valid = 0;
        end
    end
end
//}}}

/*
//时序逻辑，
//{{{
always @(posedge clk) begin
    if ( rst_n == 1'b0 ) begin
        AXI_slave_read_data <= 0;
        AXI_slave_read_valid <= 0;
    end
    else begin
        if (AXI_slave_ar_flag == 1) begin
            if (AXI_slave_w_opt_addr >= ADDR_INPUT_ST &&
                AXI_slave_w_opt_addr < ADDR_INPUT_END
            ) begin
                AXI_slave_read_data <= in_data[AXI_slave_r_opt_addr - ADDR_INPUT_ST];
            end
            AXI_slave_read_valid <= 1;
        end
        else begin
            AXI_slave_read_valid <= 0;
        end
    end
end
//}}}
*/

//in_data
//{{{
always @( posedge clk ) begin
    if ( rst_n == 1'b0 ) begin
        for (integer i = 0; i < DATA_MEM_LENGTH; i = i + 1) begin
            in_data[i] <= 0;
        end
    end
    else begin
        if (AXI_slave_write_valid == 1) begin
            if (AXI_slave_w_opt_addr >= ADDR_INPUT_ST &&
                AXI_slave_w_opt_addr < ADDR_INPUT_END
            ) begin
                in_data[AXI_slave_w_opt_addr - ADDR_INPUT_ST] <= AXI_slave_write_data;
            end
        end
    end
end
//}}}


endmodule
