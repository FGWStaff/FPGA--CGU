/*
			Mode 0       Mode 1	    			Mode 2  		Mode3      Mode 4
Light 1: Green 20s    Green flashing 5s  	Yellow 4s  	Red        Red
Light 2  Red          Red		    			Red	    	Green 20s  Green flashing 5s

*/
module Traffic_lights(clk, rst, day_night, light_led, led_com, seg7_out, seg7_sel,row, column_green, column_red);
	 input clk;
	 input rst;
	 input day_night; //PIN_AA15 ->Switch1
	 output[5:0] light_led;//pin E2 ,D3 ,C2 ,N1 ,AA2 ,AA1
	 output led_com;//pin N20
	 output[2:0] seg7_sel;//pin AB10 ,AB11, AA12
	 output[6:0] seg7_out;
	 wire led_com;
	 wire clk_cnt_dn,clk_fst,clk_sel;
	 wire[7:0] g1_cnt;
	 wire[7:0] g2_cnt;
	 wire[3:0] count_out;
	 
	 //man walking matching the lights
	 //column_green/red compare the Lab1 pin
	 wire clk_shift, clk_scan;
	 wire[6:0] idx,idx_cnt, light2_color;
	 wire[7:0] column_out;
	 output[7:0] row, column_green, column_red;
	//row:pin A7, B7, A5, B5, B6, C6, R21, T22
	 

	assign led_com= 1'b1;
	
	count_logic M6(day_night, g1_cnt, g2_cnt, seg7_sel, count_out);
	
	freq_div#(23) M0(clk, rst, clk_cnt_dn);
	freq_div#(21) M1(clk, rst, clk_fst);
	freq_div#(15) M2(clk, rst, clk_sel);
	
	freq_div#(22) M100 (clk,rst,clk_shift);
	freq_div#(12) M99 (clk,rst,clk_scan);
	
	traffic M3(clk_fst,clk_cnt_dn,rst,day_night,g1_cnt,g2_cnt,light_led);
	
	bcd_to_seg7 M4(count_out, seg7_out); 
	seg7_select #(6) M5(clk_sel, rst, seg7_sel);
	
	
    light_color(g2_cnt,light2_color);
	 idx_gen M11  (clk_shift, rst, light2_color, idx); 

    assign column_green= (light2_color ==  2'b01 || light2_color ==  2'b10 )? column_out: 8'b0;
	 assign column_red= (light2_color == 2'b00 || light2_color ==  2'b10)? column_out: 8'b0;

	 //output the walking man based on the light 1
    row_gen M8 (clk_scan, rst, idx, row, idx_cnt);
    rom_char M9 (idx_cnt, column_out);

    
	
endmodule

module light_color(
    input [7:0] g1_count,
    output reg [1:0] color
);

    always @(*) begin
        if (g1_count >= 10 && g1_count <= 29)
            color = 2'b01; // Return 1 for this range
        else if (g1_count >= 5 && g1_count <= 9)
            color = 2'b10; // Return 2 for this range
        else if (g1_count >= 1 && g1_count <= 4)
            color = 2'b00; // Return 0 for this range
        else
            color = 2'b00; // Default case
    end

endmodule



module idx_gen(
    input clk,
    input rst,
    input [1:0] color, // 00: standing, 01: walking, 02: running
    output reg [6:0] idx
);
    reg [1:0] cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            idx <= 7'd0;
            cnt <= 2'd0;
        end else begin
            case(color)
                2'd0: begin //Standing
                    idx <= 7'd8;
                end
                2'd1: begin //Walking
                    if (cnt == 2'd0) begin
                        idx <= 7'd16;
                        cnt <= 2'd1;
                    end else begin
                        idx <= 7'd24;
                        cnt <= 2'd0;
                    end
                end
                2'd2: begin //Running
                    if (cnt == 2'd0) begin
                        idx <= 7'd32;
                        cnt <= 2'd1;
                    end else if (cnt == 2'd1) begin
                        idx <= 7'd40;
                        cnt <= 2'd2;
                    end else begin
                        idx <= 7'd48;
                        cnt <= 2'd0;
                    end
                end
                default: idx <= 7'd0;
            endcase
        end
    end
endmodule

module row_gen(clk, rst, idx, row, idx_cnt);
  input clk, rst;
  input[6:0] idx;
  output[7:0] row;
  output[6:0] idx_cnt;
  reg[7:0] row;
  reg[6:0] idx_cnt;
  reg[2:0] cnt;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      row <= 8'b0000_0001; // Start with the first row
      cnt <= 3'd0;
      idx_cnt <= 7'd0;
    end else begin
      row <= 8'b0000_0001 << cnt; // Shift to the next row
      cnt <= cnt + 3'd1; // Increment the row counter
      if (cnt == 3'd7) begin
        cnt <= 3'd0; // Reset row counter after reaching the last row
      end
      idx_cnt <= idx + cnt; // Update index counter to match current row
    end
  end
endmodule

//this module will scan all digits on 7segments display 
//and display number appropriatedly in g1_cnt(hang don vi, hang chuc) or g2_cnt
/*module count_logic(
	 input day_night,
    input [7:0] g1_cnt,
    input [7:0] g2_cnt,
    input [2:0] seg7_sel,
    output reg [3:0] count_out
);
    always @(*) begin
        if (day_night) begin
            if (seg7_sel == 3'b101) begin //right most
					count_out = g1_cnt >= 8'd9 ?  ((g1_cnt - 8'd9) % 10) : g1_cnt[3:0];
				end else if (seg7_sel == 3'b100) begin//second rightmost
					count_out = g1_cnt >= 8'd9 ?  ((g1_cnt - 8'd9) / 10) : 4'b1111;
				end else if (seg7_sel == 3'b011) begin
					count_out = 4'b1111; //not display at this poistion
				end else if (seg7_sel == 3'b010) begin//first character of count
					count_out = g2_cnt >= 8'd9 ?  ((g2_cnt - 8'd9) % 10) : g2_cnt[3:0];
				end else if (seg7_sel == 3'b0001) begin //second character of count
					count_out = g2_cnt >= 8'd9 ?  ((g2_cnt - 8'd9) / 10) : 4'b1111;
				end else 
					count_out = 4'b1111; //not display at this poistion as 
				end
		end
   
endmodule*/

module count_logic(
	 input day_night,
    input [7:0] g1_cnt,
    input [7:0] g2_cnt,
    input [2:0] seg7_sel,
    output reg [3:0] count_out
);
	//checking if it is displaying the nth Led from right to left
    always @(*) begin
        if (day_night) begin
            if (seg7_sel == 3'b101) begin //right most
					count_out = g2_cnt >= 8'd9 ?  ((g2_cnt - 8'd9) % 10) : 
																	(g2_cnt[3:0] >=8'd3) ? (g2_cnt - 8'd3) : g2_cnt[3:0]; 
				end else if (seg7_sel == 3'b100) begin//second rightmost
					count_out = g2_cnt >= 8'd9 ?  ((g2_cnt - 8'd9) / 10) : 4'b1111;
				end else if (seg7_sel == 3'b011) begin
					count_out = 4'b1111; //not display at this poistion
				end else if (seg7_sel == 3'b010) begin//first character of count
					count_out = g1_cnt >= 8'd9 ?  ((g1_cnt - 8'd9) % 10) :  
																	(g1_cnt[3:0] >=8'd3) ? (g1_cnt - 8'd3) : g1_cnt[3:0];
				end else if (seg7_sel == 3'b0001) begin //second character of count
					count_out = g1_cnt >= 8'd9 ?  ((g1_cnt - 8'd9) / 10) : 4'b1111;
				end else 
					count_out = 4'b1111; //not display at this poistion as 
				end
		end
   
endmodule


module rom_char(
    input  [6:0] addr,
    output reg [7:0] data
);

    always @(addr) begin
        case(addr)
            // Blank
            7'd0: data = 8'h00;
            7'd1: data = 8'h00;
            7'd2: data = 8'h00;
            7'd3: data = 8'h00;
            7'd4: data = 8'h00;
            7'd5: data = 8'h00;
            7'd6: data = 8'h00;
            7'd7: data = 8'h00;
            // Standing (from 7'd8 to 7'd15)
            7'd8:  data = 8'h18;
            7'd9:  data = 8'h18;
            7'd10: data = 8'h18;
            7'd11: data = 8'h18;
            7'd12: data = 8'h3C;
            7'd13: data = 8'h7E;
            7'd14: data = 8'h00;
            7'd15: data = 8'h00;
				
		
            // Walking Frame 1 (from 7'd16 to 7'd23)
            7'd16: data = 8'h18;
            7'd17: data = 8'h18;
            7'd18: data = 8'h18;
            7'd19: data = 8'h3C;
            7'd20: data = 8'h7E;
            7'd21: data = 8'h0C;
            7'd22: data = 8'h18;
            7'd23: data = 8'h00;

            // Walking Frame 2 (from 7'd24 to 7'd31)
            7'd24: data = 8'h18;
            7'd25: data = 8'h18;
            7'd26: data = 8'h18;
            7'd27: data = 8'h3C;
            7'd28: data = 8'h7E;
            7'd29: data = 8'h18;
            7'd30: data = 8'h30;
            7'd31: data = 8'h00;

            // Running Frame 1 (from 7'd32 to 7'd39)
            7'd32: data = 8'h18;
            7'd33: data = 8'h18;
            7'd34: data = 8'h18;
            7'd35: data = 8'h3C;
            7'd36: data = 8'h7E;
            7'd37: data = 8'h18;
            7'd38: data = 8'h30;
            7'd39: data = 8'h00;

            // Running Frame 2 (from 7'd40 to 7'd47)
            7'd40: data = 8'h18;
            7'd41: data = 8'h18;
            7'd42: data = 8'h18;
            7'd43: data = 8'h3C;
            7'd44: data = 8'h7E;
            7'd45: data = 8'h0C;
            7'd46: data = 8'h18;
            7'd47: data = 8'h00;

            // Running Frame 3 (from 7'd48 to 7'd55)
            7'd48: data = 8'h18;
            7'd49: data = 8'h18;
            7'd50: data = 8'h18;
            7'd51: data = 8'h3C;
            7'd52: data = 8'h7E;
            7'd53: data = 8'h30;
            7'd54: data = 8'h18;
            7'd55: data = 8'h00;

            default: data = 8'h00;
        endcase
    end
endmodule



module traffic (clk_fst, clk_cnt_dn, rst, day_night, g1_cnt, g2_cnt, light_led);
	input clk_fst, clk_cnt_dn, rst, day_night;
	output[5:0] light_led;
	output[7:0] g1_cnt;
	output[7:0] g2_cnt;
	wire g1_en, g2_en;
	wire[7:0] g1_cnt;
	wire[7:0] g2_cnt;
	ryg_ctl M0(clk_fst,clk_cnt_dn,rst,day_night,g1_cnt,g2_cnt,g1_en,g2_en, light_led);
	light_cnt_dn_29 M1(clk_cnt_dn, rst, g1_en, g1_cnt); // for light 1
	light_cnt_dn_29 M2(clk_cnt_dn, rst, g2_en, g2_cnt); // for light 2 
endmodule

module ryg_ctl (clk_fst, clk_cnt_dn, rst, day_night, g1_cnt, g2_cnt, g1_en, g2_en, light_led);
    input clk_fst, clk_cnt_dn, rst, day_night;
    input [7:0] g1_cnt, g2_cnt;
    output g1_en, g2_en;
    output [5:0] light_led;
    reg g1_en, g2_en;
    reg [5:0] light_led;
    reg [2:0] mode;

    always @(posedge clk_fst or posedge rst) begin
        if (rst) begin
            light_led <= 6'b001_100; // g1 : r2
            mode <= 3'b0;
            g1_en <= 1'b0;
            g2_en <= 1'b0;
        end else if (day_night == 1'b1) begin // day time
            case (mode)
                3'd0: begin
                    light_led <= 6'b001_100; // g1 : r2
                    g1_en <= 1'b1; // g1 count down
                    if (g1_cnt == 8'b0000_1001) // after 20 seconds (29-9=20s)
                        mode <= mode + 3'b1; 
                end
                3'd1: begin // g1 flashes : r2
                    if (g1_cnt == 8'b0000_0100) // after 5 seconds
                        mode <= mode + 3'b1; 
                    else
                        light_led[3] <= clk_cnt_dn; // g1 flashes
                end
                3'd2: begin
                    light_led = 6'b010_100; // y1 : r2
                    if (g1_cnt == 8'b0000_0000) begin // after 4 seconds
                        g1_en <= 1'b0;
                        mode <= mode + 3'b1;
                    end
                end
                3'd3: begin
                    light_led <= 6'b100_001; // r1 : g2
                    g2_en <= 1'b1;
                    if (g2_cnt == 8'b0000_1001) // after 20 seconds
                        mode <= mode + 3'b1; 
                end
                3'd4: begin // r1 : g2 flashes
                    if (g2_cnt == 8'b0000_0100) // after 5 seconds
                        mode <= mode + 3'b1; 
                    else
                        light_led[0] <= clk_cnt_dn; // g2 flashes
                end
                3'd5: begin
                    light_led <= 6'b100_010; // r1 : y2
                    if (g2_cnt == 8'b0000_0000) begin // after 4 seconds
                        g2_en <= 1'b0;
                        mode <= 3'b0;
                    end
                end
                default: begin // back to mode 0
                    light_led <= 6'b001_100; // g1 : r2
                    g1_en <= 1'b1; // g1 count down
                    if (g1_cnt == 8'b0000_1001) // after 20 seconds
                        mode <= mode + 3'b1; 
                end
            endcase
        end else if (day_night == 1'b0) begin // night time
            //row_en <= 2'b11;
            light_led <= {{1'b0, clk_cnt_dn, 1'b0}, {1'b0, clk_cnt_dn, 1'b0}};
            g1_en <= 1'b0;
            g2_en <= 1'b0;
        end
    end
endmodule




module light_cnt_dn_29 (clk, rst, enable, cnt);
	input clk, rst, enable;
	output[7:0] cnt;
	reg[7:0] cnt;//MSB[7:4] for tens digits,LSB [3:0] for ones digits; [7:4] hang chuc; [3:0] hang don vi
	 
	always@(posedge clk or posedge rst) begin
		if (rst)
            cnt = 8'b0; // initial state
        else if (enable) begin
            if (cnt == 8'b0)
                cnt = 8'd29; 
            else 
                cnt = cnt - 1'b1; 
		  end else
				cnt = 8'b0; // set cnt to 0 if enable is not set
	end
endmodule


module bcd_to_seg7(bcd_in, seg7);
	input[3:0] bcd_in;
	output[6:0] seg7;
	reg[6:0] seg7;
	
	always@ (bcd_in)begin
		case(bcd_in) // abcdefg
			4'b0000: seg7 = 7'b1111110; // 0
			4'b0001: seg7 = 7'b0110000; // 1
			4'b0010: seg7 = 7'b1101101; // 2
			4'b0011: seg7 = 7'b1111001; // 3
			4'b0100: seg7 = 7'b0110011; // 4
			4'b0101: seg7 = 7'b1011011; // 5
			4'b0110: seg7 = 7'b1011111; // 6
			4'b0111: seg7 = 7'b1110000; // 7
			4'b1000: seg7 = 7'b1111111; // 8
			4'b1001: seg7 = 7'b1111011; // 9
			default: seg7 = 7'b0000000; 
		endcase
	end
endmodule

module freq_div(clk_in, reset, clk_out);
	parameter exp = 20;
	input clk_in, reset;
	output clk_out;
	
	reg[exp-1:0] divider;
	integer i;
	assign clk_out= divider[exp-1];
	always@ (posedge clk_in or posedge reset) //
	begin
		if(reset)
			for(i=0; i < exp; i=i+1)
		divider[i] = 1'b0;
	else
		divider = divider+ 1'b1;
	end
endmodule

module seg7_select(clk, reset, seg7_sel);
	 parameter num_use= 6; //number of 7 segment
	 input clk, reset;
	 output[2:0] seg7_sel;
	 reg [2:0] seg7_sel;
	 always@ (posedge clk or posedge reset) begin
	 if(reset == 1)
	 seg7_sel = 3'b101; // the rightmost one
	 else
	 if(seg7_sel == 6 -num_use) //cycle to the first led
	 seg7_sel = 3'b101; 
	 else
	 seg7_sel = seg7_sel-3'b001; // display the next left led
	 end
endmodule
