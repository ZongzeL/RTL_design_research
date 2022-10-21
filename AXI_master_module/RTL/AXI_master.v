/*

不管master还是slave，他们的任务就是把外面发来的读写指令（addr, len, strb，burst）翻译成自己内部对应的那种指令，他们只负责拦截不属于自己的指令，不负责翻译。
作为master，它的拦截方式要特殊一些，就是外面先发了一个master模块用的指令，然后这个指令如果不是在master规定的范围内则master根本不理它（have_valid_aw/ar_instr），至于外面为什么会发不属于master地址范围的指令就是外面要控制的了。


    AW:
    outside instr:
        master_instr_awaddr
        master_instr_awlen
        master_instr_awburst
        master_instr_aw_valid

        use have_valid_aw_instr to buffer the master_instr_aw_valid 
        corresponding internal counter:
	        instr_awlen;
	        instr_awlen_cntr;
	        instr_awburst;
	        instr_awlen;
           
    W:
    outside signals:
        aw_flag
        w_opt_addr
        write_data
        write_valid

        use aw_flag indicate if running W, until B finishes aw_flag will fall, the outside is ready to send new instr. 
        write data/write_valid must be mapping same. w_opt_addr could be used as a reference, data and valid do not need to rise the same time as w_opt_addr. 
    



*/


`timescale 1 ns / 1 ps

	module pure_AXI_master_design #
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
        parameter integer SIZE = $clog2(AXI_DATA_WIDTH / 8), //2

	    parameter integer ADDR_ST  = 'h0 + ADDR_BASE_OFFSET,
	    parameter integer ADDR_END  = 'h400 + ADDR_BASE_OFFSET
    )
	(

        //`include "AXI_IO_define.svh"
        //{{{
        output [AXI_ID_WIDTH-1:0]   awid,
        output [AXI_ADDR_WIDTH-1:0] awaddr,
        output [7:0]                awlen,
        output [2:0]                awsize,
        output [1:0]                awburst,
        output                      awlock,
        output [3:0]                awcache,
        output [2:0]                awprot,
        output [3:0]                awqos,
        output [3:0]                awregion,
        output [AXI_USER_WIDTH-1:0] awuser,
        output                      awvalid,
        input                       awready,

        output [AXI_DATA_WIDTH-1:0] wdata,
        output [AXI_STRB_WIDTH-1:0] wstrb,
        output                      wlast,
        output [AXI_USER_WIDTH-1:0] wuser,
        output                      wvalid,
        input                       wready,
        output [AXI_ID_WIDTH-1:0]   wid,
        
        input [AXI_ID_WIDTH-1:0]    bid,
        input [1:0]                 bresp,
        input [AXI_USER_WIDTH-1:0]  buser,
        input                       bvalid,
        output                      bready,

        output [AXI_ID_WIDTH-1:0]   arid,
        output [AXI_ADDR_WIDTH-1:0] araddr,
        output [7:0]                arlen,
        output [2:0]                arsize,
        output [1:0]                arburst,
        output                      arlock,
        output [3:0]                arcache,
        output [2:0]                arprot,
        output [3:0]                arqos,
        output [3:0]                arregion,
        output [AXI_USER_WIDTH-1:0] aruser,
        output                      arvalid,
        input                       arready,


        input [AXI_ID_WIDTH-1:0]   rid,
        input [AXI_DATA_WIDTH-1:0] rdata,
        input [1:0]                rresp,
        input                      rlast,
        input [AXI_USER_WIDTH-1:0] ruser,
        input                      rvalid,
        output                     rready,

        //}}}
       
        input [AXI_ADDR_WIDTH-1:0] master_instr_awaddr,
        input [7:0]                master_instr_awlen,
        input [1:0]                master_instr_awburst,
        input master_instr_aw_valid,

        output aw_flag, //this can indicate if running, or ready to receive new instr
        output [AXI_ADDR_WIDTH-1:0] w_opt_addr,
        input  [AXI_DATA_WIDTH-1:0] write_data,
        input  write_valid,

        input [AXI_ADDR_WIDTH-1:0] master_instr_araddr,
        input [7:0]                master_instr_arlen,
        input [1:0]                master_instr_arburst,
        input master_instr_ar_valid,

        output ar_flag, //this can indicate if running, or ready to receive new instr
        output [AXI_ADDR_WIDTH-1:0] r_opt_addr,
        output  [AXI_DATA_WIDTH-1:0] read_data,
        output  read_valid,
        
        input wire  clk,
		input wire  rst_n
	);


 
    //AXI signals
    //{{{
    reg [AXI_ID_WIDTH-1:0]   AXI_awid;
    reg [AXI_ADDR_WIDTH-1:0] AXI_awaddr;
    reg [7:0]                AXI_awlen;
    reg [2:0]                AXI_awsize;
    reg [1:0]                AXI_awburst;
    reg                      AXI_awlock;
    reg [3:0]                AXI_awcache;
    reg [2:0]                AXI_awprot;
    reg [3:0]                AXI_awqos;
    reg [3:0]                AXI_awregion;
    reg [AXI_USER_WIDTH-1:0] AXI_awuser;
    reg                      AXI_awvalid;
    wire                     AXI_awready;

    wire[AXI_DATA_WIDTH-1:0] AXI_wdata;
    reg [AXI_STRB_WIDTH-1:0] AXI_wstrb;
    reg                      AXI_wlast;
    reg [AXI_USER_WIDTH-1:0] AXI_wuser;
    wire                     AXI_wvalid;
    wire                     AXI_wready;
    reg [AXI_ID_WIDTH-1:0]   AXI_wid;
    
    wire [AXI_ID_WIDTH-1:0]  AXI_bid;
    wire [1:0]               AXI_bresp;
    wire [AXI_USER_WIDTH-1:0]AXI_buser;
    wire                     AXI_bvalid;
    reg                      AXI_bready;

    reg [AXI_ID_WIDTH-1:0]   AXI_arid;
    reg [AXI_ADDR_WIDTH-1:0] AXI_araddr;
    reg [7:0]                AXI_arlen;
    reg [2:0]                AXI_arsize;
    reg [1:0]                AXI_arburst;
    reg                      AXI_arlock;
    reg [3:0]                AXI_arcache;
    reg [2:0]                AXI_arprot;
    reg [3:0]                AXI_arqos;
    reg [3:0]                AXI_arregion;
    reg [AXI_USER_WIDTH-1:0] AXI_aruser;
    reg                      AXI_arvalid;
    wire                     AXI_arready;

    wire [AXI_ID_WIDTH-1:0]  AXI_rid;
    wire [AXI_DATA_WIDTH-1:0]AXI_rdata;
    wire [1:0]               AXI_rresp;
    wire                     AXI_rlast;
    wire [AXI_USER_WIDTH-1:0]AXI_ruser;
    wire                     AXI_rvalid;
    reg                      AXI_rready; 

    assign  awid            =  AXI_awid;
    assign  awaddr[31:0]    =  AXI_awaddr[31:0];
    assign  awlen[7:0]      =  AXI_awlen[7:0];
    assign  awsize[2:0]     =  AXI_awsize[2:0];
    assign  awburst         =  AXI_awburst;
    assign  awlock          =  AXI_awlock;
    assign  awcache         =  AXI_awcache;
    assign  awprot          =  AXI_awprot;
    assign  awqos           =  AXI_awqos;
    assign  awregion        =  AXI_awregion;
    assign  awuser          =  AXI_awuser;
    assign  awvalid         =  AXI_awvalid;
    assign  AXI_awready     =  awready;

    assign  wdata[31:0]     = AXI_wdata[31:0];
    assign  wstrb[3:0]      = AXI_wstrb[3:0];
    assign  wlast           = AXI_wlast;
    assign  wuser           = AXI_wuser;
    assign  wvalid          = AXI_wvalid;
    assign  AXI_wready      = wready;
    assign  wid             = AXI_wid;
    
    assign  AXI_bid         = awid;
    assign  AXI_bresp       = bresp;
    assign  AXI_buser       = buser;
    assign  AXI_bvalid      = bvalid;
    assign  bready          = AXI_bready;

    assign  arid            = AXI_arid; 
    assign  araddr          = AXI_araddr; 
    assign  arlen           = AXI_arlen;
    assign  arsize          = AXI_arsize;
    assign  arburst         = AXI_arburst; 
    assign  arlock          = AXI_arlock; 
    assign  arcache         = AXI_arcache; 
    assign  arprot          = AXI_arprot; 
    assign  arqos           = AXI_arqos; 
    assign  arregion        = AXI_arregion; 
    assign  aruser          = AXI_aruser; 
    assign  arvalid         = AXI_arvalid; 
    assign  AXI_arready     = arready;

    assign  AXI_rid             = arid;
    assign  AXI_rdata           = rdata;
    assign  AXI_rresp           = rresp;
    assign  AXI_rlast           = rlast;
    assign  AXI_ruser           = ruser;
    assign  AXI_rvalid          = rvalid;
    assign  rready              = AXI_rready;

    assign AXI_wdata = write_data;

    //}}}

    //wire
	wire aw_wrap_en;
	wire ar_wrap_en;
	wire [31:0]  aw_wrap_size ; 
	wire [31:0]  ar_wrap_size ; 

    //reg
    reg have_valid_aw_instr;
    reg have_valid_ar_instr;


    reg [AXI_ADDR_WIDTH - 1 : 0] 	instr_awaddr;
	reg [AXI_ADDR_WIDTH - 1 : 0] 	instr_araddr;

    reg axi_ar_flag;
    reg axi_aw_flag;

	reg [7:0] instr_awlen_cntr;
	reg [1:0] instr_awburst;
	reg [7:0] instr_awlen;

	reg [7:0] instr_arlen_cntr;
	reg [1:0] instr_arburst;
	reg [7:0] instr_arlen;

    reg AXI_wvalid_w;
	

	// I/O Connections assignments

//`include "AXI.svh"

//assign
//{{{
assign  aw_wrap_size = (AXI_DATA_WIDTH/8 * (instr_awlen)); 
assign  ar_wrap_size = (AXI_DATA_WIDTH/8 * (instr_arlen)); 
assign  aw_wrap_en = ((instr_awaddr & aw_wrap_size) == aw_wrap_size)? 1'b1: 1'b0;
assign  ar_wrap_en = ((instr_araddr & ar_wrap_size) == ar_wrap_size)? 1'b1: 1'b0;

assign aw_flag = axi_aw_flag;
assign w_opt_addr = instr_awaddr[AXI_ADDR_WIDTH - 1:ADDR_LSB];
assign AXI_wvalid = AXI_wvalid_w & write_valid;

assign ar_flag = axi_ar_flag;
assign r_opt_addr = instr_araddr[AXI_ADDR_WIDTH - 1:ADDR_LSB];
assign read_valid = AXI_rvalid;
assign read_data = AXI_rdata;

//}}}

//have_valid_aw_instr
//{{{
always @( posedge clk )
begin
    if ( rst_n == 1'b0 ) begin
        have_valid_aw_instr <= 0;
    end 
    else begin
        if (axi_aw_flag == 0) begin
            if (master_instr_aw_valid == 1 &&
                master_instr_awaddr < ADDR_END &&
                master_instr_awaddr >= ADDR_ST
            ) begin
                have_valid_aw_instr <= 1;
            end
        end
        else begin
            //axi_aw_flag = 1
            have_valid_aw_instr <= 0;
        end
    end
end
//}}}

//aw_flag instr signals
//{{{
always @( posedge clk )
begin
    if ( rst_n == 1'b0 ) begin
        axi_aw_flag <= 1'b0;
        AXI_awid    <= 4'b0; 
        AXI_awaddr  <= 8'b0;
        AXI_awlen   <= 8'b0;
        AXI_awsize  <= 3'b0; 
        AXI_awburst <= 2'b0;
        AXI_awlock  <= 1'b0;
        AXI_awcache <= 4'b0;
        AXI_awprot  <= 3'b0;
        AXI_awqos   <= 4'b0;
        AXI_awregion<= 4'b0;
        AXI_awuser  <= 10'b0;
        AXI_awvalid <= 1'b0;
    end 
    else begin   
        if (have_valid_aw_instr == 1 &&
            AXI_awready == 0 &&
            //axi_ar_flag == 1'b0 && 
            axi_aw_flag == 1'b0 
        ) begin
            AXI_awaddr  <= master_instr_awaddr;
            AXI_awlen   <= master_instr_awlen;
            AXI_awburst <= master_instr_awburst;
            AXI_awsize  <= SIZE; 
            AXI_awvalid <= 1;
        end
        else begin
            if (AXI_awvalid == 1 && AXI_awready == 1) begin
                axi_aw_flag <= 1'b1;
                AXI_awvalid <= 0;
            end
            //if (AXI_wlast && AXI_wready == 1 && AXI_wvalid == 1) begin
            if (AXI_bready && AXI_bvalid ) begin
                axi_aw_flag <= 1'b0;
            end
        end 
    end 
end      
//}}}

//instr_aw
//{{{
always @( posedge clk )
begin
    if ( rst_n == 1'b0 ) begin
        instr_awaddr <= 0;
        instr_awlen_cntr <= 0;
        instr_awburst <= 0;
        instr_awlen <= 0;
    end 
    else begin    
        if (
            have_valid_aw_instr == 1 &&
            AXI_awready == 1'b0 &&
            //axi_ar_flag == 1'b0 &&
            axi_aw_flag == 1'b0 
        ) begin
            instr_awaddr <= master_instr_awaddr[AXI_ADDR_WIDTH - 1:0];  
            instr_awburst <= master_instr_awburst; 
            instr_awlen <= master_instr_awlen;     
            // start address of transfer
            instr_awlen_cntr <= 0;
        end   
        else if((instr_awlen_cntr <= instr_awlen) && AXI_wready && AXI_wvalid) begin
            instr_awlen_cntr <= instr_awlen_cntr + 1;
            case (instr_awburst)
            2'b00: // fixed burst
                begin
                    instr_awaddr <= instr_awaddr;          
                end   
            2'b01: //incremental burst
                begin
                    instr_awaddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] <= instr_awaddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                    instr_awaddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}};   
                end   
            2'b10: //Wrapping burst
                if (aw_wrap_en) begin
                    instr_awaddr <= (instr_awaddr - aw_wrap_size); 
                end
                else begin
                    instr_awaddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] <= instr_awaddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                    instr_awaddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}}; 
                end                      
            default: //reserved (incremental burst for example)
                begin
                    instr_awaddr <= instr_awaddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                end
            endcase              
        end
    end 
end      
//}}}

//w signals
//{{{
always @( posedge clk )
begin
    if ( rst_n == 1'b0 ) begin
        AXI_wvalid_w <= 1'b0;
        AXI_wstrb <= 1'b0;
        AXI_wlast <= 1'b0;
        AXI_wuser <= 1'b0;
        AXI_wid <= 1'b0;
    end 
    else begin    
        if (axi_aw_flag == 1'b1 && AXI_wvalid_w == 0 && AXI_bready == 0) begin
            AXI_wstrb <= 4'hf;
            AXI_wvalid_w <= 1'b1;
        end
        if  (instr_awlen_cntr == instr_awlen - 1) begin
            AXI_wlast <= 1'b1;
        end
        else begin
            AXI_wlast <= 1'b0;
        end

        if (AXI_wlast && AXI_wready == 1 && AXI_wvalid == 1) begin
            AXI_wstrb <= 4'h0;
            AXI_wvalid_w <= 1'b0;
        end
    end 
end      
//}}}

//B
//{{{
always @( posedge clk ) begin
    if ( rst_n == 1'b0 ) begin
        AXI_bready <= 0;
    end 
    else begin    
        if (axi_aw_flag == 1 ) begin
            AXI_bready <= 1;
        end 
        if (AXI_bready && AXI_bvalid ) begin
            AXI_bready <= 1'b0; 
        end  
    end
end 
//}}}

//have_valid_ar_instr
//{{{
always @( posedge clk )
begin
    if ( rst_n == 1'b0 ) begin
        have_valid_ar_instr <= 0;
    end 
    else begin
        if (axi_ar_flag == 0) begin
            if (master_instr_ar_valid == 1 &&
                master_instr_araddr < ADDR_END &&
                master_instr_araddr >= ADDR_ST 
            ) begin
                have_valid_ar_instr <= 1;
            end
        end
        else begin
            //axi_ar_flag = 1
            have_valid_ar_instr <= 0;
        end
    end
end
//}}}

//ar_flag instr signals
//{{{
always @( posedge clk )
begin
    if ( rst_n == 1'b0 ) begin
        axi_ar_flag <= 1'b0;
        AXI_arid    <= 4'b0; 
        AXI_araddr  <= 8'b0;
        AXI_arlen   <= 8'b0;
        AXI_arsize  <= 3'b0; 
        AXI_arburst <= 2'b0;
        AXI_arlock  <= 1'b0;
        AXI_arcache <= 4'b0;
        AXI_arprot  <= 3'b0;
        AXI_arqos   <= 4'b0;
        AXI_arregion<= 4'b0;
        AXI_aruser  <= 10'b0;
        AXI_arvalid <= 1'b0;
    end 
    else begin   
        if (
            have_valid_ar_instr == 1 &&
            AXI_arready == 1'b0 &&
            //axi_aw_flag == 1'b0 &&
            axi_ar_flag == 1'b0 
        ) begin
            AXI_araddr  <= master_instr_araddr;
            AXI_arlen   <= master_instr_arlen;
            AXI_arburst <= master_instr_arburst;
            AXI_arsize  <= SIZE; 
            AXI_arvalid <= 1;
        end
        else begin
            if (AXI_arvalid == 1 && AXI_arready == 1) begin
                axi_ar_flag <= 1'b1;
                AXI_arvalid <= 0;
            end
            if (AXI_rlast && AXI_rready && AXI_rvalid) begin
                axi_ar_flag <= 1'b0;
            end
        end 
    end 
end      
//}}}

//instr_arlen
//{{{
always @( posedge clk )
begin
    if ( rst_n == 1'b0 ) begin
        instr_araddr <= 0;
        instr_arlen_cntr <= 0;
        instr_arburst <= 0;
        instr_arlen <= 0;
    end 
    else begin    
        if (
            have_valid_ar_instr == 1 &&
            AXI_arready == 1'b0 &&
            //axi_aw_flag == 1'b0 &&
            axi_ar_flag == 1'b0 
        ) begin
            instr_araddr <= master_instr_araddr[AXI_ADDR_WIDTH - 1:0];  
            instr_arburst <= master_instr_arburst; 
            instr_arlen <= master_instr_arlen;     
            // start address of transfer
            instr_arlen_cntr <= 0;
        end   
        else if((instr_arlen_cntr <= instr_arlen) && rready && rvalid) begin
            instr_arlen_cntr <= instr_arlen_cntr + 1;
            case (instr_arburst)
            2'b00: // fixed burst
                begin
                    instr_araddr <= instr_araddr;          
                end   
            2'b01: //incremental burst
                begin
                    instr_araddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] <= instr_araddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                    instr_araddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}};   
                end   
            2'b10: //Wrapping burst
                if (ar_wrap_en) begin
                    instr_araddr <= (instr_araddr - ar_wrap_size); 
                end
                else begin
                    instr_araddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] <= instr_araddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                    instr_araddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}}; 
                end                      
            default: //reserved (incremental burst for example)
                begin
                    instr_araddr <= instr_araddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                end
            endcase              
        end
    end 
end      
//}}}

//rready
//{{{
always @( posedge clk )
begin
    if ( rst_n == 1'b0 ) begin
        AXI_rready <= 1'b0;
    end 
    else begin    
        if (axi_ar_flag == 1'b1) begin
            if (AXI_rready == 1'b0) begin
                AXI_rready <= 1'b1;
            end
            if (AXI_rlast && AXI_rready && AXI_rvalid) begin
                AXI_rready <= 1'b0;
            end
        end
    end 
end      
//}}}


endmodule
