
//arready
//{{{   
always @( posedge clk ) begin
    if ( rst_n == 1'b0 ) begin
        AXI_arready <= 1'b0;
        axi_ar_flag <= 1'b0;
    end 
    else begin    
        if (
            AXI_arready == 1'b0 && 
            AXI_arvalid == 1'b1 && 
            //axi_aw_flag == 1'b0 && 
            axi_ar_flag == 1'b0 &&
            AXI_araddr < ADDR_END &&
            AXI_araddr >= ADDR_ST
        ) begin
            axi_ar_flag <= 1'b1;
        end
        else if (AXI_rlast == 1'b1 && AXI_rready == 1'b1 ) begin
            axi_ar_flag  <= 1'b0;
        end
        if (
            AXI_arready == 1'b0 && 
            AXI_arvalid == 1'b1 && 
            //axi_aw_flag == 1'b0 && 
            axi_ar_flag == 1'b0 && 
            AXI_araddr < ADDR_END &&
            AXI_araddr >= ADDR_ST
        ) begin
            AXI_arready <= 1'b1;
        end
        else begin
            AXI_arready <= 1'b0;
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

