/*
以下文字来自axi_slave_mem_wrap/RTL/v2/README:
1. read mem，我们可以知道memory是看到了addr和read_req就能把地址对应的值推出来，但是这个推是需要2个cycle的latency的。所以为了不因为latency影响读速度（driver不能看见一个响应才换一个读地址），所以读地址要一直往前无脑的推。
2. 然而，无脑的推读地址是有代价的，就是memory的有效数据只会保持一个cycle，这就要求在这一个cycle里把这个有效数据保存下来。这就要用到fifo。AXI 的RVALID被挂在FIFO的empty上，只要fifo存下数据后，不empty，AXI上的master就在读它。
3. 然而，fifo的长度是有限制的，不可能无限的存。那么就产生了一个新的问题，假如AXI上的master读RREADY的速度比read mem的速度慢，就会导致fifo 会起full。fifo的full本来应该限制read mem部分的读read_req，假如fifo full了，就不能再起read_req了。但是，由于memory有latency，那么fifo的full是不能实时的因为多读了几个read mem而忠实反映full了。那就堵不住新来的数据了。
4. 那么，就只能废掉fifo的full了，用instr_arlen_cntr_in - instr_arlen_cntr_out < FIFO_LENGTH来决定是不是发了会把fifo写full了的那么多个read_req。注意，这不是在说一种可能性，而是当时确实会发出一个写full了的read_req。因为假如instr_arlen_cntr_in - instr_arlen_cntr_out >= FIFO_LENGTH了，说明此时我发出来的读指令已经会造成几个cycle的memory latency后fifo被写full，那么即使在这几个cycle的latency里面有了外面的AXI R操作把instr_arlen_cntr_out往前推，但是当前情况下我们不能去赌AXI上的R操作。因此决不能再发read_mem req了。
5. instr_arlen_cntr_in instr_arlen_cntr_out每次在收到AXI 的AR指令时都会reset成0，理论上说，如果这个mem wrap的design里面有一个巨大的buffer （256 * 32）bit，我就可以不用fifo来存了，用instr_arlen_cntr_in 当write 下标，instr_arlen_cntr_out当read下标。但是这太占面积。理论上说，只要fifo的length比memory的latency大一点点就够了，不用太大的fifo


这里就直接做一个AR module,可以用来解决任何有latency的外部设备，包括memory或者什么外设。读部分被简化成四个信号，
r_opt_addr 当前读地址
read_req 当前读请求
read_data 外部进来的读data
read_valid 外部的读valid
一切读都是顺序的，发读请求和读地址是顺序发的，那么回来的也是顺序回来的，都推进fifo里。
AXI上就从fifo拿就可以了。

这个design，已经经过了axi_slave_mem_device的测试，mem_device里面测过了时序逻辑和组合逻辑，即有1cycle的latency和无latency的两种返回data方法，都有效。fifo depth为1都有效。
*/

`timescale 1 ns / 1 ps

	module pure_AXI_slave_AR_module #
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
        parameter integer FIFO_LENGTH = 4,

	    parameter integer ADDR_ST  = 'h0 + ADDR_BASE_OFFSET,
	    parameter integer ADDR_END  = 'h400 + ADDR_BASE_OFFSET
    )
	(

        //`include "AXI_IO_define.svh"
        //{{{
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
       
        output wire [AXI_ADDR_WIDTH - 1 : 0]   r_opt_addr,
        output reg read_req,
        input  wire [AXI_DATA_WIDTH - 1 : 0]   read_data,
	    input  wire read_valid, 

        input aw_ar_ready,


 
        input wire  clk,
		input wire  rst_n
	);
    
    //AXI signals
    //{{{
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
	wire ar_wrap_en;
	wire [31:0]  ar_wrap_size ; 

    //reg	
	reg [AXI_ADDR_WIDTH - 1 : 0] 	instr_araddr;
	reg [AXI_ADDR_WIDTH - 1 : 0] 	instr_araddr_init;

    reg axi_ar_flag;

	reg [7:0] instr_arlen_cntr_in;
	reg [7:0] instr_arlen_cntr_out;
	reg [1:0] instr_arburst;
	reg [7:0] instr_arlen;

    reg receive_valid_ar_instr;   
 
    //fifo signals
    //{{{
    wire fifo_read;
    wire fifo_write;
    wire fifo_empty;
    wire fifo_full;
 
    wire [AXI_DATA_WIDTH-1:0] fifo_input_data;
    wire [AXI_DATA_WIDTH-1:0] fifo_output_data;
    
    assign fifo_read = rready & rvalid;
    assign fifo_write = read_valid && axi_ar_flag;
    assign fifo_input_data = read_data;
    //}}}	

    //assign
    //{{{
    assign  ar_wrap_size = (AXI_DATA_WIDTH/8 * (instr_arlen)); 
    assign  ar_wrap_en = ((instr_araddr & ar_wrap_size) == ar_wrap_size)? 1'b1: 1'b0;
    //}}}

    //eight useful signals: read
    assign AXI_rdata = fifo_output_data; 
    assign r_opt_addr = instr_araddr_init [AXI_ADDR_WIDTH - 1:ADDR_LSB] + instr_arlen_cntr_in; 
    assign AXI_rvalid = AXI_rvalid_w & ~fifo_empty;
    
    //Instantiation of fifo
    //{{{
    fifo #(
        .DATA_BITS (AXI_DATA_WIDTH),
        .FIFO_LENGTH (FIFO_LENGTH)
    ) FIFO (
        .input_data     (fifo_input_data),
        .output_data    (fifo_output_data),
        .read           (fifo_read),
        .write          (fifo_write),
        .empty          (fifo_empty),
        .full           (fifo_full),

        
        .clk                    (clk),
		.reset                  (rst_n)
    ); 
    //}}}

always @(*) begin
    if (
        axi_ar_flag == 1 &&
        instr_arlen_cntr_in - instr_arlen_cntr_out < FIFO_LENGTH &&
        (instr_arlen_cntr_in <= instr_arlen)
    ) begin
        read_req = 1;
    end
    else begin
        read_req = 0;
    end
end
    
always @(*) begin
    if (
        aw_ar_ready == 1'b1 &&
        AXI_arready == 1'b0 && 
        AXI_arvalid == 1'b1 && 
        //axi_aw_flag == 1'b0 && 
        axi_ar_flag == 1'b0 && 
        AXI_araddr < ADDR_END &&
        AXI_araddr >= ADDR_ST
    ) begin
        receive_valid_ar_instr = 1;
    end
    else begin
        receive_valid_ar_instr = 0;
    end
end



//arready
//{{{   
always @( posedge clk ) begin
    if ( rst_n == 1'b0 ) begin
        AXI_arready <= 1'b0;
        axi_ar_flag <= 1'b0;
    end 
    else begin    
        if (
            receive_valid_ar_instr == 1
        ) begin
            axi_ar_flag <= 1'b1;
        end
        else if (AXI_rlast == 1'b1 && AXI_rready == 1'b1 ) begin
            axi_ar_flag  <= 1'b0;
        end
        if (
            receive_valid_ar_instr == 1
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
        instr_arlen_cntr_out <= 0;
    end
    else begin
        if (
            receive_valid_ar_instr == 1
        ) begin
            instr_arlen_cntr_out <= 0;
        end
        else if((instr_arlen_cntr_out <= instr_arlen) && AXI_rvalid == 1 && AXI_rready ) begin
            instr_arlen_cntr_out <= instr_arlen_cntr_out + 1;
        end

    end
end

always @( posedge clk ) begin
    if ( rst_n == 1'b0 ) begin
        instr_arlen_cntr_in <= 0;
    end
    else begin
        if (
            receive_valid_ar_instr == 1
        ) begin
            instr_arlen_cntr_in <= 0;
        end
        else if(read_req) begin
            instr_arlen_cntr_in <= instr_arlen_cntr_in + 1;
        end
    end
end

always @( posedge clk ) begin
    if ( rst_n == 1'b0 ) begin
        instr_araddr <= 0;
        instr_araddr_init <= 0;
        instr_arburst <= 0;
        instr_arlen <= 0;
    end 
    else begin    
        if (
            receive_valid_ar_instr == 1
        ) begin
            instr_araddr <= AXI_araddr[AXI_ADDR_WIDTH - 1:0]; 
            instr_araddr_init <= AXI_araddr[AXI_ADDR_WIDTH - 1:0]; 
            instr_arburst <= AXI_arburst; 
            instr_arlen <= AXI_arlen;     
        end   
        else if((instr_arlen_cntr_out <= instr_arlen) && AXI_rvalid == 1 && AXI_rready ) begin
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
    if(instr_arlen_cntr_out == instr_arlen && AXI_rvalid == 1) begin
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
