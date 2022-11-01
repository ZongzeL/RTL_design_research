
`timescale 1 ns / 1 ps
longint unsigned ns_counter;
longint unsigned clock_counter;

module TB_memory_bus;

    parameter N_CH0           = 1;  //--> Debug, UdmaTX, UdmaRX, IcacheR5, DataR5
    parameter N_SLAVE         = 2;
    parameter ID_WIDTH        = N_CH0;
    parameter ADDR_WIDTH      = 32;
    parameter DATA_WIDTH      = 32;
    parameter BE_WIDTH        = DATA_WIDTH/8;
    parameter ADDR_MEM_WIDTH  = 12;
    parameter ADDR_IN_WIDTH    = ADDR_MEM_WIDTH+$clog2(N_SLAVE);
    parameter TB_RESET_VALUE = 0;

    logic               clk, rst_n;
    logic [N_CH0-1:0]   fetch_enable;


    //XBAR_L2 signals
    //{{{

    // ---------------- Master SIDE (Interleaved) --------------------------
    reg                          data_req_TGEN;
    reg  [ADDR_IN_WIDTH-1:0]     data_add_TGEN;
    reg                          data_wen_TGEN;
    reg  [DATA_WIDTH-1:0]        data_wdata_TGEN;
    reg  [BE_WIDTH-1:0]          data_be_TGEN;
    wire                         data_gnt_TGEN;
    wire                         data_r_valid_TGEN;
    wire [DATA_WIDTH-1:0]        data_r_rdata_TGEN;


    // ---------------- Memeory SIDE (Interleaved) --------------------------
    wire [N_SLAVE-1:0]                            data_req_MEM;            // Data request
    wire [N_SLAVE-1:0][ADDR_MEM_WIDTH-1:0]        data_add_MEM;            // Data request Address
    wire [N_SLAVE-1:0]                            data_wen_MEM;            // Data request type : 0--> Store; 1 --> Load
    wire [N_SLAVE-1:0][DATA_WIDTH-1:0]            data_wdata_MEM;          // Data request Wrire data
    wire [N_SLAVE-1:0][BE_WIDTH-1:0]              data_be_MEM;             // Data request Byte enable
    wire [N_SLAVE-1:0][ID_WIDTH-1:0]              data_ID_MEM;

    wire  [N_SLAVE-1:0]                            data_r_valid_MEM;
    wire  [N_SLAVE-1:0][DATA_WIDTH-1:0]            data_r_rdata_MEM;        // Data Response DATA (For LOAD commands)
    wire  [N_SLAVE-1:0][ID_WIDTH-1:0]              data_r_ID_MEM;
    //}}}

    //BRAM signals
    //{{{
    wire [N_SLAVE-1:0][ADDR_MEM_WIDTH - 1 : 0]      ADDRA;
    wire [N_SLAVE-1:0][DATA_WIDTH - 1 : 0]          DINA;
    wire [N_SLAVE-1:0][DATA_WIDTH - 1 : 0]          DOUTA;
    wire [N_SLAVE-1:0]                              ENA;
    wire [N_SLAVE-1:0]                              WEA;
    //}}}

    //instantiation of XBAR_L2
    one_master_two_slave_XBAR_L2_wrap
    //{{{
    #(
        .N_MASTER       ( N_CH0           ), // = 5,  //--> Debug, UdmaTX, UdmaRX, IcacheR5, DataR5
        .N_SLAVE        ( N_SLAVE         ), // = 4,
        .ID_WIDTH       ( ID_WIDTH        ), // = N_CH0,
        .ADDR_WIDTH     ( ADDR_WIDTH      ), // = 32,
        .DATA_WIDTH     ( DATA_WIDTH      ), // = 32,
        .BE_WIDTH       ( BE_WIDTH        ), // = DATA_WIDTH/8,
        .ADDR_MEM_WIDTH ( ADDR_MEM_WIDTH  )
    )
    DUT_i
    (
        // ---------------- MASTER CH0 SIDE  --------------------------
        .data_req_M_i_0             ( data_req_TGEN     ), // Data request
        .data_add_M_i_0             ( data_add_TGEN     ), // Data request Address
        .data_wen_M_i_0             ( data_wen_TGEN     ), // Data request type : 0--> Store 1 --> Load
        .data_wdata_M_i_0           ( data_wdata_TGEN   ), // Data request Write data
        .data_be_M_i_0              ( data_be_TGEN      ), // Data request Byte enable
        .data_gnt_M_o_0             ( data_gnt_TGEN     ), // Grant Incoming Request
        .data_r_valid_M_o_0         ( data_r_valid_TGEN ), // Data Response Valid (For LOAD/STORE commands)
        .data_r_rdata_M_o_0         ( data_r_rdata_TGEN ), // Data Response DATA (For LOAD commands)

        // ---------------- MM_SIDE (Interleaved) --------------------------
        .data_req_S_o_0             ( data_req_MEM[0]        ), // Data request
        .data_add_S_o_0             ( data_add_MEM[0]        ), // Data request Address
        .data_wen_S_o_0             ( data_wen_MEM[0]        ), // Data request type : 0--> Store 1 --> Load
        .data_wdata_S_o_0           ( data_wdata_MEM[0]      ), // Data request Wrire data
        .data_be_S_o_0              ( data_be_MEM[0]         ), // Data request Byte enable
        .data_ID_S_o_0              ( data_ID_MEM[0]         ),

        .data_r_valid_S_i_0         ( data_r_valid_MEM[0]    ),
        .data_r_rdata_S_i_0         ( data_r_rdata_MEM[0]    ), // Data Response DATA (For LOAD commands)
        .data_r_ID_S_i_0            ( data_r_ID_MEM[0]       ),
        
        .data_req_S_o_1             ( data_req_MEM[1]        ), // Data request
        .data_add_S_o_1             ( data_add_MEM[1]        ), // Data request Address
        .data_wen_S_o_1             ( data_wen_MEM[1]        ), // Data request type : 0--> Store 1 --> Load
        .data_wdata_S_o_1           ( data_wdata_MEM[1]      ), // Data request Wrire data
        .data_be_S_o_1              ( data_be_MEM[1]         ), // Data request Byte enable
        .data_ID_S_o_1              ( data_ID_MEM[1]         ),

        .data_r_valid_S_i_1         ( data_r_valid_MEM[1]    ),
        .data_r_rdata_S_i_1         ( data_r_rdata_MEM[1]    ), // Data Response DATA (For LOAD commands)
        .data_r_ID_S_i_1            ( data_r_ID_MEM[1]       ),

        .clk                    ( clk                 ),
        .rst_n                  ( rst_n               )
    );
    //}}}

    //instantiation of BRAM_wrap
    //{{{
    BRAM_wrap_single
    #(
        .ID_WIDTH       ( ID_WIDTH        ), // = N_CH0,
        .ADDR_WIDTH     ( ADDR_MEM_WIDTH      ), // = 32,
        .DATA_WIDTH     ( DATA_WIDTH      )  // = 32,
    ) BRAM_WRAP_0 (
        .data_req_i             ( data_req_MEM[0]                         ), // Data request
        .data_add_i             ( data_add_MEM[0][ADDR_MEM_WIDTH-1:0]     ), // Data request Address
        .data_wen_i             ( data_wen_MEM[0]                         ), // Data request type : 0--> Store 1 --> Load
        .data_wdata_i           ( data_wdata_MEM[0][DATA_WIDTH-1:0]       ), // Data request Write data
        .data_be_i              ( data_be_MEM[0][BE_WIDTH-1:0]            ), // Data request Byte enable
        .data_ID_i              ( data_ID_MEM[0]                         ), // Grant Incoming Request
        .data_r_valid_o         ( data_r_valid_MEM[0]                     ), // Data Response Valid (For LOAD/STORE commands)
        .data_r_rdata_o         ( data_r_rdata_MEM[0][DATA_WIDTH-1:0]     ), // Data Response DATA (For LOAD commands)
        .data_r_ID_o            ( data_r_ID_MEM[0]                         ), // Grant Incoming Request
         
        .ADDRA_o                (ADDRA[0][ADDR_MEM_WIDTH - 1 : 0]         ),
        .DINA_o                 (DINA[0][DATA_WIDTH - 1 : 0]              ),
        .DOUTA_i                (DOUTA[0][DATA_WIDTH - 1 : 0]             ),
        .ENA_o                  (ENA[0]),
        .WEA_o                  (WEA[0]),
        
        .clk                    ( clk                 ),
        .rst_n                  ( rst_n               )
    );
    
    BRAM_wrap_single
    #(
        .ID_WIDTH       ( ID_WIDTH        ), // = N_CH0,
        .ADDR_WIDTH     ( ADDR_MEM_WIDTH      ), // = 12,
        .DATA_WIDTH     ( DATA_WIDTH      )  // = 32,
    ) BRAM_WRAP_1 (
        .data_req_i             ( data_req_MEM[1]                         ), // Data request
        .data_add_i             ( data_add_MEM[1][ADDR_MEM_WIDTH-1:0]     ), // Data request Address
        .data_wen_i             ( data_wen_MEM[1]                         ), // Data request type : 0--> Store 1 --> Load
        .data_wdata_i           ( data_wdata_MEM[1][DATA_WIDTH-1:0]       ), // Data request Write data
        .data_be_i              ( data_be_MEM[1][BE_WIDTH-1:0]            ), // Data request Byte enable
        .data_ID_i              ( data_ID_MEM[1]                          ), // Grant Incoming Request
        .data_r_valid_o         ( data_r_valid_MEM[1]                     ), // Data Response Valid (For LOAD/STORE commands)
        .data_r_rdata_o         ( data_r_rdata_MEM[1][DATA_WIDTH-1:0]     ), // Data Response DATA (For LOAD commands)
        .data_r_ID_o            ( data_r_ID_MEM[1]                        ), // Grant Incoming Request
         
        .ADDRA_o                (ADDRA[1][ADDR_MEM_WIDTH - 1 : 0]         ),
        .DINA_o                 (DINA[1][DATA_WIDTH - 1 : 0]              ),
        .DOUTA_i                (DOUTA[1][DATA_WIDTH - 1 : 0]             ),
        .ENA_o                  (ENA[1]),
        .WEA_o                  (WEA[1]),
        
        .clk                    ( clk                 ),
        .rst_n                  ( rst_n               )
    );
    //}}}

    //instantiation of BRAM 
    //must use blk_mem_gen_0, do not use blk_mem_gen_1. blk_mem_gen_1 is a model with out and read latency
    blk_mem_gen_0 #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_MEM_WIDTH),
        .MEM_LENGTH ($pow(2, ADDR_MEM_WIDTH))
    ) BRAM_0 (
        .ADDRA   (ADDRA[0][ADDR_MEM_WIDTH - 1 : 0]         ),
        .DINA    (DINA[0][DATA_WIDTH - 1 : 0]              ),
        .DOUTA   (DOUTA[0][DATA_WIDTH - 1 : 0]             ),
        .ENA     (ENA[0]),
        .WEA     (WEA[0]),
        .CLKA    (clk)
    );
    
    blk_mem_gen_0 #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_MEM_WIDTH),
        .MEM_LENGTH ($pow(2, ADDR_MEM_WIDTH))
    ) BRAM_1 (
        .ADDRA   (ADDRA[1][ADDR_MEM_WIDTH - 1 : 0]         ),
        .DINA    (DINA[1][DATA_WIDTH - 1 : 0]              ),
        .DOUTA   (DOUTA[1][DATA_WIDTH - 1 : 0]             ),
        .ENA     (ENA[1]),
        .WEA     (WEA[1]),
        .CLKA    (clk)
    );



initial begin
    int i;
    data_req_TGEN = 0;
    data_add_TGEN = 0;
    data_wen_TGEN = 0;
    data_wdata_TGEN = 0;
    data_be_TGEN  = 0;

    fetch_enable = 0;


    for (i = 0; i < 20; i++) begin
        @(posedge clk);
    end

    //write
    //{{{
    master_0_write (0, 12'h0fe, 32'hdea0bee0);
    @(posedge clk);
    master_0_reset_0();
    //}}}
    
    //read
    //{{{
    for (i = 0; i < 20; i++) begin
        @(posedge clk);
    end
    
    master_0_read(0, 12'h0fe);   
 
    @(posedge clk);
    master_0_reset_0();
    //}}}

end

//read write tasks
//{{{
task master_0_write (bit slave, bit[ADDR_MEM_WIDTH - 1:0] addr, bit[DATA_WIDTH -1:0] data);
begin
    data_add_TGEN[11:0] <= addr;
    data_add_TGEN[12:12] <= slave;
    data_req_TGEN <= 1;
    data_wen_TGEN <= 1;
    data_wdata_TGEN <= data;
    data_be_TGEN  <= 4'hf;
end
endtask

task master_0_read (bit slave, bit[ADDR_MEM_WIDTH - 1:0] addr);
begin
    data_add_TGEN[11:0] <= addr;
    data_add_TGEN[12:12] <= slave;
    data_req_TGEN <= 1;
    data_wen_TGEN <= 0;
    data_wdata_TGEN <= 0;
end
endtask

task master_0_reset_0 ();
begin
    data_add_TGEN[12:0] <= 0; 
    data_req_TGEN <= 0;
    data_wen_TGEN <= 0;
    data_wdata_TGEN <= 0;
    data_be_TGEN  <= 0;
end
endtask

//}}}




always @(posedge clk) begin
    if (data_req_MEM[0] == 1 && data_wen_MEM[0] == 1) begin
        $display ("write mem 0 = %h", data_wdata_MEM[0:0]);
    end
    if (data_req_MEM[1] == 1 && data_wen_MEM[1] == 1) begin
        $display ("write mem 0 = %h", data_wdata_MEM[1:1]);
    end
    if (data_r_valid_MEM == 1) begin
        $display ("read mem 0 = %h", data_r_rdata_MEM[0:0]);
    end
    if (data_r_valid_TGEN == 1) begin
        $display ("read bus = %h", data_r_rdata_TGEN[31:0]);
    end
end

//rst_n
//{{{
initial begin
    rst_n = TB_RESET_VALUE;
    #20;
    rst_n = ~TB_RESET_VALUE;
    //messager.dump_message("sim start");
    //#500000;
    #10000;
    //messager.dump_message("sim end");
    $finish;
end
//}}}

//clk
//{{{
initial begin
    clk = 0;
    clock_counter = 0;
    ns_counter = 0;
    forever begin
        #5 clk ^= 1;
        ns_counter += 5;
        #5 clk ^= 1;
        ns_counter += 5;
        clock_counter += 1;
    end
end
//}}}

//waveform
//{{{
initial begin
    $vcdplusfile("waveforms.vpd");
    $vcdpluson();
    $vcdplusmemon();
end
//}}}



endmodule // TB_memory_bus
