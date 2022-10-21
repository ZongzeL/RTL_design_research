`timescale 1 ns / 1 ps

module fifo #
(
    parameter integer DATA_BITS	= 10,
    parameter integer FIFO_LENGTH	= 16,
	parameter ADDR_BIT = $clog2(FIFO_LENGTH),
    
    parameter RESET_VALUE = 0
)
(

	input clk,
	input reset,
	input [DATA_BITS - 1 : 0] input_data,
	output [DATA_BITS - 1 : 0] output_data,
	
	input wire read,
	input wire write,
	output wire empty,
	output wire full


);
    //wire

    //reg
	reg [DATA_BITS - 1 : 0] data_array[FIFO_LENGTH - 1: 0];
	reg flap;
	reg [ADDR_BIT - 1:0] write_addr;
	reg [ADDR_BIT - 1:0] read_addr;	


    //assign
	assign output_data = data_array[read_addr];

	assign full = (write_addr == read_addr && flap == 1) ? 1 : 0; 
	assign empty = (write_addr == read_addr && flap == 0) ? 1 : 0; 

//data_array 
//{{{
always@(posedge clk) begin
    if (write == 1 && full != 1) begin
        data_array[write_addr] <= input_data;
    end
end 
//}}}

//write_addr
//{{{
always@(posedge clk) begin
	if (reset == RESET_VALUE) begin
		write_addr <= 0;
	end
	else begin
		if (write == 1 && full != 1) begin
			if (write_addr == FIFO_LENGTH - 1) begin
				write_addr <= 0;
			end
			else begin
				write_addr <= write_addr + 1;
			end
		end
	end
end 
//}}}

//read_addr
//{{{
always@(posedge clk) begin
	if (reset == RESET_VALUE) begin
		read_addr <= 0;
	end
	else begin
		if (read == 1 && empty != 1) begin
			if (read_addr == FIFO_LENGTH - 1) begin
				read_addr <= 0;
			end
			else begin
				read_addr <= read_addr + 1;
			end
		end

	end
end
//}}}

//flap
//flap == 0: write greater than read
//flap == 1: write less than read
//{{{
always@(posedge clk) begin
	if (reset == RESET_VALUE) begin
		flap <= 0;
	end
	else begin
		if (write == 1 && full != 1) begin
			//write
			if (write_addr == FIFO_LENGTH - 1) begin
				flap <= ~flap;
			end
		end
		if (read == 1 && empty != 1 ) begin
			//read
			if (read_addr == FIFO_LENGTH - 1) begin
				flap <= ~flap;
			end
		end
	end
end 
//}}}

endmodule
