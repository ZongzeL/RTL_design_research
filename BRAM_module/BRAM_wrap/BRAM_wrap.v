/*
This wrap is translating the CPU style memory control signals into bram signals.

LOAD is CPU read memory
STORE is CPU write memory

    // Data request wen : 0--> Store, 1 --> Load
    This is incorrect, or hard to understand. Ignore it. 


data_req is memory en
data_wen is write en


*/
module BRAM_wrap
#(
    parameter ADDR_MEM_WIDTH   = 12,
    parameter DATA_WIDTH       = 32,
    parameter BE_WIDTH         = DATA_WIDTH/8

)
(
    
    //signals for memory bus
    input  wire                      data_req_i,     // Data request
    input  wire [ADDR_MEM_WIDTH-1:0] data_add_i,     // Data request Address {memory ROW , BANK}
    input  wire                      data_wen_i,     // Data request wen : 0--> Store, 1 --> Load --ARES: wen == 1 should be write (STORE)  
    input  wire [DATA_WIDTH-1:0]     data_wdata_i,   // Data request Write data
    input  wire [BE_WIDTH-1:0]       data_be_i,      // Data request Byte enable
    output wire                      data_gnt_o,     // Data request Grant
    // Resp
    output reg                       data_r_valid_o, // Data Response Valid (For LOAD/STORE commands) --ARES: maybe he means valid will rise with req_i with a latency, no matter LOAD/STORE
    output wire [DATA_WIDTH-1:0]     data_r_rdata_o, // Data Response DATA (For LOAD commands)

    //signals for BRAM
    output [ADDR_MEM_WIDTH - 1 : 0] ADDRA_o,
    output [DATA_WIDTH - 1 : 0] DINA_o,
    input  [DATA_WIDTH - 1 : 0] DOUTA_i,
    output ENA_o,
    output WEA_o,


    input  wire clk,                    // Clock
    input  wire rst_n                   // Active Low Reset

);

reg data_r_valid_o_buffer_0;


assign ENA_o = data_req_i;
assign WEA_o = data_wen_i;
assign DINA_o[DATA_WIDTH - 1 : 0] = data_wdata_i[DATA_WIDTH-1:0];
assign ADDRA_o[ADDR_MEM_WIDTH - 1 : 0] = data_add_i[ADDR_MEM_WIDTH-1:0];
assign data_gnt_o = 0;
assign data_r_rdata_o = DOUTA_i;



always @(posedge clk) begin
    if (rst_n == 0) begin
        data_r_valid_o_buffer_0 <= 0;
        data_r_valid_o <= 0;
    end
    else begin
        //data_r_valid_o_buffer_0 <= (data_req_i & ~data_wen_i); //LOAD only
        data_r_valid_o_buffer_0 <= data_req_i;//LOAD/STORE 
        data_r_valid_o <= data_r_valid_o_buffer_0;
    end
end

endmodule
