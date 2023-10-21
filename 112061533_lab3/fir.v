`timescale 1ns / 1ps

module fir
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    // AXI-WRITE
    output  reg                      awready, // fir can accept the address
    output  reg                      wready, // fir can accept the data
    input   wire                     awvalid, // testbench can transfer write_address to fir
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid, // testbench can transfer write_data to fir
    input   wire [(pDATA_WIDTH-1):0] wdata,
    // AXI-READ
    output  reg                     arready, // fir can read the address from the testbench
    input   wire                     rready, //  testbench can read the data from the fir
    input   wire                     arvalid,//  testbench can transfer read_address to fir
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  reg                     rvalid, //  fir can transfer read_data to testbench
    output  reg [(pDATA_WIDTH-1):0] rdata,  
    // AXI-STREAM input to ram
    input   wire                     ss_tvalid, // tvalid occur need to wait tready
    input   wire [(pDATA_WIDTH-1):0] ss_tdata,  
    input   wire                     ss_tlast,
    output  reg                      ss_tready,
    //AXI-STREAM output
    input   wire                    sm_tready,
    output  reg                    sm_tvalid,
    output  reg [(pDATA_WIDTH-1):0]  sm_tdata,
    output  reg                     sm_tlast,
   
    // bram for tap RAM
    output  reg [3:0]               tap_WE,
    output  reg                     tap_EN,
    output  reg [(pDATA_WIDTH-1):0] tap_Di,
    output  reg [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  reg [3:0]               data_WE,
    output  reg                     data_EN,
    output  reg [(pDATA_WIDTH-1):0] data_Di,
    output  reg [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);

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
reg signed [(pDATA_WIDTH-1):0] next_data,result_r;
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

always@(posedge axis_clk or negedge axis_rst_n)
begin
	if (~axis_rst_n) begin
		curr_state <= axilite_w;
		data_A <= 0;
	end
	else begin
		curr_state <= next_state;
		data_A <= data_A_temp;
	end
end


always@(*)
begin
    if (~axis_rst_n) begin
			config_reg = 3'b100;
			awready = 1'd0;
			wready = 1'd0;
			ss_tready = 1'd0;
			data_A_temp = 12'h000;
			tap_A_temp = 12'h000;
			data_counter = 32'd0;
			sm_tvalid = 0;
			sm_tlast = 0;
			sm_tdata = 0;
			result_r = 0;
			next_state = axilite_w;
	end
	else begin
	case (curr_state)	
		axilite_w:
		begin
			if (awvalid && awaddr>=12'h20 && awaddr<=12'hFF) begin
				awready = 1'd1;
				wready = 1'd1;
				tap_EN = 1'd1;
				tap_WE = 4'b1111;
				tap_A[3:0] = awaddr[3:0];
	    			tap_A[7:4] = awaddr[7:4] - 4'b0010;
	    			tap_A[11:8] = awaddr[11:8];
	    			tap_Di = wdata;
			end
			else if (awvalid && wvalid && awaddr == 12'h10) begin
				awready = 1'd1;
				wready = 1'd1;
				data_length = wdata;
			end
				
			if (tap_A == 12'h028) next_state = axilite_addr_r;
			else next_state = axilite_w;
			sm_tdata = 0;
			result_r = 0;
			next_data = 0;
		end
		
		axilite_addr_r:
		begin
			if (arvalid && awaddr>=12'h20 && awaddr<=12'hFF) begin
				rvalid = 0;
				tap_EN = 1'd1;
				tap_WE = 4'b0000;
				tap_A[3:0] = araddr[3:0];
		        	tap_A[7:4] = araddr[7:4]- 4'b0010;
		        	tap_A[11:8] = araddr[11:8];
		        	next_state = axilite_data_r;
		        end
		     	sm_tdata = 0;
		     	result_r = 0;
		     	next_data = 0;
		end
		
		axilite_data_r:
		begin
			if (rready == 1'd1) begin
				rvalid = 1'd1;
				tap_EN = 1'd1;
				rdata = tap_Do;	
			end
			if (tap_A == 12'h028) next_state = start;
			else next_state = axilite_addr_r;
			sm_tdata = 0;
			result_r = 0;
			next_data = 0;
		end
		
		start:
		begin
			if (awvalid && wvalid && awaddr == 12'h00) begin 
				config_reg = wdata[2:0];
				rdata = config_reg[2];
			end	
			if (config_reg == 3'b100) next_state = start;
			else if (config_reg == 3'b001) next_state = stream_init;
			sm_tdata = 0;
			result_r = 0;
			next_data = 0;
		end
		
		stream_init:
		begin
			config_reg = 3'b000;
			data_EN = 1'b1;
			data_WE = 4'b1111;
			data_Di = 32'd0;
			if (data_A == 12'h028) begin
				next_state = stream_addr_r;
				data_A_temp = 12'h000;
			end
			else begin
				next_state = stream_init;
				data_A_temp = data_A_temp + 12'h004;
			end
			sm_tdata = 0;
			result_r = 0;
			next_data = 0;
		end
		
		stream_addr_r:
		begin
			ss_tready = 0;
			sm_tvalid = 0;
			sm_tdata = 0;
			next_data = 0;
			result_r = 0;
			data_EN = 1'b1;
			data_WE = 4'b0000;
			if (data_counter == data_length) next_state = final_stage;
 			
			else next_state = stream_data_r;
		end
		
		stream_data_r:
		begin
			read_temp = data_Do;
			next_state = stream_data_w;
			sm_tdata = 0;
			result_r = 0;
			next_data = 0;
		end
		
		stream_data_w:
		begin
			data_WE = 4'b1111;
			if (data_A == 12'h000) begin
				if (ss_tvalid==1 && ss_tlast==0) begin
					ss_tready = 1;
					write_temp = read_temp;
					data_Di = ss_tdata;
				end
				else if (ss_tlast == 1) begin
					write_temp = read_temp;
					data_Di = ss_tdata;
				end
			end
			else begin
				data_Di = write_temp;
				write_temp = read_temp;
			end
			if (data_A == 12'h028) begin
				next_state = result_addr;
				data_A_temp = 12'h000;
			end
			else begin
				next_state = stream_addr_r;
				data_A_temp = data_A_temp + 12'h004;
			end
			sm_tdata = 0;
			result_r = 0;
			next_data = 0;
		end
		
		result_addr:
		begin
			data_WE = 4'b0000;
			data_EN = 1'b1;	
			rvalid = 0;
		    tap_WE = 4'b0000;
		    tap_EN = 1'b1;
            arready = 1'b1;
		    result_r = next_data; 
		    tap_A = tap_A_temp;
			next_state = result_data;
			sm_tdata = 0;
			next_data = 0;
		end
 		result_data:
 		begin
 			data_WE = 4'b0000;
			data_EN = 1'b1;
			tap_WE = 4'b0000;
		    	tap_EN = 1'b1;
		    	if (rready == 1) rvalid = 1; 
		    	mult_do =data_Do * tap_Do;
		    	next_data = result_r + mult_do; 
		    	sm_tdata = next_data;
			if (data_A == 12'h028) begin 
	        		if (sm_tready) sm_tvalid = 1'b1;
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
 			 	sm_tlast = 0;
 				rvalid = 1;
 				config_reg[2:1]= 2'b10;
 				rdata = config_reg;
 				next_state = axilite_w;
			 end	
 			 else begin
 			 	sm_tlast = 1;
 			 	config_reg[2:1]= 2'b01;
 			 	rdata = config_reg;
 			 	next_state = final_stage; 
 			 end
 			 sm_tdata = 0;	
 			 result_r = 0;
 			 next_data = 0;				
 		end
 		default:
 		begin
 		      sm_tdata = 0;
 		      result_r = 0;
 		      next_data = 0;
 		end		
	endcase

    end
end
endmodule
