module SevenDisplay99(clk, reset, seg7_sel, enable, seg7_out, dpt_out, carry, led_com);

	input clk, reset, enable; //pin W16,C16,AA15
	output[2:0] seg7_sel; //pin AB10,AB11,AA12 
	output[6:0] seg7_out; // pin AB7,AA7,AB6,AB5,AA9,Y9,AB8 
	
	output dpt_out, led_com, carry;
	wire clk_count, clk_sel;
	wire[3:0] count_out, count1, count0;
	
	assign dpt_out= 1'b0;
	assign led_com= 1'b1;
	assign count_out= (seg7_sel == 3'b101 )? count0 : count1; //MUX
	
	
	freq_div #(22) slow_clk_gen (clk,reset,clk_count); // slow- how quickly generate number
	freq_div #(15) fast_clk_gen (clk,reset,clk_sel); // fast -refresh rate
	count_00_99  counter (clk_count,reset,enable,count1,count0,carry);
	
	//display only count 0 or count 1 only one at a time
	bcd_to_seg7 decoder(count_out,seg7_out);
	//select which digit to display`
	seg7_select #(2) selector (clk_sel, reset, seg7_sel);
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
	 if(seg7_sel == 6 -num_use)
	 seg7_sel = 3'b101; 
	 else
	 seg7_sel = seg7_sel-3'b001; // shift left
	 end
 endmodule
 



module count_00_99(
	clk, 
	reset, 
	enable, 
	count1_out, 
	count0_out, 
	carry);

	input clk, reset, enable;
	output[3:0] count1_out, count0_out;
	output carry = carry1 & carry0;
	wire carry0, carry1;
	count_0_9 C1(clk,reset,enable,count0_out,carry0);
	count_0_9 C2(clk,reset,carry0,count1_out,carry1);
endmodule

module count_0_9(clk, reset, enable, count_out, carry);
	input clk, reset, enable;
	output[3:0] count_out;
	output carry;
	reg[3:0] count_out;
 
	assign carry = (count_out== 4'b1001) ? 1 : 0;
	always@ (posedge clk or posedge reset)begin
	if(reset)
		count_out = 4'b0000;
		else if(enable == 1) begin
			if(count_out== 4'b1001)
				count_out = 4'b0000; //count_out back to 0
		else
			//~~~~your code~~~~//count_out add 1
			count_out = count_out + 1'b1;
	 end
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
	always@ (posedge clk_in or posedge reset) //正緣觸發
	begin
		if(reset)
			for(i=0; i < exp; i=i+1)
		divider[i] = 1'b0;
	else
		divider = divider+ 1'b1;
	end
endmodule