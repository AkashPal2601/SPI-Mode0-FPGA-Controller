`timescale 1ns/1ps
`define FPGA_DEBUG

module Seven_Seg_Controller (
    clk,
    rst_n,
    display_driver,
    an,
    seg
);

// parameter DATA_WIDTH = 8; // 8 bit data to be exchanged
// parameter CLOCK_DIV_VAL = 8; // number of times the frequency of SCLK is slower than clk (even number)
// parameter HALF_PERIOD = CLOCK_DIV_VAL/2; // Half period when SCLK needs to toggle

input wire clk;
input wire rst_n;
input wire [15:0] display_driver;

output reg [3:0] an;
output reg [6:0] seg;

reg [19:0] refresh_count; // 2 MSB for selecting one of the 4 segment displays on the board 
// each of the 4 segment displays stays illuminated for 2.62 ms before the next one gets switched ON
reg [3:0] curr_nibble;

wire [1:0] digit_select;
assign digit_select = refresh_count[19:18]; // we use the 2 MSB of refresh_count to select the digits
// 00 --> Digit 3
// 01 --> Digit 2
// 10 --> Digit 1
// 11 --> Digit 0

// refresh count increment block
always @(posedge clk or negedge rst_n) 
begin
    if(!rst_n)
    begin
        refresh_count <= 0;
    end
    else
    begin
        refresh_count <= refresh_count + 1;
    end
end

// Multiplexing Block for electing the current 4 bit vector to be displayed
// and to activate the corresponding 7 segment

always @(*)
begin
    case (digit_select)

    2'b00: // Digit 3
    begin
        an = 4'b0111;
        curr_nibble = display_driver[15:12];
    end

    2'b01: // Digit 2
    begin
        an = 4'b1011;
        curr_nibble = display_driver[11:8];
    end

    2'b10: // Digit 1
    begin
        an = 4'b1101;
        curr_nibble = display_driver[7:4];
    end

    2'b11: // Digit 0
    begin
        an = 4'b1110;
        curr_nibble = display_driver[3:0];
    end

    default:
    begin
        an = 4'b1111;
        curr_nibble = 0;
    end

    endcase

end

// Multiplexing Block for seg

always @(*)
begin
    case (curr_nibble)

    4'h0: seg = 7'b1000000;
    4'h1: seg = 7'b1111001;
    4'h2: seg = 7'b0100100;
    4'h3: seg = 7'b0110000;
    4'h4: seg = 7'b0011001;
    4'h5: seg = 7'b0010010;
    4'h6: seg = 7'b0000010;
    4'h7: seg = 7'b1111000;
    4'h8: seg = 7'b0000000;
    4'h9: seg = 7'b0010000;
    4'hA: seg = 7'b0001000;
    4'hB: seg = 7'b0000011;
    4'hC: seg = 7'b1000110;
    4'hD: seg = 7'b0100001; 
    4'hE: seg = 7'b0000110;
    4'hF: seg = 7'b0001110;

    default: seg = 7'b1111111;

    endcase

end

endmodule