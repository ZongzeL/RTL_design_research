
`timescale 1 ns / 1 ps
longint unsigned ns_counter;
longint unsigned clock_counter;
module fifo_tb #(


    parameter integer DATA_BITS = 11, //same as C_AXI_Full_data_OPT_MEM_ADDR_BITS
    parameter integer FIFO_LENGTH 	= 16, 



    parameter TB_RESET_VALUE = 0

);

    //wire
    wire [DATA_BITS - 1 : 0]output_data;    
    wire read;
    wire empty;
    wire full;



    //reg
    reg [DATA_BITS - 1 : 0]input_data;
    reg write;    

    reg [DATA_BITS - 1 : 0]data_buffer;
    reg [DATA_BITS - 1 : 0]data_expect;

    reg reset;
    reg clk = 1'b0;

    //assign
    assign read = (output_data == data_expect && empty != 1) ? 1 : 0;


    fifo #(
        .DATA_BITS (DATA_BITS),
        .FIFO_LENGTH (FIFO_LENGTH)
    ) addr_fifo (
        .input_data (input_data),
        .output_data (output_data),
        
        .read(read),
        .write(write),
        .empty(empty),
        .full(full),


        .clk(clk),
        .reset (reset)
    );




task write_data (bit[DATA_BITS - 1 : 0] data);
begin
    input_data <= data;
    write <= 1; 
    @(posedge clk);
    input_data <= 10'b11_1111_1111;
    write <= 0; 
end
endtask


initial begin
    int i, j;

    input_data = 10'b11_1111_1111;

    @(posedge clk);
    @(posedge clk);
    while (reset == TB_RESET_VALUE) begin
        @(posedge clk);
    end

    @(posedge clk);
    @(posedge clk);

    for (i = 0; i < 10; i ++) begin
        write_data(i);
    end
    
    @(posedge clk);
    
    for (i = 0; i < 10; i ++) begin
        write_data(i + 5);
    end


end


always@(posedge clk) begin
    if (empty != 1) begin
        $display ("read_data: %d", output_data);
    end
end

always@(posedge clk) begin
    data_buffer <= input_data;
end

always@(posedge clk) begin
    data_expect <= data_buffer;
end


//reset
//{{{
initial begin
    reset = TB_RESET_VALUE;
    #20;
    reset = ~TB_RESET_VALUE;
    //messager.dump_message("sim start");
    //#500000;
    #1000;
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
