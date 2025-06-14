/*
By cycling through sel values quickly, 
the system creates the illusion that all 6 digits are displayed simultaneously, 
with each digit showing the correct key code from the corresponding position in display_code.
*/
module Keyboard2 (clk, rst, column, sel, seg7);
	input clk, rst; //pin W16,C16
	input[2:0]column; // pin AA13, AB12, Y16; used for keyboard column
	output[2:0]sel; // pin AB10, AB11, AA12; ;used for keyboard row
	output[6:0]seg7; // pin AB7,AA7,AB6,AB5,AA9,Y9,AB8 ;used for 7segment Led display
	wire clk_sel;
	wire[3:0] key_code; //keyboard from current input
	
	//sel: generated from count6 used to control which led to display and at which position of display_code
	//000 : the most left bit of the 6Leds, 101: the most right bit of the 6Leds 
	//000 : display_code[23:20]				  101: display_code[3:0] 	
	
	//sel: can also be used to specify the row position of the keyboard  
	
	freq_div#(13) (clk, rst, clk_sel);
	key_seg7_6dig( clk_sel,rst,column,sel,key_code);
	bcd_to_seg7(key_code, seg7);
endmodule

//if sel = 2 means: scanning the 3rd row. So scanning continously from 0 to 5 and cycle
module count6(clk, reset, sel);
    input clk, reset;
    output [2:0] sel;
    reg [2:0] sel;

    always @(posedge clk or posedge reset) begin
        if (reset)
            sel <= 3'b000;
        else if (sel == 3'b101) //already 5: cycle again
            sel <= 3'b000;
        else
            sel <= sel + 1;
    end
endmodule

module key_seg7_6dig(clk_sel, rst, column, sel, key_code);
	input clk_sel, rst;
	input[2:0]column;
	output[2:0]sel;
	output[3:0]key_code;

	wire press, press_valid;
	wire[3:0] scan_code, key_code;
	wire[23:0]display_code;
	count6(clk_sel,rst,sel);
	key_decode(sel, column, press, scan_code);// get input from the keyboard in store in scan_code
	debounce_ctl(clk_sel, rst, press, press_valid);//make sure the scan_code is valid
	key_buf6(clk_sel, rst, press_valid, scan_code, display_code);//shifting display_code 4 bits left then append scan_code  
	key_code_mux(display_code, sel, key_code);//get the in put at the position sel in display_code
endmodule


module key_code_mux(display_code, sel, key_code);
	input[23:0] display_code;
	input[2:0]sel;
 output[3:0] key_code;
 
 assign key_code= (sel== 3'b101) ? display_code[3:0] :
 (sel== 3'b100) ? display_code[7:4] :
 (sel== 3'b011) ? display_code[11:8] :
 (sel== 3'b010) ? display_code[15:12] :
 (sel== 3'b001) ? display_code[19:16] :
 (sel== 3'b000) ? display_code[23:20] : 4'b1111;
endmodule

module key_buf6(clk, rst, press_valid, scan_code, display_code);
	input clk, rst, press_valid;
	input[3:0] scan_code;
	output[23:0]display_code;
	reg[23:0]display_code;
 
	always@(posedge clk or posedge rst) begin
		if(rst)
			display_code= 24'hffffff;// initial value
	else
		display_code= press_valid? {display_code[19:0], scan_code[3:0]} : display_code;
	end
endmodule

module debounce_ctl (clk, rst, press, press_valid);
	input press, clk, rst;
	output press_valid;
	reg [5:0] gg;
	
	//(The number of bits depends on the number of enabling counts, 
	//since the sevensegment display needs to use the count6 in order to reuse the count signals, so directly set the 6bit.)
	assign press_valid = ~(gg[5] || (~press));
	always@(posedge clk or posedge rst)
	begin
		if(rst)
			gg <= 6'b0;
		else
			gg <= {gg[4:0], press};
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

//sel : scanning row; column -input from user input (combined with row specified in sel value)
//column combined with row: provide the key pressed ->hardware specific
module key_decode(sel, column, press, scan_code);
    input [2:0] sel;
    input [2:0] column;
    output press;
    output [3:0] scan_code;
    reg [3:0] scan_code;
    reg press;

    always @(sel or column) begin
        case(sel)
            3'b000: begin //row 0 of the key board
                case(column)
                    3'b011: begin scan_code = 4'b0001; press = 1'b1; end // 1
                    3'b101: begin scan_code = 4'b0010; press = 1'b1; end // 2
                    3'b110: begin scan_code = 4'b0011; press = 1'b1; end // 3
                    default: begin scan_code = 4'b1111; press = 1'b0; end
                endcase
            end
            3'b001: begin
                case(column)
                    3'b011: begin scan_code = 4'b0100; press = 1'b1; end // 4
                    3'b101: begin scan_code = 4'b0101; press = 1'b1; end // 5
                    3'b110: begin scan_code = 4'b0110; press = 1'b1; end // 6
                    default: begin scan_code = 4'b1111; press = 1'b0; end
                endcase
            end
            3'b010: begin
                case(column)
                    3'b011: begin scan_code = 4'b0111; press = 1'b1; end // 7
                    3'b101: begin scan_code = 4'b1000; press = 1'b1; end // 8
                    3'b110: begin scan_code = 4'b1001; press = 1'b1; end // 9
                    default: begin scan_code = 4'b1111; press = 1'b0; end
                endcase
            end
            3'b011: begin
                case(column)
                    3'b101: begin scan_code = 4'b0000; press = 1'b1; end // 0
                    default: begin scan_code = 4'b1111; press = 1'b0; end
                endcase
            end
            default: begin
                scan_code = 4'b1111; press = 1'b0;
            end
        endcase
    end
endmodule