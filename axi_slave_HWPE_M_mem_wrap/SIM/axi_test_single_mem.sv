/*
所谓的single_mem，就是地址下标以1为offset向前推，有两个特点：
1. memory 的addr是log2位的
2. 以addr以1为offset向前推
3. WEN只有1bit
xilinx 的bram ip设置里，要把Generate address interface with 32 bits那个框《不点》！
如果点了，就变成了Byte Write Enable默认也点了。

*/

//axi_test.sv_use_master_module

`timescale 1 ns / 1 ps
longint unsigned ns_counter;
longint unsigned clock_counter;

module pure_axi_test_tb #(
    // Parameters of Axi Slave Bus Interface AXI_data
    parameter integer ID_WIDTH	= 2,
    parameter integer DATA_WIDTH	= 32,
    parameter integer ADDR_WIDTH	= 10,
    parameter integer BE_WIDTH      = DATA_WIDTH/8,
    parameter integer USER_WIDTH	= 10,
    parameter integer MEM_LENGTH    = $pow(2, ADDR_WIDTH),
    parameter integer data_MEM_LENGTH	= 32,
    
    parameter TB_RESET_VALUE = 0
);

    //reg    
    reg reset;
    reg clk = 1'b0;

    wire data_req_MEM                     ;
    wire [ADDR_WIDTH-1:0] data_add_MEM;
    wire data_wen_MEM                     ;
    wire [DATA_WIDTH-1:0] data_wdata_MEM  ;
    wire [BE_WIDTH-1:0] data_be_MEM       ;
    wire data_gnt_MEM                     ;
    wire data_r_valid_MEM                 ;
    wire [DATA_WIDTH-1:0] data_r_rdata_MEM;

    //sim use
    bit [DATA_WIDTH - 1 : 0] all_input_list [256];
    bit [31:0] input_addr;
    bit [31:0] output_addr;
    
    bit[31:0] tmp;

    bit [DATA_WIDTH - 1 : 0] input_list [256];
    bit [DATA_WIDTH - 1 : 0] output_list [256];
    bit [DATA_WIDTH - 1 : 0] golden_list [256];

    //AXI wires
    //{{{
    wire [ID_WIDTH-1:0]        aw_id;
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
    wire [ID_WIDTH-1:0]        w_id;
    
    wire [ID_WIDTH-1:0]        b_id;
    wire [1:0]                 b_resp;
    wire [USER_WIDTH-1:0]      b_user;
    wire                       b_valid;
    wire                       b_ready;

    wire [ID_WIDTH-1:0]        ar_id;
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


    wire [ID_WIDTH-1:0]        r_id;
    wire [DATA_WIDTH-1:0]      r_data;
    wire [1:0]                 r_resp;
    wire                       r_last;
    wire [USER_WIDTH-1:0]      r_user;
    wire                       r_valid;
    wire                       r_ready; 
    //}}} 
    
    //BRAM signals
    //{{{
    wire [ADDR_WIDTH - 1 : 0]          ADDRA;
    wire [DATA_WIDTH - 1 : 0]          DINA;
    wire [DATA_WIDTH - 1 : 0]          DOUTA;
    wire                               ENA;
    wire                               WEA;
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
    
    //Instantiation of slave_mem_wrap 
    //{{{
    axi_slave_mem_wrap #(
		.AXI_ID_WIDTH	        (ID_WIDTH	     ), 
		.AXI_DATA_WIDTH	        (DATA_WIDTH	     ),
        .AXI_AR_FIFO_LENGTH     (1), 
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


        .data_req_o             ( data_req_MEM                         ),     
        .data_add_o             ( data_add_MEM[ADDR_WIDTH-1:0]     ),
        .data_wen_o             ( data_wen_MEM                         ),
        .data_wdata_o           ( data_wdata_MEM[DATA_WIDTH-1:0]       ),
        .data_be_o              ( data_be_MEM[BE_WIDTH-1:0]            ),
        .data_gnt_i             ( data_gnt_MEM                         ),
        .data_r_valid_i         ( data_r_valid_MEM                     ),
        .data_r_rdata_i         ( data_r_rdata_MEM[DATA_WIDTH-1:0]     ),



		.clk                    (clk),
		.rst_n                  (reset)
    ); 
    //}}}
    
    //instantiation of BRAM_wrap
    //{{{
    BRAM_wrap_single
    #(
        .ID_WIDTH       ( ID_WIDTH        ), // = N_CH0,
        .ADDR_WIDTH     ( ADDR_WIDTH      ), // = 32,
        .DATA_WIDTH     ( DATA_WIDTH      )  // = 32,
    ) BRAM_WRAP_0 (
        .data_req_i             ( data_req_MEM                         ), // Data request
        .data_add_i             ( data_add_MEM[ADDR_WIDTH-1:0]         ), // Data request Address
        .data_wen_i             ( data_wen_MEM                         ), // Data request type : 0--> Store 1 --> Load
        .data_wdata_i           ( data_wdata_MEM[DATA_WIDTH-1:0]       ), // Data request Write data
        .data_be_i              ( data_be_MEM[BE_WIDTH-1:0]            ), // Data request Byte enable
        .data_gnt_o             ( data_gnt_MEM                         ), // Grant Incoming Request
        .data_r_valid_o         ( data_r_valid_MEM                     ), // Data Response Valid (For LOAD/STORE commands)
        .data_r_rdata_o         ( data_r_rdata_MEM[DATA_WIDTH-1:0]     ), // Data Response DATA (For LOAD commands)
         
        .ADDRA_o                (ADDRA[ADDR_WIDTH - 1 : 0]             ),
        .DINA_o                 (DINA[DATA_WIDTH - 1 : 0]              ),
        .DOUTA_i                (DOUTA[DATA_WIDTH - 1 : 0]             ),
        .ENA_o                  (ENA),
        .WEA_o                  (WEA),
        
        .clk                    ( clk                 ),
        .rst_n                  ( reset               )
    );
    //}}}

    //instantiation of BRAM 
    //{{{
    blk_mem_gen_0 #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .MEM_LENGTH ($pow(2, ADDR_WIDTH))
    ) BRAM_0 (
        .ADDRA   (ADDRA[ADDR_WIDTH - 1 : 0]             ),
        .DINA    (DINA[DATA_WIDTH - 1 : 0]              ),
        .DOUTA   (DOUTA[DATA_WIDTH - 1 : 0]             ),
        .ENA     (ENA),
        .WEA     (WEA),
        .CLKA    (clk)
    );
    //}}}

initial begin
    
    int i, j;
    string config_input_hex_file;


    while (reset == TB_RESET_VALUE) begin
        @(posedge clk);
    end

    @(posedge clk);
    @(posedge clk);

    for (i = 0; i < 16; i ++) begin
        input_list[i] = i;
    end


    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, 0, 16); 
    
    
    for (i = 0; i < 50; i ++) begin
        @(posedge clk);
    end
    
    axi_bus_master_driver.OUTPUT_DATA_ONE_ROUND(clk, output_list, 0, 20);

    show_list_four_byte (output_list, 0, 20, "output", 8);
    
    for (i = 0; i < 50; i ++) begin
        @(posedge clk);
    end
    
    for (i = 0; i < 20; i ++) begin
        axi_bus_master_driver.OUTPUT_DATA_ONE_ROUND(clk, output_list, i, 1);

        show_list_four_byte (output_list, 0, 1, "output", 8);
    
        @(posedge clk);
    end


end


//reset
//{{{
initial begin
    reset = TB_RESET_VALUE;
    #20;
    reset = ~TB_RESET_VALUE;
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


endmodule
