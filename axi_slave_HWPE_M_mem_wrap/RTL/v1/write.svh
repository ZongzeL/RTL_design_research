
//assign memory signals write 
//{{{
assign data_wen_o = write_valid;
assign data_wdata_o = write_data;
assign data_be_o = write_strb;

//}}}

//eight useful signals: write, use ff to buffer wdata
//{{{
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


