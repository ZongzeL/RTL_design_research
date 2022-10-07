/*
    top 有一个slave， 一个master。
    注意，我这个东西不是DMA模块，不是为了在两个slave之中通信，而是要从top和slave通信。dma模块自己不带直接写操作，我的top是可以直接写的。外面那个slave mem是为了给我辅助用的，模仿xilinx的，或者任何的axi的memory
    slave用来接收写数据，config和读数据。
    master用来挂一个slave mem外设。master有一个0x400的offset。因为slave mem也要有这个0x400的offset
    一开始没必要写的那么细，默认一次写4byte

    写操作：
        src_addr top自己的input buffer，
        dst_addr master的memory。
        这里就有了一个尚未有定论的问题，有两种解决方案：
        1. slave mem 有这个offset，对应的master也有，那么对master的所有操作都要有这个offset
            master会发一个带0x400的aw，这个是必须的也是正确的，因为slave mem也是有这个offset的，假如master不发带offset的aw，slave mem是不接受的。

            那么master_w_opt_addr也就带这个0x400的offset了。
            这里就有两个需要做的事：
            1) slave mem端必须把这个offset挡住。
            2) top 端也要挡住。
        2. 可以让slave mem没有这个 offset, 那么master虽然有这个offset，但必须在master发master_w_opt_addr的时候把这个offset给挡住，这样top和slave mem的访问地址就都是从0开始了。


        我现在认为第一种更好一点，暂时不确定，视未来情况而定。
        不管用哪种方案，top这边的in_data[master_w_opt_addr]写出值的时候必须要有一个换算，就是master_w_opt_addr (-offset) - dst + src
        master_w_opt_addr (- offset) (如果用1方案) 不解释
        -dst + src的意思就是：
        举个例子，我要把top in_data[1] 开始的15个值写到slave mem的 从[3]开始的15个值里面去。
        那么首先，src = 0x0 + 1* 4 = 4; dst = 400 + 3 * 4 = 0x40c.
        master_w_opt_addr 会从0x40c/4开始（0x103）数15个，我要想让它读到in_data的[1]，那就要用这个0x103- dst<<2(0x40c << 2) + (src << 2).   
        那么既然必定要-dst<<2，那还是用方案1更好，因为dst本身已经带了那个offset了。
        注意，这里说的一切都只针对这个top design，master只负责产生一个干净的，带offset的master_w_opt_addr,具体怎么用视top design情况而定。这个top未来说不好该怎么用。
        master_w_opt_addr - dst<<2 其实就是获得一个当前的计数器i
    



*/

`timescale 1 ns / 1 ps

	module TOP_device #
    (
		parameter integer AXI_ID_WIDTH	= 1,
		parameter integer AXI_DATA_WIDTH	= 32,
        parameter integer AXI_STRB_WIDTH        = AXI_DATA_WIDTH/8,

		parameter integer AXI_ADDR_WIDTH	= 32, //ARES addr 一定要设成32bit！
        parameter integer AXI_USER_WIDTH        = 10,

        parameter integer DATA_MEM_LENGTH       = 32,
        parameter integer OPT_MEM_ADDR_BITS     = $clog2(DATA_MEM_LENGTH),
	    parameter integer ADDR_LSB = $clog2(AXI_DATA_WIDTH/8), //2
        parameter integer ADDR_BASE_OFFSET = 0,
	    parameter integer ADDR_ST  = 'h0 + ADDR_BASE_OFFSET,
	    parameter integer ADDR_END  = 'h400 + ADDR_BASE_OFFSET,

        
        parameter integer ADDR_MASTER_OFFSET = 0

    )
	(

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
        input wire                       AXI_slave_rready, 

        //}}}
       
        //master 
        //{{{
        output [AXI_ID_WIDTH-1:0]   AXI_master_awid,
        output [AXI_ADDR_WIDTH-1:0] AXI_master_awaddr,
        output [7:0]                AXI_master_awlen,
        output [2:0]                AXI_master_awsize,
        output [1:0]                AXI_master_awburst,
        output                      AXI_master_awlock,
        output [3:0]                AXI_master_awcache,
        output [2:0]                AXI_master_awprot,
        output [3:0]                AXI_master_awqos,
        output [3:0]                AXI_master_awregion,
        output [AXI_USER_WIDTH-1:0] AXI_master_awuser,
        output                      AXI_master_awvalid,
        input                       AXI_master_awready,

        output [AXI_DATA_WIDTH-1:0] AXI_master_wdata,
        output [AXI_STRB_WIDTH-1:0] AXI_master_wstrb,
        output                      AXI_master_wlast,
        output [AXI_USER_WIDTH-1:0] AXI_master_wuser,
        output                      AXI_master_wvalid,
        input                       AXI_master_wready,
        output [AXI_ID_WIDTH-1:0]   AXI_master_wid,
        
        input [AXI_ID_WIDTH-1:0]    AXI_master_bid,
        input [1:0]                 AXI_master_bresp,
        input [AXI_USER_WIDTH-1:0]  AXI_master_buser,
        input                       AXI_master_bvalid,
        output                      AXI_master_bready,

        output [AXI_ID_WIDTH-1:0]   AXI_master_arid,
        output [AXI_ADDR_WIDTH-1:0] AXI_master_araddr,
        output [7:0]                AXI_master_arlen,
        output [2:0]                AXI_master_arsize,
        output [1:0]                AXI_master_arburst,
        output                      AXI_master_arlock,
        output [3:0]                AXI_master_arcache,
        output [2:0]                AXI_master_arprot,
        output [3:0]                AXI_master_arqos,
        output [3:0]                AXI_master_arregion,
        output [AXI_USER_WIDTH-1:0] AXI_master_aruser,
        output                      AXI_master_arvalid,
        input                       AXI_master_arready,


        input [AXI_ID_WIDTH-1:0]   AXI_master_rid,
        input [AXI_DATA_WIDTH-1:0] AXI_master_rdata,
        input [1:0]                AXI_master_rresp,
        input                      AXI_master_rlast,
        input [AXI_USER_WIDTH-1:0] AXI_master_ruser,
        input                      AXI_master_rvalid,
        output                     AXI_master_rready,

        //}}}
        input wire  clk,
		input wire  rst_n
        
	);
    
    localparam integer ADDR_INPUT_ST    = 0 >> ADDR_LSB;	
    localparam integer ADDR_INPUT_END   = 'h100 >> ADDR_LSB;	
    localparam integer ADDR_CONFIG_ST   = 'h100 >> ADDR_LSB;	
    localparam integer ADDR_CONFIG_END  = 'h200 >> ADDR_LSB;	
    localparam integer ADDR_OUTPUT_ST   = 'h200 >> ADDR_LSB;	
    localparam integer ADDR_OUTPUT_END  = 'h300 >> ADDR_LSB;	
    localparam integer SLAVE_MEM_OFFSET  = 'h400;	

    localparam integer IDLE = 0;
    localparam integer DRIVE_MASTER_AW = 1;
    localparam integer RUN_AW = 2;
    localparam integer RUN_W = 3;
    localparam integer DRIVE_MASTER_AR = 4;
    localparam integer RUN_AR = 5;
    localparam integer RUN_R = 6;

    integer i;

    reg [3:0] CS;
    reg [3:0] CS_w;

    reg [AXI_DATA_WIDTH-1:0] in_data[0 : DATA_MEM_LENGTH - 1];
    reg [AXI_DATA_WIDTH-1:0] config_data[0 : DATA_MEM_LENGTH - 1];
    reg [AXI_DATA_WIDTH-1:0] out_data[0 : DATA_MEM_LENGTH - 1];
   
    //slave_signals
    //{{{
    wire [AXI_DATA_WIDTH-1:0] AXI_slave_write_data; 
    wire [3:0]                AXI_slave_write_strb; 
    wire [AXI_ADDR_WIDTH-1:0] AXI_slave_w_opt_addr; 
    wire AXI_slave_write_valid; 

    reg  [AXI_DATA_WIDTH-1:0] AXI_slave_read_data; 
    wire [AXI_ADDR_WIDTH-1:0] AXI_slave_r_opt_addr; 
    wire  AXI_slave_ar_flag;
    reg  AXI_slave_read_valid;
    //}}}

    //master signals
    //{{{
    reg [AXI_ADDR_WIDTH-1:0] master_instr_awaddr;
    reg [7:0]                master_instr_awlen;
    reg [1:0]                master_instr_awburst;
    reg master_instr_aw_valid;
    wire master_aw_flag;
    wire [AXI_ADDR_WIDTH-1:0] master_w_opt_addr;
    reg [AXI_DATA_WIDTH-1:0] master_write_data;
    reg master_write_valid;
    
    reg [AXI_ADDR_WIDTH-1:0] master_instr_araddr;
    reg [7:0]                master_instr_arlen;
    reg [1:0]                master_instr_arburst;
    reg master_instr_ar_valid;
    wire master_ar_flag;
    wire [AXI_ADDR_WIDTH-1:0] master_r_opt_addr;
    wire [AXI_DATA_WIDTH-1:0] master_read_data;
    wire master_read_valid;
    //}}}

    //config signals
    //{{{
    wire [1:0] mode;
    wire [1:0] mode_burst;
    wire [31:0] src_addr; 
    wire[31:0] dst_addr; 
    wire [7:0] len; 

    assign mode = config_data[0][1:0];
    assign mode_burst = config_data[0][3:2];
    assign len      = config_data[0][31:24];
    assign src_addr = config_data[1][31:0];
    assign dst_addr = config_data[2][31:0];
    //}}}

    //Instantiation of AXI_slave_module 
    //{{{
    pure_AXI_slave_design #(
		.AXI_ID_WIDTH	        (AXI_ID_WIDTH	     ), 
		.AXI_DATA_WIDTH	        (AXI_DATA_WIDTH	     ), 
		.AXI_ADDR_WIDTH	        (AXI_ADDR_WIDTH	     ),
        .ADDR_BASE_OFFSET       (ADDR_BASE_OFFSET)
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

        .aw_ar_ready (CS == IDLE),

        .clk                    (clk),
		.rst_n                  (rst_n)
        
    ); 
    //}}}
    
    //Instantiation of AXI_master_module 
    //{{{
    pure_AXI_master_design #(
		.AXI_ID_WIDTH	        (AXI_ID_WIDTH	     ), 
		.AXI_DATA_WIDTH	        (AXI_DATA_WIDTH	     ), 
		.AXI_ADDR_WIDTH	        (AXI_ADDR_WIDTH	     ), 
        .ADDR_BASE_OFFSET       (ADDR_MASTER_OFFSET  )

    ) AXI_MASTER (
        //axi full data
        //{{{
		.awid           (AXI_master_awid    ),
		.awaddr         (AXI_master_awaddr),
		.awlen          (AXI_master_awlen   ),
		.awsize         (AXI_master_awsize  ),
		.awburst        (AXI_master_awburst ),
		.awlock         (AXI_master_awlock  ),
		.awcache        (AXI_master_awcache ),
		.awprot         (AXI_master_awprot  ),
		.awqos          (AXI_master_awqos   ),
		.awregion       (AXI_master_awregion),
		.awuser         (AXI_master_awuser  ),
		.awvalid        (AXI_master_awvalid ),
		.awready        (AXI_master_awready ),
		.wdata          (AXI_master_wdata    ),
		.wstrb          (AXI_master_wstrb    ),
		.wlast          (AXI_master_wlast    ),
		.wuser          (AXI_master_wuser    ),
		.wvalid	        (AXI_master_wvalid   ),
		.wready	        (AXI_master_wready   ),
		.bid		    (AXI_master_bid	    ),
		.bresp		    (AXI_master_bresp	),
		.buser		    (AXI_master_buser	),
		.bvalid	        (AXI_master_bvalid   ),
		.bready	        (AXI_master_bready   ),
		.arid		    (AXI_master_arid	    ),
		.araddr	        (AXI_master_araddr   ),
		.arlen		    (AXI_master_arlen	),
		.arsize	        (AXI_master_arsize   ),
		.arburst	    (AXI_master_arburst  ),
		.arlock	        (AXI_master_arlock   ),
		.arcache	    (AXI_master_arcache  ),
		.arprot	        (AXI_master_arprot   ),
		.arqos		    (AXI_master_arqos	),
		.arregion	    (AXI_master_arregion ),
		.aruser	        (AXI_master_aruser   ),
		.arvalid	    (AXI_master_arvalid  ),
		.arready	    (AXI_master_arready  ),
		.rid		    (AXI_master_rid	    ),
		.rdata		    (AXI_master_rdata	),
		.rresp		    (AXI_master_rresp	),
		.rlast		    (AXI_master_rlast	),
		.ruser		    (AXI_master_ruser	),
		.rvalid	        (AXI_master_rvalid   ),
		.rready	        (AXI_master_rready   ),
        //}}}
        
        .master_instr_awaddr   (master_instr_awaddr),
        .master_instr_awlen    (master_instr_awlen),
        .master_instr_awburst  (master_instr_awburst),
        .master_instr_aw_valid (master_instr_aw_valid),
       
        .aw_flag               (master_aw_flag),
        .w_opt_addr            (master_w_opt_addr),
        .write_data            (master_write_data),
        .write_valid           (master_write_valid),
        
        .master_instr_araddr   (master_instr_araddr),
        .master_instr_arlen    (master_instr_arlen),
        .master_instr_arburst  (master_instr_arburst),
        .master_instr_ar_valid (master_instr_ar_valid),
       
        .ar_flag               (master_ar_flag),
        .r_opt_addr            (master_r_opt_addr),
        .read_data             (master_read_data),
        .read_valid            (master_read_valid),
        
        .clk                   (clk),
		.rst_n                 (rst_n)
    );
    //}}}

//read_data
//组合逻辑写法，slave module里面要用时序逻辑控制addr
//{{{
always @(AXI_slave_r_opt_addr or rst_n or AXI_slave_ar_flag) begin
    if ( rst_n == 1'b0 ) begin
        AXI_slave_read_data = 0;
        AXI_slave_read_valid = 0;
    end
    else begin
        if (AXI_slave_ar_flag == 1) begin
            if (AXI_slave_r_opt_addr >= ADDR_INPUT_ST &&
                AXI_slave_r_opt_addr < ADDR_INPUT_END
            ) begin
                AXI_slave_read_data = in_data[AXI_slave_r_opt_addr - ADDR_INPUT_ST];
            end
            if (AXI_slave_r_opt_addr >= ADDR_CONFIG_ST &&
                AXI_slave_r_opt_addr < ADDR_CONFIG_END
            ) begin
                AXI_slave_read_data = config_data[AXI_slave_r_opt_addr - ADDR_CONFIG_ST];
            end
            if (AXI_slave_r_opt_addr >= ADDR_OUTPUT_ST &&
                AXI_slave_r_opt_addr < ADDR_OUTPUT_END
            ) begin
                AXI_slave_read_data = out_data[AXI_slave_r_opt_addr - ADDR_OUTPUT_ST];
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
//时序逻辑写法，slave module里面要用组合逻辑控制addr
//{{{
always @(posedge clk) begin
    if ( rst_n == 1'b0 ) begin
        AXI_slave_read_data <= 0;
        AXI_slave_read_valid = 0;
    end
    else begin
        if (AXI_slave_ar_flag == 1) begin
            if (AXI_slave_r_opt_addr >= ADDR_INPUT_ST &&
                AXI_slave_r_opt_addr < ADDR_INPUT_END
            ) begin
                AXI_slave_read_data <= in_data[AXI_slave_r_opt_addr - ADDR_INPUT_ST];
            end
            if (AXI_slave_r_opt_addr >= ADDR_CONFIG_ST &&
                AXI_slave_r_opt_addr < ADDR_CONFIG_END
            ) begin
                AXI_slave_read_data <= config_data[AXI_slave_r_opt_addr - ADDR_CONFIG_ST];
            end
            if (AXI_slave_r_opt_addr >= ADDR_OUTPUT_ST &&
                AXI_slave_r_opt_addr < ADDR_OUTPUT_END
            ) begin
                AXI_slave_read_data <= out_data[AXI_slave_r_opt_addr - ADDR_OUTPUT_ST];
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
        for (i = 0; i < DATA_MEM_LENGTH; i = i + 1) begin
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

//config_data
//{{{
always @( posedge clk ) begin
    if ( rst_n == 1'b0 ) begin
        for (i = 0; i < DATA_MEM_LENGTH; i = i + 1) begin
            config_data[i] <= 0;
        end
    end
    else begin
        if (AXI_slave_write_valid == 1) begin
            if (AXI_slave_w_opt_addr >= ADDR_CONFIG_ST &&
                AXI_slave_w_opt_addr < ADDR_CONFIG_END
            ) begin
                config_data[AXI_slave_w_opt_addr - ADDR_CONFIG_ST] <= AXI_slave_write_data;
            end
        end
        if (CS != IDLE) begin
            config_data[0][1:0] <= 2'b0; //reset mode
        end
    end
end
//}}}

//state_machine
//{{{
always @(posedge clk) begin
    CS <= CS_w;
end

always @(*) begin
    if ( rst_n == 1'b0 ) begin
        CS_w = IDLE;
    end
    else begin
        case (CS) 
            IDLE: begin
                if (mode == 2'b01) begin
                    CS_w = DRIVE_MASTER_AW;
                end
                else if (mode == 2'b10) begin
                    CS_w = DRIVE_MASTER_AR;
                end
                else begin
                    CS_w = IDLE;
                end
            end
            
            DRIVE_MASTER_AW: begin
                if (master_instr_aw_valid == 1) begin
                    CS_w = RUN_AW;
                end
                else begin
                    CS_w = DRIVE_MASTER_AW;
                end
            end
            
            RUN_AW: begin
                if (master_aw_flag == 0) begin
                    CS_w = RUN_AW;
                end
                else begin
                    CS_w = RUN_W;
                end
            end

            RUN_W: begin
                if (master_aw_flag == 1) begin
                    CS_w = RUN_W;
                end
                else begin
                    CS_w = IDLE;
                end
            end
            
            DRIVE_MASTER_AR: begin
                if (master_instr_ar_valid == 1) begin
                    CS_w = RUN_AR;
                end
                else begin
                    CS_w = DRIVE_MASTER_AR;
                end
            end
                
            RUN_AR: begin
                if (master_ar_flag == 0) begin
                    CS_w = RUN_AR;
                end
                else begin
                    CS_w = RUN_R;
                end
            end

            RUN_R: begin
                if (master_ar_flag == 1) begin
                    CS_w = RUN_R;
                end
                else begin
                    CS_w = IDLE;
                end
            end
     
            default: begin
                CS_w = IDLE;
            end
        endcase
    end 
end
//}}}

//master aw
//{{{
always @(posedge clk) begin
    if ( rst_n == 1'b0 ) begin
        master_instr_awaddr <= 0;
        master_instr_awlen <= 0;
        master_instr_awburst <= 0;
        master_instr_aw_valid <= 0;
    end
    else begin
        if (CS == DRIVE_MASTER_AW) begin
            master_instr_awaddr <= dst_addr;
            master_instr_awlen <= len;
            master_instr_awburst <= mode_burst;
            master_instr_aw_valid <= 1;
        end
        else if (CS == RUN_AW) begin
            //use only CS == RUN_AW to reset master_instr_aw_valid, because only CS == DRIVE_MASTER_AW can make it rise. and DRIVE_MASTER_AW's next state is RUN_AW.
            master_instr_aw_valid <= 0;
        end
    end 
end
//}}}

//master w
//{{{
always @(*) begin
    master_write_data = in_data[master_w_opt_addr - (dst_addr >> 2) + (src_addr >> 2)];
    master_write_valid = master_aw_flag;
end
//}}}

//master ar
//{{{
always @(posedge clk) begin
    if ( rst_n == 1'b0 ) begin
        master_instr_araddr <= 0;
        master_instr_arlen <= 0;
        master_instr_arburst <= 0;
        master_instr_ar_valid <= 0;
    end
    else begin
        if (CS == DRIVE_MASTER_AR) begin
            master_instr_araddr <= src_addr;
            master_instr_arlen <= len;
            master_instr_arburst <= mode_burst;
            master_instr_ar_valid <= 1;
        end
        else if (CS == RUN_AR) begin
            master_instr_ar_valid <= 0;
        end
    end 
end
//}}}

//master r
//{{{
always @(posedge clk) begin
    if ( rst_n == 1'b0 ) begin
        for (i = 0; i < DATA_MEM_LENGTH; i = i + 1) begin
            out_data[i] = 0;
        end
    end
    else begin
        if (
            master_read_valid == 1 &&
            (dst_addr >> 2) >= ADDR_OUTPUT_ST &&
            (dst_addr >> 2) <  ADDR_OUTPUT_END
            ) begin
            out_data[master_r_opt_addr - (src_addr >> 2) + ((dst_addr >> 2) - ADDR_OUTPUT_ST)] = master_read_data;
        end
    end
end
//}}}

endmodule
