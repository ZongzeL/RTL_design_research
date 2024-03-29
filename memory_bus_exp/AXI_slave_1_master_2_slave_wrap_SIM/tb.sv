/*
This case is testing:
    axi_slave_HWPE_mem_wrap
    one_master_two_slave_XBAR_L2_wrap
    


*/

`timescale 1 ns / 1 ps
longint unsigned ns_counter;
longint unsigned clock_counter;

module TB_memory_bus;

    parameter N_CH0           = 1;  //--> Debug, UdmaTX, UdmaRX, IcacheR5, DataR5
    parameter N_SLAVE         = 2;
    parameter ID_WIDTH        = N_CH0;
    parameter AXI_ID_WIDTH    = 10;
    parameter ADDR_WIDTH      = 32;
    parameter DATA_WIDTH      = 32;
    parameter BE_WIDTH        = DATA_WIDTH/8;
    parameter ADDR_MEM_WIDTH  = 12;
    parameter MEM_LENGTH  = 8192; //8192
    parameter ADDR_IN_WIDTH    = ADDR_MEM_WIDTH+$clog2(N_SLAVE);
    parameter USER_WIDTH        = 10;
    parameter TB_RESET_VALUE = 0;

    int i, j;
    
    logic               clk, rst_n;
    logic [N_CH0-1:0]   fetch_enable;
    
    bit [31:0] input_addr;
    bit [31:0] output_addr;
    
    bit[31:0] tmp;

    bit [DATA_WIDTH - 1 : 0] input_list [256];
    bit [DATA_WIDTH - 1 : 0] output_list [256];
    bit [DATA_WIDTH - 1 : 0] golden_list [256];

    //AXI wires
    //{{{
    wire [AXI_ID_WIDTH-1:0]    aw_id;
    wire [ADDR_WIDTH-1:0]      aw_addr;
    wire [7:0]                 aw_len;
    wire [2:0]                 aw_size;
    wire [1:0]                 aw_burst;
    wire                       aw_lock;
    wire [3:0]                 aw_cache;
    wire [2:0]                 aw_prot;
    wire [3:0]                 aw_qos;
    wire [3:0]                 aw_region;
    wire [USER_WIDTH-1:0]      aw_user;
    wire                       aw_valid;
    wire                       aw_ready;

    wire [DATA_WIDTH-1:0]      w_data;
    wire [3:0]                 w_strb;
    wire                       w_last;
    wire [USER_WIDTH-1:0]      w_user;
    wire                       w_valid;
    wire                       w_ready;
    wire [AXI_ID_WIDTH-1:0]    w_id;
    
    wire [AXI_ID_WIDTH-1:0]    b_id;
    wire [1:0]                 b_resp;
    wire [USER_WIDTH-1:0]      b_user;
    wire                       b_valid;
    wire                       b_ready;

    wire [AXI_ID_WIDTH-1:0]    ar_id;
    wire [ADDR_WIDTH-1:0]      ar_addr;
    wire [7:0]                 ar_len;
    wire [2:0]                 ar_size;
    wire [1:0]                 ar_burst;
    wire                       ar_lock;
    wire [3:0]                 ar_cache;
    wire [2:0]                 ar_prot;
    wire [3:0]                 ar_qos;
    wire [3:0]                 ar_region;
    wire [USER_WIDTH-1:0]      ar_user;
    wire                       ar_valid;
    wire                       ar_ready;


    wire [AXI_ID_WIDTH-1:0]    r_id;
    wire [DATA_WIDTH-1:0]      r_data;
    wire [1:0]                 r_resp;
    wire                       r_last;
    wire [USER_WIDTH-1:0]      r_user;
    wire                       r_valid;
    wire                       r_ready; 
    //}}} 
    
    //XBAR_L2 signals
    //{{{

    // ---------------- Master SIDE (Interleaved) --------------------------
    wire                         data_req_HWPE_M;
    wire [ADDR_IN_WIDTH-1:0]     data_add_HWPE_M;
    wire                         data_wen_HWPE_M;
    wire [DATA_WIDTH-1:0]        data_wdata_HWPE_M;
    wire [BE_WIDTH-1:0]          data_be_HWPE_M;
    wire                         data_gnt_HWPE_M;
    wire                         data_r_valid_HWPE_M;
    wire [DATA_WIDTH-1:0]        data_r_rdata_HWPE_M;


    // ---------------- Memeory SIDE (Interleaved) --------------------------
    wire [N_SLAVE-1:0]                            data_req_MEM;            // Data request
    wire [N_SLAVE-1:0][ADDR_MEM_WIDTH-1:0]        data_add_MEM;            // Data request Address
    wire [N_SLAVE-1:0]                            data_wen_MEM;            // Data request type : 0--> Store; 1 --> Load
    wire [N_SLAVE-1:0][DATA_WIDTH-1:0]            data_wdata_MEM;          // Data request Write data
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
    
    //axi_full_master_interface
    //{{{
    AXI_BUS_MASTER #(
        .AXI_ADDR_WIDTH ( ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( DATA_WIDTH     ),
        .AXI_ID_WIDTH   ( ID_WIDTH ),
        .AXI_USER_WIDTH ( USER_WIDTH     )
    ) axi_full_master_interface();
    
    axi_bus_master_driver_class #(
		.DATA_WIDTH	       (DATA_WIDTH	     ),
        .MEM_LENGTH        (MEM_LENGTH),
		.ADDR_WIDTH	       (ADDR_WIDTH	     )
        //.ADDR_BYTE_OFFSET (1) //xilinx ip 时写aw_addr 要有个ADDR_BYTE_OFFSET的偏移量，是DATA_WIDTH / 8，在这里不需要这个偏移。
    ) axi_bus_master_driver = new (
        axi_full_master_interface
    );
    //}}}
    
    //Instantiation of axi_slave_HWPE_M_mem_wrap 
    //{{{
    axi_slave_HWPE_M_mem_wrap #(
		.AXI_ID_WIDTH	        (ID_WIDTH	     ), 
		.AXI_DATA_WIDTH	        (DATA_WIDTH	     ),
        .AXI_AR_FIFO_LENGTH     (8), 
		.AXI_ADDR_WIDTH	        (ADDR_WIDTH	     ) 
    ) AXI_SLAVE_MEM_WRAP (
        //axi slave data
        //{{{
		.AXI_slave_awid         (axi_full_master_interface.aw_id    ),
		.AXI_slave_awaddr       (axi_full_master_interface.aw_addr),
		.AXI_slave_awlen        (axi_full_master_interface.aw_len   ),
		.AXI_slave_awsize       (axi_full_master_interface.aw_size  ),
		.AXI_slave_awburst      (axi_full_master_interface.aw_burst ),
		.AXI_slave_awlock       (axi_full_master_interface.aw_lock  ),
		.AXI_slave_awcache      (axi_full_master_interface.aw_cache ),
		.AXI_slave_awprot       (axi_full_master_interface.aw_prot  ),
		.AXI_slave_awqos        (axi_full_master_interface.aw_qos   ),
		.AXI_slave_awregion     (axi_full_master_interface.aw_region),
		.AXI_slave_awuser       (axi_full_master_interface.aw_user  ),
		.AXI_slave_awvalid      (axi_full_master_interface.aw_valid ),
		.AXI_slave_awready      (axi_full_master_interface.aw_ready ),
		.AXI_slave_wdata        (axi_full_master_interface.w_data    ),
		.AXI_slave_wstrb        (axi_full_master_interface.w_strb    ),
		.AXI_slave_wlast        (axi_full_master_interface.w_last    ),
		.AXI_slave_wuser        (axi_full_master_interface.w_user    ),
		.AXI_slave_wvalid	    (axi_full_master_interface.w_valid   ),
		.AXI_slave_wready	    (axi_full_master_interface.w_ready   ),
		.AXI_slave_bid		    (axi_full_master_interface.b_id	    ),
		.AXI_slave_bresp		(axi_full_master_interface.b_resp	),
		.AXI_slave_buser		(axi_full_master_interface.b_user	),
		.AXI_slave_bvalid	    (axi_full_master_interface.b_valid   ),
		.AXI_slave_bready	    (axi_full_master_interface.b_ready   ),
		.AXI_slave_arid		    (axi_full_master_interface.ar_id	    ),
		.AXI_slave_araddr	    (axi_full_master_interface.ar_addr   ),
		.AXI_slave_arlen		(axi_full_master_interface.ar_len	),
		.AXI_slave_arsize	    (axi_full_master_interface.ar_size   ),
		.AXI_slave_arburst	    (axi_full_master_interface.ar_burst  ),
		.AXI_slave_arlock	    (axi_full_master_interface.ar_lock   ),
		.AXI_slave_arcache	    (axi_full_master_interface.ar_cache  ),
		.AXI_slave_arprot	    (axi_full_master_interface.ar_prot   ),
		.AXI_slave_arqos		(axi_full_master_interface.ar_qos	),
		.AXI_slave_arregion	    (axi_full_master_interface.ar_region ),
		.AXI_slave_aruser	    (axi_full_master_interface.ar_user   ),
		.AXI_slave_arvalid	    (axi_full_master_interface.ar_valid  ),
		.AXI_slave_arready	    (axi_full_master_interface.ar_ready  ),
		.AXI_slave_rid		    (axi_full_master_interface.r_id	    ),
		.AXI_slave_rdata		(axi_full_master_interface.r_data	),
		.AXI_slave_rresp		(axi_full_master_interface.r_resp	),
		.AXI_slave_rlast		(axi_full_master_interface.r_last	),
		.AXI_slave_ruser		(axi_full_master_interface.r_user	),
		.AXI_slave_rvalid	    (axi_full_master_interface.r_valid   ),
		.AXI_slave_rready	    (axi_full_master_interface.r_ready   ),
        //}}}


        .HWPE_M_data_req_o      ( data_req_HWPE_M                    ),     
        .HWPE_M_data_add_o      ( data_add_HWPE_M                    ),
        .HWPE_M_data_wen_o      ( data_wen_HWPE_M                    ),
        .HWPE_M_data_wdata_o    ( data_wdata_HWPE_M[DATA_WIDTH-1:0]  ),
        .HWPE_M_data_be_o       ( data_be_HWPE_M[BE_WIDTH-1:0]       ),
        .HWPE_M_data_gnt_i      ( data_gnt_HWPE_M                    ),
        .HWPE_M_data_r_valid_i  ( data_r_valid_HWPE_M                ),
        .HWPE_M_data_r_rdata_i  ( data_r_rdata_HWPE_M[DATA_WIDTH-1:0]),



		.clk                    (clk),
		.rst_n                  (rst_n)
    ); 
    //}}}

    //instantiation of XBAR_L2 wrap
    one_master_two_slave_XBAR_L2_wrap
    //{{{
    #(
        .N_MASTER       ( N_CH0           ), // = 1,  //--> Debug, UdmaTX, UdmaRX, IcacheR5, DataR5
        .N_SLAVE        ( N_SLAVE         ), // = 2,
        .ID_WIDTH       ( N_CH0           ), // = N_CH0,
        .ADDR_WIDTH     ( ADDR_WIDTH      ), // = 32,
        .DATA_WIDTH     ( DATA_WIDTH      ), // = 32,
        .BE_WIDTH       ( BE_WIDTH        ), // = DATA_WIDTH/8,
        .ADDR_MEM_WIDTH ( ADDR_MEM_WIDTH  )
    )
    DUT_i
    (
        // ---------------- MASTER CH0 SIDE  --------------------------
        .data_req_M_i_0             ( data_req_HWPE_M     ), // Data request
        .data_add_M_i_0             ( data_add_HWPE_M     ), // Data request Address
        .data_wen_M_i_0             ( data_wen_HWPE_M     ), // Data request type : 0--> Store 1 --> Load
        .data_wdata_M_i_0           ( data_wdata_HWPE_M[DATA_WIDTH-1:0]   ), // Data request Write data
        .data_be_M_i_0              ( data_be_HWPE_M[BE_WIDTH-1:0]      ), // Data request Byte enable
        .data_gnt_M_o_0             ( data_gnt_HWPE_M     ), // Grant Incoming Request
        .data_r_valid_M_o_0         ( data_r_valid_HWPE_M ), // Data Response Valid (For LOAD/STORE commands)
        .data_r_rdata_M_o_0         ( data_r_rdata_HWPE_M[DATA_WIDTH-1:0] ), // Data Response DATA (For LOAD commands)

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
    HWPE_M_BRAM_S_wrap_single
    #(
        .ID_WIDTH       ( ID_WIDTH        ), // = N_CH0,
        .ADDR_WIDTH     ( ADDR_MEM_WIDTH      ), // = 32,
        .DATA_WIDTH     ( DATA_WIDTH      )  // = 32,
    ) BRAM_WRAP_0 (
        .HWPE_M_data_req_i      ( data_req_MEM[0]                     ), 
        .HWPE_M_data_add_i      ( data_add_MEM[0][ADDR_MEM_WIDTH-1:0] ), 
        .HWPE_M_data_wen_i      ( data_wen_MEM[0]                     ), 
        .HWPE_M_data_wdata_i    ( data_wdata_MEM[0][DATA_WIDTH-1:0]   ), 
        .HWPE_M_data_be_i       ( data_be_MEM[0][BE_WIDTH-1:0]        ), 
        .HWPE_M_data_ID_i       ( data_ID_MEM[0]                      ), 
        .HWPE_M_data_r_valid_o  ( data_r_valid_MEM[0]                 ), 
        .HWPE_M_data_r_rdata_o  ( data_r_rdata_MEM[0][DATA_WIDTH-1:0] ), 
        .HWPE_M_data_r_ID_o     ( data_r_ID_MEM[0]                    ),
         
        .BRAM_S_ADDRA_o         (ADDRA[0][ADDR_MEM_WIDTH - 1 : 0]         ),
        .BRAM_S_DINA_o          (DINA[0][DATA_WIDTH - 1 : 0]              ),
        .BRAM_S_DOUTA_i         (DOUTA[0][DATA_WIDTH - 1 : 0]             ),
        .BRAM_S_ENA_o           (ENA[0]),
        .BRAM_S_WEA_o           (WEA[0]),
        
        .clk                    ( clk                 ),
        .rst_n                  ( rst_n               )
    );
    
    HWPE_M_BRAM_S_wrap_single
    #(
        .ID_WIDTH       ( ID_WIDTH        ), // = N_CH0,
        .ADDR_WIDTH     ( ADDR_MEM_WIDTH      ), // = 12,
        .DATA_WIDTH     ( DATA_WIDTH      )  // = 32,
    ) BRAM_WRAP_1 (
        .HWPE_M_data_req_i      ( data_req_MEM[1]                         ),
        .HWPE_M_data_add_i      ( data_add_MEM[1][ADDR_MEM_WIDTH-1:0]     ),
        .HWPE_M_data_wen_i      ( data_wen_MEM[1]                         ),
        .HWPE_M_data_wdata_i    ( data_wdata_MEM[1][DATA_WIDTH-1:0]       ),
        .HWPE_M_data_be_i       ( data_be_MEM[1][BE_WIDTH-1:0]            ),
        .HWPE_M_data_ID_i       ( data_ID_MEM[1]                          ),
        .HWPE_M_data_r_valid_o  ( data_r_valid_MEM[1]                     ),
        .HWPE_M_data_r_rdata_o  ( data_r_rdata_MEM[1][DATA_WIDTH-1:0]     ),
        .HWPE_M_data_r_ID_o     ( data_r_ID_MEM[1]                        ),
         
        .BRAM_S_ADDRA_o         (ADDRA[1][ADDR_MEM_WIDTH - 1 : 0]         ),
        .BRAM_S_DINA_o          (DINA[1][DATA_WIDTH - 1 : 0]              ),
        .BRAM_S_DOUTA_i         (DOUTA[1][DATA_WIDTH - 1 : 0]             ),
        .BRAM_S_ENA_o           (ENA[1]),
        .BRAM_S_WEA_o           (WEA[1]),
        
        .clk                    ( clk                 ),
        .rst_n                  ( rst_n               )
    );
    //}}}

    //instantiation of BRAM
    //{{{ 
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
    //}}}


initial begin
    int i;
    bit[31:0] addr;

    for (i = 0; i < 20; i++) begin
        @(posedge clk);
    end
    addr = 4096;
    
    for (i = 0; i < 20; i++) begin
        input_list[i] = i;
    end
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, addr, 16); 
    
    
    for (i = 0; i < 50; i ++) begin
        @(posedge clk);
    end
    
    axi_bus_master_driver.OUTPUT_DATA_ONE_ROUND(clk, output_list, addr, 20);

    show_list_four_byte (output_list, 0, 20, "output", 8);
    
    for (i = 0; i < 50; i ++) begin
        @(posedge clk);
    end
    
    for (i = 0; i < 20; i ++) begin
        axi_bus_master_driver.OUTPUT_DATA_ONE_ROUND(clk, output_list, i + addr, 1);

        show_list_four_byte (output_list, 0, 1, "output", 8);
    
        @(posedge clk);
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
