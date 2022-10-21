
`timescale 1 ns / 1 ps

	module pure_AXI_slave_AW_module #
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
        
        output reg [AXI_DATA_WIDTH - 1 : 0]   write_data,
        output reg [3 : 0]                    write_strb,
        output reg [AXI_ADDR_WIDTH - 1 : 0]   w_opt_addr,
        output reg write_valid,
        
        input aw_ar_ready,
        
        input wire  clk,
		input wire  rst_n
    );
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
    //}}}

	wire aw_wrap_en;
	wire [31:0]  aw_wrap_size ; 
    reg [AXI_ADDR_WIDTH - 1 : 0] 	instr_awaddr;
    reg axi_aw_flag;
	reg [7:0] instr_awlen_cntr;
	reg [1:0] instr_awburst;
	reg [7:0] instr_awlen;

assign  aw_wrap_size = (AXI_DATA_WIDTH/8 * (instr_awlen)); 
assign  aw_wrap_en = ((instr_awaddr & aw_wrap_size) == aw_wrap_size)? 1'b1: 1'b0;

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

endmodule
