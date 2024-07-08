module Maze(clk, row, red, green, column, sel, reset,seg7);
	input reset, clk; 
	input [2:0]column; //AA13,AB12,Y16  -used for keyboard column
	output [7:0]red, row, green;
	//D7,D6,A9,C9,A8,C8,C11,B11
	//T22,R21,C6,B6,B5,A5,B7,A7
	//A10,B10,A13,A12,B12,D12,A15,A14
 
	output [2:0]sel; //AB10,AB11,AA12 - used for keyboard row 
	
	//output keyboard to test
	output[6:0]seg7; // pin AB7,AA7,AB6,AB5,AA9,Y9,AB8 ;used for 7segment Led display
	//
	wire ck, press, press_valid, coll;
	wire [3:0]keycode, scancode, addr, keyLed;
	wire [2:0]idx;
	wire [7:0]hor, ver; //saves the current position of the red dot
	assign addr = { coll, idx };
	
	reg [3:0] keycode_and_empty;//added to test keyboard input
	
	key_decode M1 (sel, column, press, scancode); 
	key_buff M2(ck, reset, press_valid, scancode, keycode,keyLed);
	debounce_ctl (ck, reset, press, press_valid);
	
	count6 M4 (ck, reset, sel);
	move M5 (reset, coll, keycode, ver, hor, ck); 

   freq_div#(14) M6 (clk, reset, ck);
	map M7 (addr, green); 
	//run to update address(idx value) and row position in Led matrix=> all rows will be displayed consequently
	idx M8 (ck, reset, idx, row); 
	mix M9 (ver, hor, row, red);
	collision M10 (ck, reset, red, green, coll); //check collision
	
	//add logic to print key pressed to the 7segment 
	bcd_to_seg7 M11(keycode_and_empty, seg7);
	always @(*) begin
		if (sel == 3'b101)  //(only the first left led)
			 keycode_and_empty <= keyLed;
		else
			 keycode_and_empty <= 4'b1111; //black out other leds 
	end
endmodule


module key_buff(clk, rst, press_valid, scan_code, keycode,keyLed);
 
input clk, rst, press_valid;
input[3:0]   scan_code;
output[3:0] keycode,keyLed;
reg[3:0]    keycode,keyLed;
 
 always@(posedge clk or posedge rst) begin
	if(rst) begin
		keycode= 4'b0000;
		keyLed = 4'b1111;
	end else begin
		if (press_valid) begin
			keycode <= scan_code;
			keyLed <= scan_code;//
		end else begin
			keycode <= 4'b0000;
			keyLed <= keyLed;//
		end
	end
 end
endmodule
 
module shift(left, right, reset, unable, out, clk);
	input left, right, reset, clk, unable;
	output reg [7:0]out;
	 always@(posedge clk or posedge reset)
	 begin
		if(reset)
			out<=8'b0000_1000;
		else if(unable) //collision happen
			out<=8'b0000_0000;
		else if(left)
			out <= (out[7] != 1'b1) ? ({out[6:0],out[7]}) : out;
		else if(right)
			out <=  (out[0] !=1'b1) ? ({out[0],out[7:1]}) : out;
		else
			out<=out;
	 end
endmodule
 
module move(reset, unable, key_code, ver, hor, clk);
	input reset, clk, unable;
	input [3:0]key_code;
	output [7:0]ver, hor;
	wire left, right, up, down;
	
	assign left =(key_code==4'b0100)?1'b1:1'b0;
	assign right = (key_code==4'b0110)?1'b1:1'b0;
	assign up = (key_code==4'b0010)?1'b1:1'b0;
	assign down = (key_code==4'b1000)?1'b1:1'b0;
	
	
	shift S1(left, right, reset, unable, hor, clk); //left & right
	shift S2(up, down, reset, unable, ver, clk); //up & down	
endmodule

 module map(addr,data);
	input [3:0]addr;
	output reg [7:0]data;
	 
	 always@(addr)
	 begin
		 case(addr)
			 4'd0 :data= 8'b1111_1111;//Create your own map
			 4'd1 :data= 8'b1110_0011;
			 4'd2 :data= 8'b1111_0100;
			 4'd3 :data= 8'b1000_0001;
			 4'd4 :data= 8'b1111_0101;
			 4'd5 :data= 8'b1111_0101;
			 4'd6 :data= 8'b1111_0101;
			 4'd7 :data= 8'b1111_1111;
			 
			 4'd8  :data=8'b1111_1111;
			 4'd9  :data=8'b1111_1111;
			 4'd10 :data=8'b1111_1111;
			 4'd11 :data=8'b1111_1111;
			 4'd12 :data=8'b1111_1111;
			 4'd13 :data=8'b1111_1111;
			 4'd14 :data=8'b1111_1111;
			 4'd15 :data=8'b1111_1111;
			 default :data=8'b0000_0000;
		 endcase
	 end
 endmodule
 

module mix(ver, hor, row, red);
	input [7:0]ver, hor, row;
	output reg [7:0]red;
		
	always@(*) 
	begin
		if ( (ver & row ) != 8'b0) 
				 red <= hor;
		else
			red <=  8'b0000_0000;				
	end
endmodule

module collision(clk, reset, red, green, coll);
	 input clk, reset;
	 input [7:0]red, green;
	 output reg coll;
	 
	 always@(posedge clk or posedge reset)
	 begin
		 if(reset)
			coll<=1'b0;
		 else if((red & green) != 8'b0) //Collision happen
			coll<=1'b1;
		 else
			coll<=coll;
	 end
 endmodule

//Example idx: 0; row:b1000_0000 => 
//display row 0(row 0:b1000_0000) in the led matrix by value at position {0,d0} hoac {1,d0}
module idx(clk, reset, idx, row);
	input reset, clk;
	output reg [2:0]idx;
	output reg [7:0]row;
	
	always@(posedge clk or posedge reset)
	begin
		if(reset) begin
			 idx<=3'b000;
			 row<=8'b1000_0000;
		 end
		 else begin
			 idx<=idx+3'b001;
			 row<={row[0],row[7:1]};
		 end
	 end
endmodule

module freq_div(clk_in, reset, clk_out);

	parameter exp = 20;
	input clk_in, reset;
	output clk_out;
	reg[exp-1:0] divider;
	integer i;
	assign clk_out= divider[exp-1];
	
	always@ (posedge clk_in or posedge reset) begin
		if(reset)
			for(i=0; i < exp; i=i+1)
		divider[i] = 1'b0;
	else
		divider = divider+ 1'b1;
	end
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
                    //3'b011: begin scan_code = 4'b0001; press = 1'b1; end // 1
                    3'b101: begin scan_code = 4'b0010; press = 1'b1; end // 2
                  //  3'b110: begin scan_code = 4'b0011; press = 1'b1; end // 3
                    default: begin scan_code = 4'b1111; press = 1'b0; end
                endcase
            end
            3'b001: begin
                case(column)
                    3'b011: begin scan_code = 4'b0100; press = 1'b1; end // 4
                   // 3'b101: begin scan_code = 4'b0101; press = 1'b1; end // 5
                    3'b110: begin scan_code = 4'b0110; press = 1'b1; end // 6
                    default: begin scan_code = 4'b1111; press = 1'b0; end
                endcase
            end
            3'b010: begin
                case(column)
                   // 3'b011: begin scan_code = 4'b0111; press = 1'b1; end // 7
                    3'b101: begin scan_code = 4'b1000; press = 1'b1; end // 8
                  //  3'b110: begin scan_code = 4'b1001; press = 1'b1; end // 9
                    default: begin scan_code = 4'b1111; press = 1'b0; end
                endcase
            end
           // 3'b011: begin
          //      case(column)
          //          3'b101: begin scan_code = 4'b0000; press = 1'b1; end // 0
           //         default: begin scan_code = 4'b1111; press = 1'b0; end
          //      endcase
           // end
            default: begin
                scan_code = 4'b1111; press = 1'b0;
            end
        endcase
    end
endmodule
module bcd_led(key_code, led);
	input[3:0]key_code;
	output[9:0]led;
	reg[9:0]led;
 
 always@(key_code) begin
	 case(key_code)
		4'b0000: led = 10'b0000000001; //0 to 9的LED display
		4'b0001: led = 10'b0000000010; // 1
		4'b0010: led = 10'b0000000100; // 2
		4'b0011: led = 10'b0000001000; // 3
		4'b0100: led = 10'b0000010000; // 4
		4'b0101: led = 10'b0000100000; // 5
		4'b0110: led = 10'b0001000000; // 6
		4'b0111: led = 10'b0010000000; // 7
		4'b1000: led = 10'b0100000000; // 8
		4'b1001: led = 10'b1000000000; // 9
		default: led = 10'b0000000000;
	 endcase
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