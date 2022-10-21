
`timescale 1 ns / 1 ps
longint unsigned ns_counter;
longint unsigned clock_counter;

module pure_axi_test_tb #(
    // Parameters of Axi Slave Bus Interface AXI_data
    parameter integer AXI_ID_WIDTH	= 2,
    parameter integer AXI_DATA_WIDTH	= 32,
    parameter integer AXI_ADDR_WIDTH	= 32,
    parameter integer AXI_USER_WIDTH	= 10,
    
    parameter integer AXI_MEM_LENGTH	= 32,
    parameter integer ADDR_LSB          = 2, 

    parameter TB_RESET_VALUE = 0
);

    //reg    
    reg reset;
    reg clk = 1'b0;


    //sim use
    bit [AXI_DATA_WIDTH - 1 : 0] all_input_list [256];


    //AXI master wires
    //{{{
    wire [AXI_ID_WIDTH-1:0]    master_aw_id;
    wire [AXI_ADDR_WIDTH-1:0]  master_aw_addr;
    wire [7:0]                 master_aw_len;
    wire [2:0]                 master_aw_size;
    wire [1:0]                 master_aw_burst;
    wire                       master_aw_lock;
    wire [3:0]                 master_aw_cache;
    wire [2:0]                 master_aw_prot;
    wire [3:0]                 master_aw_qos;
    wire [3:0]                 master_aw_region;
    wire [AXI_USER_WIDTH-1:0]  master_aw_user;
    wire                       master_aw_valid;
    wire                       master_aw_ready;

    wire [AXI_DATA_WIDTH-1:0]  master_w_data;
    wire [3:0]                 master_w_strb;
    wire                       master_w_last;
    wire [AXI_USER_WIDTH-1:0]  master_w_user;
    wire                       master_w_valid;
    wire                       master_w_ready;
    wire [AXI_ID_WIDTH-1:0]    master_w_id;
    
    wire [AXI_ID_WIDTH-1:0]    master_b_id;
    wire [1:0]                 master_b_resp;
    wire [AXI_USER_WIDTH-1:0]  master_b_user;
    wire                       master_b_valid;
    wire                       master_b_ready;

    wire [AXI_ID_WIDTH-1:0]    master_ar_id;
    wire [AXI_ADDR_WIDTH-1:0]  master_ar_addr;
    wire [7:0]                 master_ar_len;
    wire [2:0]                 master_ar_size;
    wire [1:0]                 master_ar_burst;
    wire                       master_ar_lock;
    wire [3:0]                 master_ar_cache;
    wire [2:0]                 master_ar_prot;
    wire [3:0]                 master_ar_qos;
    wire [3:0]                 master_ar_region;
    wire [AXI_USER_WIDTH-1:0]  master_ar_user;
    wire                       master_ar_valid;
    wire                       master_ar_ready;


    wire [AXI_ID_WIDTH-1:0]    master_r_id;
    wire [AXI_DATA_WIDTH-1:0]  master_r_data;
    wire [1:0]                 master_r_resp;
    wire                       master_r_last;
    wire [AXI_USER_WIDTH-1:0]  master_r_user;
    wire                       master_r_valid;
    wire                       master_r_ready; 
    //}}} 
    
    int i, j;
    
    bit [31:0] input_addr;
    bit [31:0] output_addr;
    
    bit[31:0] tmp;

    bit [AXI_DATA_WIDTH - 1 : 0] input_list [256];
    bit [AXI_DATA_WIDTH - 1 : 0] output_list [256];
    bit [AXI_DATA_WIDTH - 1 : 0] golden_list [256];
    
    //axi_full_master_interface
    //{{{
    AXI_BUS_MASTER #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH     ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
    ) axi_full_master_interface();
    
    axi_bus_master_driver_class #(
		.DATA_WIDTH	       (AXI_DATA_WIDTH	     ),
        .MEM_LENGTH        (AXI_MEM_LENGTH),
		.ADDR_WIDTH	       (AXI_ADDR_WIDTH	     )
        //.ADDR_BYTE_OFFSET (1) //xilinx ip 时写aw_addr 要有个ADDR_BYTE_OFFSET的偏移量，是DATA_WIDTH / 8，在这里不需要这个偏移。
    ) axi_bus_master_driver = new (
        axi_full_master_interface
    );
    //}}}

    //Instantiation of top_device 
    //{{{
    TOP_device #(
		.AXI_ID_WIDTH	        (AXI_ID_WIDTH	     ), 
		.AXI_DATA_WIDTH	        (AXI_DATA_WIDTH	     ), 
		.AXI_ADDR_WIDTH	        (AXI_ADDR_WIDTH	     ),
		.ADDR_MASTER_OFFSET     ('h400               )

 
    ) TOP_DEVICE (
        //axi slave data
        //{{{
		.AXI_slave_awid             (axi_full_master_interface.aw_id     ),
		.AXI_slave_awaddr           (axi_full_master_interface.aw_addr   ),
		.AXI_slave_awlen            (axi_full_master_interface.aw_len    ),
		.AXI_slave_awsize           (axi_full_master_interface.aw_size   ),
		.AXI_slave_awburst          (axi_full_master_interface.aw_burst  ),
		.AXI_slave_awlock           (axi_full_master_interface.aw_lock   ),
		.AXI_slave_awcache          (axi_full_master_interface.aw_cache  ),
		.AXI_slave_awprot           (axi_full_master_interface.aw_prot   ),
		.AXI_slave_awqos            (axi_full_master_interface.aw_qos    ),
		.AXI_slave_awregion         (axi_full_master_interface.aw_region ),
		.AXI_slave_awuser           (axi_full_master_interface.aw_user   ),
		.AXI_slave_awvalid          (axi_full_master_interface.aw_valid  ),
		.AXI_slave_awready          (axi_full_master_interface.aw_ready  ),
		.AXI_slave_wdata            (axi_full_master_interface.w_data    ),
		.AXI_slave_wstrb            (axi_full_master_interface.w_strb    ),
		.AXI_slave_wlast            (axi_full_master_interface.w_last    ),
		.AXI_slave_wuser            (axi_full_master_interface.w_user    ),
		.AXI_slave_wvalid	        (axi_full_master_interface.w_valid   ),
		.AXI_slave_wready	        (axi_full_master_interface.w_ready   ),
		.AXI_slave_bid		        (axi_full_master_interface.b_id	     ),
		.AXI_slave_bresp		    (axi_full_master_interface.b_resp	 ),
		.AXI_slave_buser		    (axi_full_master_interface.b_user	 ),
		.AXI_slave_bvalid	        (axi_full_master_interface.b_valid   ),
		.AXI_slave_bready	        (axi_full_master_interface.b_ready   ),
		.AXI_slave_arid		        (axi_full_master_interface.ar_id	 ),
		.AXI_slave_araddr	        (axi_full_master_interface.ar_addr   ),
		.AXI_slave_arlen		    (axi_full_master_interface.ar_len	 ),
		.AXI_slave_arsize	        (axi_full_master_interface.ar_size   ),
		.AXI_slave_arburst	        (axi_full_master_interface.ar_burst  ),
		.AXI_slave_arlock	        (axi_full_master_interface.ar_lock   ),
		.AXI_slave_arcache	        (axi_full_master_interface.ar_cache  ),
		.AXI_slave_arprot	        (axi_full_master_interface.ar_prot   ),
		.AXI_slave_arqos		    (axi_full_master_interface.ar_qos	 ),
		.AXI_slave_arregion	        (axi_full_master_interface.ar_region ),
		.AXI_slave_aruser	        (axi_full_master_interface.ar_user   ),
		.AXI_slave_arvalid	        (axi_full_master_interface.ar_valid  ),
		.AXI_slave_arready	        (axi_full_master_interface.ar_ready  ),
		.AXI_slave_rid		        (axi_full_master_interface.r_id	     ),
		.AXI_slave_rdata		    (axi_full_master_interface.r_data	 ),
		.AXI_slave_rresp		    (axi_full_master_interface.r_resp	 ),
		.AXI_slave_rlast		    (axi_full_master_interface.r_last	 ),
		.AXI_slave_ruser		    (axi_full_master_interface.r_user	 ),
		.AXI_slave_rvalid	        (axi_full_master_interface.r_valid   ),
		.AXI_slave_rready	        (axi_full_master_interface.r_ready   ),
		//}}}

        //axi master data
        //{{{
		.AXI_master_awid         (master_aw_id    ),
		.AXI_master_awaddr       (master_aw_addr),
		.AXI_master_awlen        (master_aw_len   ),
		.AXI_master_awsize       (master_aw_size  ),
		.AXI_master_awburst      (master_aw_burst ),
		.AXI_master_awlock       (master_aw_lock  ),
		.AXI_master_awcache      (master_aw_cache ),
		.AXI_master_awprot       (master_aw_prot  ),
		.AXI_master_awqos        (master_aw_qos   ),
		.AXI_master_awregion     (master_aw_region),
		.AXI_master_awuser       (master_aw_user  ),
		.AXI_master_awvalid      (master_aw_valid ),
		.AXI_master_awready      (master_aw_ready ),
		.AXI_master_wdata        (master_w_data    ),
		.AXI_master_wstrb        (master_w_strb    ),
		.AXI_master_wlast        (master_w_last    ),
		.AXI_master_wuser        (master_w_user    ),
		.AXI_master_wvalid	     (master_w_valid   ),
		.AXI_master_wready	     (master_w_ready   ),
		.AXI_master_bid		     (master_b_id	    ),
		.AXI_master_bresp		 (master_b_resp	),
		.AXI_master_buser		 (master_b_user	),
		.AXI_master_bvalid	     (master_b_valid   ),
		.AXI_master_bready	     (master_b_ready   ),
		.AXI_master_arid		 (master_ar_id	    ),
		.AXI_master_araddr	     (master_ar_addr   ),
		.AXI_master_arlen		 (master_ar_len	),
		.AXI_master_arsize	     (master_ar_size   ),
		.AXI_master_arburst	     (master_ar_burst  ),
		.AXI_master_arlock	     (master_ar_lock   ),
		.AXI_master_arcache	     (master_ar_cache  ),
		.AXI_master_arprot	     (master_ar_prot   ),
		.AXI_master_arqos		 (master_ar_qos	),
		.AXI_master_arregion	 (master_ar_region ),
		.AXI_master_aruser	     (master_ar_user   ),
		.AXI_master_arvalid	     (master_ar_valid  ),
		.AXI_master_arready	     (master_ar_ready  ),
		.AXI_master_rid		     (master_r_id	    ),
		.AXI_master_rdata		 (master_r_data	),
		.AXI_master_rresp		 (master_r_resp	),
		.AXI_master_rlast		 (master_r_last	),
		.AXI_master_ruser		 (master_r_user	),
		.AXI_master_rvalid	     (master_r_valid   ),
		.AXI_master_rready	     (master_r_ready   ),
        //}}}

        .clk                    (clk),
		.rst_n                  (reset)
        //}}}
        
    ); 
    //}}}

    //Instantiation of axi_slave_mem_device  
    //{{{
    axi_slave_mem_device #(
		.AXI_ID_WIDTH	        (AXI_ID_WIDTH	     ), 
		.AXI_DATA_WIDTH	        (AXI_DATA_WIDTH	     ), 
		.AXI_ADDR_WIDTH	        (AXI_ADDR_WIDTH	     ),
        .ADDR_BASE_OFFSET       ('h400) 
    ) AXI_SLAVE_MEM_DEVICE (
        //axi slave data
        //{{{
		.AXI_slave_awid         (master_aw_id    ),
		.AXI_slave_awaddr       (master_aw_addr),
		.AXI_slave_awlen        (master_aw_len   ),
		.AXI_slave_awsize       (master_aw_size  ),
		.AXI_slave_awburst      (master_aw_burst ),
		.AXI_slave_awlock       (master_aw_lock  ),
		.AXI_slave_awcache      (master_aw_cache ),
		.AXI_slave_awprot       (master_aw_prot  ),
		.AXI_slave_awqos        (master_aw_qos   ),
		.AXI_slave_awregion     (master_aw_region),
		.AXI_slave_awuser       (master_aw_user  ),
		.AXI_slave_awvalid      (master_aw_valid ),
		.AXI_slave_awready      (master_aw_ready ),
		.AXI_slave_wdata        (master_w_data    ),
		.AXI_slave_wstrb        (master_w_strb    ),
		.AXI_slave_wlast        (master_w_last    ),
		.AXI_slave_wuser        (master_w_user    ),
		.AXI_slave_wvalid	    (master_w_valid   ),
		.AXI_slave_wready	    (master_w_ready   ),
		.AXI_slave_bid		    (master_b_id	    ),
		.AXI_slave_bresp		(master_b_resp	),
		.AXI_slave_buser		(master_b_user	),
		.AXI_slave_bvalid	    (master_b_valid   ),
		.AXI_slave_bready	    (master_b_ready   ),
		.AXI_slave_arid		    (master_ar_id	    ),
		.AXI_slave_araddr	    (master_ar_addr   ),
		.AXI_slave_arlen		(master_ar_len	),
		.AXI_slave_arsize	    (master_ar_size   ),
		.AXI_slave_arburst	    (master_ar_burst  ),
		.AXI_slave_arlock	    (master_ar_lock   ),
		.AXI_slave_arcache	    (master_ar_cache  ),
		.AXI_slave_arprot	    (master_ar_prot   ),
		.AXI_slave_arqos		(master_ar_qos	),
		.AXI_slave_arregion	    (master_ar_region ),
		.AXI_slave_aruser	    (master_ar_user   ),
		.AXI_slave_arvalid	    (master_ar_valid  ),
		.AXI_slave_arready	    (master_ar_ready  ),
		.AXI_slave_rid		    (master_r_id	    ),
		.AXI_slave_rdata		(master_r_data	),
		.AXI_slave_rresp		(master_r_resp	),
		.AXI_slave_rlast		(master_r_last	),
		.AXI_slave_ruser		(master_r_user	),
		.AXI_slave_rvalid	    (master_r_valid   ),
		.AXI_slave_rready	    (master_r_ready   ),

		.clk                    (clk),
		.rst_n                  (reset)

        //}}}
        
    ); 
    //}}}



initial begin
    

    while (reset == TB_RESET_VALUE) begin
        @(posedge clk);
    end

    @(posedge clk);
    @(posedge clk);

    for (i = 0; i < 16; i ++) begin
        input_list[i] = i;
    end

    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    
    input_addr = 0;
    output_addr = 0;
    

    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, input_addr, 16);

    axi_bus_master_driver.OUTPUT_DATA_ONE_ROUND(clk, output_list, output_addr, 16);
    show_list_four_byte (output_list, 0, 16, "output", 8);
    write_slave_mem_opt_1();
    read_slave_mem_opt_2();

    


end

task write_slave_mem_opt_1();
//{{{ 
begin
    tmp = 32'b0;
    tmp[1:0] = 1;
    tmp[3:2] = 2'b01;
    tmp[31:24] = 8'd15;
    input_list[0] = 'h0; // input_st
    input_list[1] = 'h400; // slave_mem input_st
    

    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, input_addr + ('h104 >> 2), 2); //config: src and dst
    input_list[0] = tmp; // input_st
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, input_addr + ('h100 >> 2), 1); //config start trigger

    for (i = 0; i < 50; i ++) begin
        @(posedge clk);
    end
end
endtask
//}}}

task read_slave_mem_opt_1();
//{{{
begin
    tmp = 32'b0;
    tmp[1:0] = 2'b10; //read
    tmp[3:2] = 2'b01; //burst
    tmp[31:24] = 8'd15; //len
    input_list[0] = 'h400; //src slave mem input_st
    input_list[1] = 'h200; //dst top device out data
 
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, input_addr + ('h104 >> 2), 2); //config: src and dst
    input_list[0] = tmp; // input_st
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, input_addr + ('h100 >> 2), 1); //config start trigger
   
    for (i = 0; i < 50; i ++) begin
        @(posedge clk);
    end

    input_list[0] = 'h200 + 4 * 4; //dst
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, input_addr + ('h108 >> 2), 1); //config: only change dst
    input_list[0] = tmp; // input_st
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, input_addr + ('h100 >> 2), 1); //config start trigger

    for (i = 0; i < 50; i ++) begin
        @(posedge clk);
    end

    axi_bus_master_driver.OUTPUT_DATA_ONE_ROUND(clk, output_list, ('h200 >> 2), 20);
    show_list_four_byte (output_list, 0, 20, "output", 8);
end
endtask
//}}}

task read_slave_mem_opt_2();
//{{{
begin
    tmp = 32'b0;
    tmp[1:0] = 2'b10; //read
    tmp[3:2] = 2'b01; //burst
    tmp[31:24] = 8'd15; //len
    input_list[0] = 'h400; //src slave mem input_st
    input_list[1] = 'h200; //dst top device out data
 
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, input_addr + ('h104 >> 2), 2); //config: src and dst
    input_list[0] = tmp; // input_st
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, input_addr + ('h100 >> 2), 1); //config start trigger
   
    for (i = 0; i < 50; i ++) begin
        @(posedge clk);
    end

    axi_bus_master_driver.OUTPUT_DATA_ONE_ROUND(clk, output_list, ('h200 >> 2), 20);
    show_list_four_byte (output_list, 0, 20, "output", 8);
end
endtask
//}}}

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
