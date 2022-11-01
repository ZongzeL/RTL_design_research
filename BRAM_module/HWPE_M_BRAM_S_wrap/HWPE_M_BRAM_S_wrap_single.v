/*
This wrap is translating the CPU style memory control signals into bram signals.

LOAD is CPU read memory
STORE is CPU write memory

    // Data request wen : 0--> Store, 1 --> Load
    This is incorrect, or hard to understand. Ignore it. 


data_req is memory en
data_wen is write en

10/25/22 发现以下问题：

1. 以前的design，比如MPW或者waveform gen，ENA_o 是用rst_n的，就是只要rst_n=1就让memory默认开动。这样搞没问题，但是很费电。
2. 我一开始的做法是把ENA_o挂在data_req_i上，而data_req_i在外面其实是read/write request valid，具体是哪个根据情况而定。而外面生成这个request valid的机制有的时候很严苛，一个request，一个addr，只起一次valid。过时就停。
3. 然而，memory在收到一个新write的时候，虽然当时就起效，但是要让这个ENA_o保持至少两个cycle(也有可能是至少3个，毕竟我没试过)。这个数才能真正的被存在memory里。这个ENA_o就相当于NPU里面的apply_v。
4. 那么就出现一个问题，如果用外面的request valid（data_req_i）当ENA_o，它绝不可能保持多那么几个cycle。如果ENA_o用了rst_n，它倒是肯定起效，但是特别耗电。

另外，从别的AXI_BRAM_exp 看来的：
xilinx的这个bram ip，有一种设定是可以让addr = 32 bit，byte = 8 bit，如果这样选了，WEA = 4bit.写的时候从ILA读出来的波形看，它的ENA，WEA是跟着data一起的，也就是起一个cycle马上就变。一个cycle以后写数据就起效了。
不过，这个情况下addr必须要以4为offset变化

而我一直使用的办法，是addr只要加1就可以。
那么，根据这两个实验的观察可以这样想：
1. 更接近axi的做法，就是像AXI_BRAM_exp一样：
    1. WEA有4个bit，用data_be_i&wen_i来当WEA。
    2. add_i 用32bit，以4为offset

2. 直接访问
    1. add_i 用log2 (2048 = 11)，ENA 要多保持至少一个cycle。
        现在我并不清楚该如何给ENA多保持这么一个cycle，如果用一个时序逻辑把data_req_i存下来，assign ENA=data_req_i || HWPE_M_data_req_i_buffer, 那么很可能会造成毛刺，很可怕。

    实验结果显示，以以下方式做ENA，是可以成功的：
    assign ENA_o = HWPE_M_data_req_i || HWPE_M_data_r_valid_o_buffer_0 || HWPE_M_data_r_valid_o;
    这样ENA是可以保持至少3个cycle的高。

=================================================================
这个所谓的single wrap，使用的是直接访问的方法，针对single memory
此设计对应xilinx bram ip 里的“Generate address interface with 32 bits”为关，Byte Write Enable 也为关。具体这两个哪个会影响到WEN有4bit不清楚，很可能是Byte Write Enable
1. AXI 的strb,或者BE，不起作用
2. addr以1为offset去发
3. WEN只有一个bit
4. ENA还是要用此方式保持3 cycle：
    assign ENA_o = HWPE_M_data_req_i || HWPE_M_data_r_valid_o_buffer_0 || HWPE_M_data_r_valid_o;





=================================================================





*/
module HWPE_M_BRAM_S_wrap_single
#(
    parameter ADDR_MEM_WIDTH   = 12,
    parameter DATA_WIDTH       = 32,
    parameter BE_WIDTH         = DATA_WIDTH/8,
    parameter ID_WIDTH         = 2 //should be the total master number

)
(
    
    //signals for memory bus
    input  wire                      HWPE_M_data_req_i,     // Data request
    input  wire [ADDR_MEM_WIDTH-1:0] HWPE_M_data_add_i,     // Data request Address {memory ROW , BANK}
    input  wire                      HWPE_M_data_wen_i,     // Data request wen : 0--> Store, 1 --> Load --ARES: wen == 1 should be write (STORE)  
    input  wire [DATA_WIDTH-1:0]     HWPE_M_data_wdata_i,   // Data request Write data
    input  wire [BE_WIDTH-1:0]       HWPE_M_data_be_i,      // Data request Byte enable
    input  wire [ID_WIDTH-1:0]       HWPE_M_data_ID_i,     
    // Resp
    output reg                       HWPE_M_data_r_valid_o, // Data Response Valid (For LOAD/STORE commands) --ARES: maybe he means valid will rise with req_i with a latency, no matter LOAD/STORE
    output wire [DATA_WIDTH-1:0]     HWPE_M_data_r_rdata_o, // Data Response DATA (For LOAD commands)
    output reg  [ID_WIDTH-1:0]       HWPE_M_data_r_ID_o,     

    //signals for BRAM
    output [ADDR_MEM_WIDTH - 1 : 0] BRAM_S_ADDRA_o,
    output [DATA_WIDTH - 1 : 0] BRAM_S_DINA_o,
    input  [DATA_WIDTH - 1 : 0] BRAM_S_DOUTA_i,
    output BRAM_S_ENA_o,
    output BRAM_S_WEA_o,


    input  wire clk,                    // Clock
    input  wire rst_n                   // Active Low Reset

);

reg data_r_valid_o_buffer_0;
reg [ID_WIDTH-1:0] data_r_ID_o_buffer_0;


//assign ENA_o = rst_n;
assign BRAM_S_ENA_o = HWPE_M_data_req_i || data_r_valid_o_buffer_0 || HWPE_M_data_r_valid_o;
assign BRAM_S_WEA_o = HWPE_M_data_wen_i;
assign BRAM_S_DINA_o[DATA_WIDTH - 1 : 0] = HWPE_M_data_wdata_i[DATA_WIDTH-1:0];
assign BRAM_S_ADDRA_o[ADDR_MEM_WIDTH - 1 : 0] = HWPE_M_data_add_i[ADDR_MEM_WIDTH-1:0];
assign HWPE_M_data_r_rdata_o = BRAM_S_DOUTA_i;




//This is used to fit the memory's two cycles' read latency
always @(posedge clk) begin
    if (rst_n == 0) begin
        data_r_valid_o_buffer_0 <= 0;
        HWPE_M_data_r_valid_o <= 0;
        data_r_ID_o_buffer_0 <= 0;
        HWPE_M_data_r_ID_o <= 0;
    end
    else begin
        //data_r_valid_o_buffer_0 <= (data_req_i & ~data_wen_i); //LOAD only
        data_r_valid_o_buffer_0 <= HWPE_M_data_req_i;//LOAD/STORE 
        HWPE_M_data_r_valid_o <= data_r_valid_o_buffer_0;

        data_r_ID_o_buffer_0 <= HWPE_M_data_ID_i;
        HWPE_M_data_r_ID_o <= data_r_ID_o_buffer_0;
    end
end

endmodule
