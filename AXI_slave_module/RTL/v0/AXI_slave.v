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
       
        //eight useful signals
        output reg [AXI_DATA_WIDTH - 1 : 0]   write_data,
        output reg [3 : 0]                    write_strb,
        output reg [AXI_ADDR_WIDTH - 1 : 0]   w_opt_addr,
        output reg write_valid,
 
        output wire [AXI_ADDR_WIDTH - 1 : 0]   r_opt_addr,
        output wire ar_flag,
        input  wire [AXI_DATA_WIDTH - 1 : 0]   read_data,
	    input  wire read_valid, 

        input aw_ar_ready,


 
        input wire  clk,
		input wire  rst_n
	);


 
    //AXI signals
    //{{{
    wire [AXI_ID_WIDTH-1:0]   AXI_awid;
    wire [AXI_ADDR_WIDTH-1:0] AXI_awaddr;
    wire [7:0]                AXI_awlen;
    wire [2:0]                AXI_awsize;
    wire [1:0]                AXI_awburst;
    wire                      AXI_awlock;
    wire [3:0]                AXI_awcache;
    wire [2:0]                AXI_awprot;
    wire [3:0]                AXI_awqos;
    wire [3:0]                AXI_awregion;
    wire [AXI_USER_WIDTH-1:0] AXI_awuser;
    wire                      AXI_awvalid;
    reg                       AXI_awready;

    wire [AXI_DATA_WIDTH-1:0] AXI_wdata;
    wire [AXI_STRB_WIDTH-1:0] AXI_wstrb;
    wire                      AXI_wlast;
    wire [AXI_USER_WIDTH-1:0] AXI_wuser;
    wire                      AXI_wvalid;
    reg                       AXI_wready;
    wire [AXI_ID_WIDTH-1:0]   AXI_wid;
    
    reg [AXI_ID_WIDTH-1:0]    AXI_bid;
    reg [1:0]                 AXI_bresp;
    reg [AXI_USER_WIDTH-1:0]  AXI_buser;
    reg                       AXI_bvalid;
    wire                      AXI_bready;

    wire [AXI_ID_WIDTH-1:0]   AXI_arid;
    wire [AXI_ADDR_WIDTH-1:0] AXI_araddr;
    wire [7:0]                AXI_arlen;
    wire [2:0]                AXI_arsize;
    wire [1:0]                AXI_arburst;
    wire                      AXI_arlock;
    wire [3:0]                AXI_arcache;
    wire [2:0]                AXI_arprot;
    wire [3:0]                AXI_arqos;
    wire [3:0]                AXI_arregion;
    wire [AXI_USER_WIDTH-1:0] AXI_aruser;
    wire                      AXI_arvalid;
    reg                       AXI_arready;

    reg [AXI_ID_WIDTH-1:0]    AXI_rid;
    wire [AXI_DATA_WIDTH-1:0] AXI_rdata;
    reg [1:0]                 AXI_rresp;
    reg                       AXI_rlast;
    reg [AXI_USER_WIDTH-1:0]  AXI_ruser;
    reg                       AXI_rvalid_w;
    wire                      AXI_rvalid;
    wire                      AXI_rready; 

    assign  AXI_awid     =  awid;
    assign  AXI_awaddr[31:0]   =  awaddr[31:0];
    assign  AXI_awlen[7:0]    =  awlen[7:0];
    assign  AXI_awsize[2:0]   =  awsize[2:0];
    assign  AXI_awburst  =  awburst;
    assign  AXI_awlock   =  awlock;
    assign  AXI_awcache  =  awcache;
    assign  AXI_awprot   =  awprot;
    assign  AXI_awqos    =  awqos;
    assign  AXI_awregion =  awregion;
    assign  AXI_awuser   =  awuser;
    assign  AXI_awvalid  =  awvalid;
    assign  awready      =  AXI_awready;

    assign  AXI_wdata[31:0]   = wdata[31:0];
    assign  AXI_wstrb[3:0]   = wstrb[3:0];
    assign  AXI_wlast   = wlast;
    assign  AXI_wuser   = wuser;
    assign  AXI_wvalid  = wvalid;
    assign  wready      = AXI_wready;
    assign  AXI_wid     = wid;
    
    assign  bid         = AXI_awid;
    assign  bresp       = AXI_bresp;
    assign  buser       = AXI_buser;
    assign  bvalid      = AXI_bvalid;
    assign  AXI_bready  = bready;

    assign  AXI_arid    = arid; 
    assign  AXI_araddr[31:0]  = araddr[31:0]; 
    assign  AXI_arlen[7:0]    =  arlen[7:0];
    assign  AXI_arsize[2:0]   =  arsize[2:0];
    assign  AXI_arburst = arburst; 
    assign  AXI_arlock  = arlock; 
    assign  AXI_arcache = arcache; 
    assign  AXI_arprot  = arprot; 
    assign  AXI_arqos   = arqos; 
    assign  AXI_arregion= arregion; 
    assign  AXI_aruser  = aruser; 
    assign  AXI_arvalid = arvalid; 
    assign  arready     = AXI_arready;

    assign  rid         = AXI_arid;
    assign  rdata       = AXI_rdata;
    assign  rresp       = AXI_rresp;
    assign  rlast       = AXI_rlast;
    assign  ruser       = AXI_ruser;
    assign  rvalid      = AXI_rvalid;
    assign  AXI_rready  = rready;
    //}}}

    //wire
	wire aw_wrap_en;
	wire ar_wrap_en;
	wire [31:0]  aw_wrap_size ; 
	wire [31:0]  ar_wrap_size ; 

    //reg	
    reg [AXI_ADDR_WIDTH - 1 : 0] 	instr_awaddr;
	reg [AXI_ADDR_WIDTH - 1 : 0] 	instr_araddr;

    reg axi_ar_flag;
    reg axi_aw_flag;

	reg [7:0] instr_awlen_cntr;
	reg [7:0] instr_arlen_cntr;
	reg [1:0] instr_arburst;
	reg [1:0] instr_awburst;
	reg [7:0] instr_arlen;
	reg [7:0] instr_awlen;


	

	// I/O Connections assignments

//`include "AXI.svh"

//assign
//{{{
assign  aw_wrap_size = (AXI_DATA_WIDTH/8 * (instr_awlen)); 
assign  ar_wrap_size = (AXI_DATA_WIDTH/8 * (instr_arlen)); 
assign  aw_wrap_en = ((instr_awaddr & aw_wrap_size) == aw_wrap_size)? 1'b1: 1'b0;
assign  ar_wrap_en = ((instr_araddr & ar_wrap_size) == ar_wrap_size)? 1'b1: 1'b0;


//}}}

//eight useful signals: read
assign AXI_rdata = read_data; 
assign r_opt_addr = instr_araddr [AXI_ADDR_WIDTH - 1:ADDR_LSB];
assign ar_flag = axi_ar_flag;
assign AXI_rvalid = AXI_rvalid_w & read_valid;

//eight useful signals: write, use ff to buffer wdata
//{{{
//assign write_data = AXI_wdata;
//assign write_strb = AXI_wstrb;
//assign w_opt_addr = instr_awaddr [AXI_ADDR_WIDTH - 1:ADDR_LSB];
//assign write_valid = (AXI_wready == 1 && AXI_wvalid == 1) ? 1 : 0;
always @(posedge clk) begin
    if ( rst_n == 1'b0 ) begin
        write_data <= 0;
        write_strb <= 0;
        w_opt_addr <= 0;
        write_valid <= 0;
    end
    else begin
        if (AXI_wready == 1 && AXI_wvalid == 1) begin
            write_data <= AXI_wdata;
            write_strb <= AXI_wstrb;
            w_opt_addr <= instr_awaddr [AXI_ADDR_WIDTH - 1:ADDR_LSB];
            write_valid <= 1;
        end 
        else begin
            write_valid <= 0;
        end
    end
end
//}}}

//awready
//{{{
always @( posedge clk )
begin
    if ( rst_n == 1'b0 ) begin
        AXI_awready <= 1'b0;
        axi_aw_flag <= 1'b0;
    end 
    else begin    
        if (
            aw_ar_ready == 1'b1 &&
            AXI_awready == 1'b0 &&
            AXI_awvalid == 1'b1 && 
            axi_aw_flag == 1'b0 &&
            //axi_ar_flag == 1'b0 &&
            AXI_awaddr < ADDR_END &&
            AXI_awaddr >= ADDR_ST
        ) begin
            axi_aw_flag  <= 1'b1; 
        end
        else if (AXI_wlast == 1'b1 && AXI_wready == 1'b1) begin    
            axi_aw_flag  <= 1'b0;
        end
        if (
            aw_ar_ready == 1'b1 &&
            AXI_awready == 1'b0 &&
            AXI_awvalid == 1'b1 && 
            axi_aw_flag == 1'b0 &&
            //axi_ar_flag == 1'b0 &&
            AXI_awaddr < ADDR_END &&
            AXI_awaddr >= ADDR_ST
        ) begin
            AXI_awready <= 1'b1;
        end
        else begin
            AXI_awready <= 1'b0;
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
            aw_ar_ready == 1'b1 &&
            AXI_awready == 1'b0 &&
            AXI_awvalid == 1'b1 && 
            axi_aw_flag == 1'b0 &&
            //axi_ar_flag == 1'b0 &&
            AXI_awaddr < ADDR_END &&
            AXI_awaddr >= ADDR_ST
        ) begin
            instr_awaddr <= AXI_awaddr[AXI_ADDR_WIDTH - 1:0];  
            instr_awburst <= AXI_awburst; 
            instr_awlen <= AXI_awlen;     
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
 
//wready
//{{{
always @( posedge clk )
begin
    if ( rst_n == 1'b0 ) begin
        AXI_wready <= 1'b0;
    end 
    else begin    
        if (axi_aw_flag == 1'b1) begin
            if (AXI_wready == 1'b0) begin
                AXI_wready <= 1'b1;
            end
        end
        if (AXI_wlast && AXI_wready) begin
            AXI_wready <= 1'b0;
        end
    end 
end      
//}}}
 
//WRITE_RESP (B)
//{{{
always @( posedge clk ) begin
    if ( rst_n == 1'b0 ) begin
        AXI_bvalid <= 0;
        AXI_bresp <= 2'b0;
        AXI_buser <= 0;
    end 
    else begin    
        if (axi_aw_flag && AXI_wready && AXI_wvalid && ~AXI_bvalid && AXI_wlast ) begin
            AXI_bvalid <= 1'b1;
            AXI_bresp  <= 2'b0; 
        end                   
        else begin
            if (AXI_bready && AXI_bvalid) begin
                AXI_bvalid <= 1'b0; 
            end  
        end
    end
 end 

always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        AXI_bid   <= 1'b0;
    end 
    else begin           
        if (axi_aw_flag == 1'b1) begin
            AXI_bid <= AXI_awid;
        end
    end
end
 
//}}}
 
//arready
//{{{   
always @( posedge clk ) begin
    if ( rst_n == 1'b0 ) begin
        AXI_arready <= 1'b0;
        axi_ar_flag <= 1'b0;
    end 
    else begin    
        if (
            aw_ar_ready == 1'b1 &&
            AXI_arready == 1'b0 && 
            AXI_arvalid == 1'b1 && 
            //axi_aw_flag == 1'b0 && 
            axi_ar_flag == 1'b0 &&
            AXI_araddr < ADDR_END &&
            AXI_araddr >= ADDR_ST
        ) begin
            axi_ar_flag <= 1'b1;
        end
        else if (AXI_rlast == 1'b1 && AXI_rready == 1'b1 ) begin
            axi_ar_flag  <= 1'b0;
        end
        if (
            aw_ar_ready == 1'b1 &&
            AXI_arready == 1'b0 && 
            AXI_arvalid == 1'b1 && 
            //axi_aw_flag == 1'b0 && 
            axi_ar_flag == 1'b0 && 
            AXI_araddr < ADDR_END &&
            AXI_araddr >= ADDR_ST
        ) begin
            AXI_arready <= 1'b1;
        end
        else begin
            AXI_arready <= 1'b0;
        end
    end 
end      
//}}}

//instr_ar
//{{{
//This process is used to latch the address when both
always @( posedge clk ) begin
    if ( rst_n == 1'b0 ) begin
        instr_araddr <= 0;
        instr_arlen_cntr <= 0;
        instr_arburst <= 0;
        instr_arlen <= 0;
    end 
    else begin    
        if (
            aw_ar_ready == 1'b1 &&
            AXI_arready == 1'b0 && 
            AXI_arvalid == 1'b1 && 
            //axi_aw_flag == 1'b0 && 
            axi_ar_flag == 1'b0 && 
            AXI_araddr < ADDR_END &&
            AXI_araddr >= ADDR_ST
        ) begin
            instr_araddr <= AXI_araddr[AXI_ADDR_WIDTH - 1:0]; 
            instr_arburst <= AXI_arburst; 
            instr_arlen <= AXI_arlen;     
            instr_arlen_cntr <= 0;
        end   
        else if((instr_arlen_cntr <= instr_arlen) && AXI_rvalid == 1 && AXI_rready ) begin
            instr_arlen_cntr <= instr_arlen_cntr + 1;
        
            case (instr_arburst)
            2'b00: // fixed burst
                begin
                    instr_araddr       <= instr_araddr;        
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
                //araddr aligned to 4 byte boundary
                    instr_araddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}};   
                end                      
            default: //reserved (incremental burst for example)
                begin
                    instr_araddr <= instr_araddr[AXI_ADDR_WIDTH - 1:ADDR_LSB]+1;
                end
            endcase              
        end
    end 
end       
//}}}

//rlast
//{{{
always @(*) begin
    AXI_ruser = 1'b0;
    if(instr_arlen_cntr == instr_arlen && AXI_rvalid == 1) begin
        AXI_rlast = 1'b1;
    end       
    else begin
        AXI_rlast = 1'b0;
    end   
end
//}}}

//rvalid_w
//{{{    
always @( posedge clk ) begin
    if ( rst_n == 1'b0 ) begin
        AXI_rvalid_w <= 0;
        AXI_rresp  <= 0;
    end 
    else begin    
        if (axi_ar_flag && ~AXI_rvalid_w) begin
            AXI_rvalid_w <= 1'b1;
            AXI_rresp  <= 2'b0; 
        end   
        //else if (rvalid && rready && instr_arlen_cntr == instr_arlen) begin
        else if (AXI_rlast && AXI_rready) begin
            AXI_rvalid_w <= 1'b0;
            AXI_rresp  <= 2'b0; 
        end            
    end
end
//}}}





endmodule
