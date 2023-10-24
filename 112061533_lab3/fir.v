`timescale 1ns / 1ps

module fir
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,    
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 
    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);
reg awready_reg;
reg wready_reg;
reg arready_reg;
reg rvalid_reg;
reg [(pDATA_WIDTH-1):0] rdata_reg;
reg ss_tready_reg;
reg [(pDATA_WIDTH-1):0] sm_tdata_reg;
reg sm_tlast_reg;
reg sm_tvalid_reg;
reg [3:0] tap_WE_reg;
reg tap_EN_reg;
reg [(pDATA_WIDTH-1):0] tap_Di_reg;
reg [(pADDR_WIDTH-1):0] tap_A_reg;
reg [3:0] data_WE_reg;
reg data_EN_reg;
reg [(pDATA_WIDTH-1):0] data_Di_reg;
reg [(pADDR_WIDTH-1):0] data_A_reg;

reg [2:0] config_reg;
reg [31:0] data_length;
reg [3:0] curr_state;
reg [3:0] next_state;
reg [31:0] mult_do;
reg [31:0] data_counter;
reg [(pADDR_WIDTH-1):0] data_A_temp;
reg [(pADDR_WIDTH-1):0] tap_A_temp;
reg [(pDATA_WIDTH-1):0] write_temp;
reg [(pDATA_WIDTH-1):0] read_temp;
reg signed [(pDATA_WIDTH-1):0] result_r;
parameter axilite_w      = 0;
parameter axilite_addr_r = 1;
parameter axilite_data_r = 2;
parameter start          = 3;
parameter stream_init    = 4;
parameter stream_addr_r  = 5;
parameter stream_data_r  = 6;
parameter stream_data_w  = 7;
parameter result_addr    = 8;
parameter result_data    = 9;
parameter final_stage    = 10;

assign awready = awready_reg;
assign wready = wready_reg;
assign arready= arready_reg;
assign rvalid= rvalid_reg;
assign rdata= rdata_reg;
assign ss_tready= ss_tready_reg;
assign sm_tdata= sm_tdata_reg;
assign sm_tlast= sm_tlast_reg;
assign sm_tvalid= sm_tvalid_reg;
assign tap_WE= tap_WE_reg;
assign tap_EN= tap_EN_reg;
assign tap_Di= tap_Di_reg;
assign tap_A= tap_A_reg;
assign data_WE= data_WE_reg;
assign data_EN= data_EN_reg;
assign data_Di= data_Di_reg;
assign data_A= data_A_reg;



always@(posedge axis_clk or negedge axis_rst_n)
begin
	if (~axis_rst_n) begin
		curr_state <= axilite_w;
		data_A_reg <= 0;
	end
	else begin
		curr_state <= next_state;
		data_A_reg <= data_A_temp;
	end
end


always@(*)
begin
    if (~axis_rst_n) begin
			config_reg = 3'b100;
			awready_reg = 1'd0;
			wready_reg= 1'd0;
			ss_tready_reg = 1'd0;
			data_A_temp = 12'h000;
			tap_A_temp = 12'h000;
			data_counter = 32'd0;
			sm_tvalid_reg = 0;
			sm_tlast_reg = 0;
			sm_tdata_reg = 0;
			result_r = 0;
			next_state = axilite_w;
	end
	else begin
	case (curr_state)	
		axilite_w:
		begin
			if (awvalid && awaddr>=12'h20 && awaddr<=12'hFF) begin
				awready_reg = 1'd1;
				wready_reg = 1'd1;
				tap_EN_reg = 1'd1;
				tap_WE_reg = 4'b1111;
				tap_A_reg[3:0] = awaddr[3:0];
	    			tap_A_reg[7:4] = awaddr[7:4] - 4'b0010;
	    			tap_A_reg[11:8] = awaddr[11:8];
	    			tap_Di_reg = wdata;
			end
			else if (awvalid && wvalid && awaddr == 12'h10) begin
				awready_reg = 1'd1;
				wready_reg = 1'd1;
				data_length = wdata;
			end
				
			if (tap_A_reg == 12'h028) next_state = axilite_addr_r;
			else next_state = axilite_w;
			sm_tdata_reg = 0;
			result_r = 0;
		end
		
		axilite_addr_r:
		begin
			if (arvalid && awaddr>=12'h20 && awaddr<=12'hFF) begin
				rvalid_reg = 0;
				tap_EN_reg = 1'd1;
				tap_WE_reg = 4'b0000;
				tap_A_reg[3:0] = araddr[3:0];
		        	tap_A_reg[7:4] = araddr[7:4]- 4'b0010;
		        	tap_A_reg[11:8] = araddr[11:8];
		        	next_state = axilite_data_r;
		        end
		     	sm_tdata_reg = 0;
		     	result_r = 0;
		end
		
		axilite_data_r:
		begin
			if (rready == 1'd1) begin
				rvalid_reg = 1'd1;
				tap_EN_reg = 1'd1;
				rdata_reg = tap_Do;	
			end
			if (tap_A_reg == 12'h028) next_state = start;
			else next_state = axilite_addr_r;
			sm_tdata_reg = 0;
			result_r = 0;
		end
		
		start:
		begin
			if (awvalid && wvalid && awaddr == 12'h00) begin 
				config_reg = wdata[2:0];
				rdata_reg = config_reg[2];
			end	
			if (config_reg == 3'b100) next_state = start;
			else if (config_reg == 3'b001) next_state = stream_init;
			sm_tdata_reg = 0;
			result_r = 0;
		end
		
		stream_init:
		begin
			config_reg = 3'b000;
			data_EN_reg = 1'b1;
			data_WE_reg = 4'b1111;
			data_Di_reg = 32'd0;
			if (data_A_reg == 12'h028) begin
				next_state = stream_addr_r;
				data_A_temp = 12'h000;
			end
			else begin
				next_state = stream_init;
				data_A_temp = data_A_temp + 12'h004;
			end
			sm_tdata_reg = 0;
			result_r = 0;
		end
		
		stream_addr_r:
		begin
			ss_tready_reg = 0;
			sm_tvalid_reg = 0;
			sm_tdata_reg = 0;
			result_r = 0;
			data_EN_reg = 1'b1;
			data_WE_reg = 4'b0000;
			if (data_counter == data_length) begin
				next_state = final_stage;
 				sm_tlast_reg = 1;
 			end
			else next_state = stream_data_r;
		end
		
		stream_data_r:
		begin
			read_temp = data_Do;
			next_state = stream_data_w;
			sm_tdata_reg = 0;
			result_r = 0;
		end
		
		stream_data_w:
		begin
			data_WE_reg = 4'b1111;
			if (data_A_reg == 12'h000) begin
				if (ss_tvalid==1 && ss_tlast==0) begin
					ss_tready_reg = 1;
					write_temp = read_temp;
					data_Di_reg = ss_tdata;
				end
				else if (ss_tlast == 1) begin
					write_temp = read_temp;
					data_Di_reg = ss_tdata;
				end
			end
			else begin
				data_Di_reg = write_temp;
				write_temp = read_temp;
			end
			if (data_A_reg == 12'h028) begin
				next_state = result_addr;
				data_A_temp = 12'h000;
			end
			else begin
				next_state = stream_addr_r;
				data_A_temp = data_A_temp + 12'h004;
			end
			sm_tdata_reg = 0;
			result_r = 0;
		end
		
		result_addr:
		begin
			data_WE_reg = 4'b0000;
			data_EN_reg = 1'b1;	
			rvalid_reg = 0;
		    	tap_WE_reg = 4'b0000;
		    	tap_EN_reg = 1'b1;
            		arready_reg = 1'b1;
		    	result_r = sm_tdata_reg; 
		    	tap_A_reg = tap_A_temp;
			next_state = result_data;
			sm_tdata_reg = 0;
		end
 		result_data:
 		begin
 			data_WE_reg = 4'b0000;
			data_EN_reg = 1'b1;
			tap_WE_reg = 4'b0000;
		    	tap_EN_reg = 1'b1;
		    	if (rready == 1) rvalid_reg = 1; 
		    	sm_tdata_reg = result_r + data_Do * tap_Do; 
			if (data_A_reg == 12'h028) begin 
	        		if (sm_tready) sm_tvalid_reg = 1'b1;
	        		if (data_counter == data_length) sm_tlast_reg = 1'd1;			
 				next_state = stream_addr_r;
	        		data_counter = data_counter + 1;
	        		data_A_temp = 12'h000;
	        		tap_A_temp  = 12'h000;
	        	end 
			else begin
				next_state = result_addr;
				data_A_temp = data_A_temp + 12'h004;
				tap_A_temp = tap_A_temp + 12'h004;
			end
            		result_r = 0;
 		end
 		
 		final_stage:
 		begin
 			 if (config_reg[2:1]== 2'b01) begin
 				rvalid_reg = 1;
 				config_reg[2:1]= 2'b10;
 				rdata_reg = config_reg;
 				next_state = axilite_w;
			 end	
 			 else begin
 			 	config_reg[2:1]= 2'b01;
 			 	rdata_reg = config_reg;
 			 	next_state = final_stage; 
 			 end
 			 sm_tdata_reg = 0;	
 			 result_r = 0;				
 		end
 		default:
 		begin
 		      sm_tdata_reg = 0;
 		      result_r = 0;
 		end		
	endcase

    end
end
endmodule
