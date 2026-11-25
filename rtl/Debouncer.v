`timescale 1ns/1ps

module Debouncer (
    clk,
    rst_n,
    signal,
    signal_debounced
);

// Parameters
parameter DEBOUNCE_COUNT = 1000; // practically should be 10^6
parameter CLOCK_PERIOD = 10;
//

// I/O Pins
input wire clk;
input wire signal;
input wire rst_n;

output reg signal_debounced;
//

// Internal Nets and Registers
reg [$clog2(DEBOUNCE_COUNT)-1:0] count;
reg signal_FF;
//

// Debouncer Core RTL

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        signal_FF <= 0;
        count <= 0;
        signal_debounced <= 0;
    end
    else
    begin
        if(signal != signal_FF)
        begin
            signal_FF <= signal;
            count <= 0;
        end
        else if(count < DEBOUNCE_COUNT)
        begin
            count <= count + 1;
        end
        
        if(count == DEBOUNCE_COUNT)
        begin
            signal_debounced <= signal_FF;
        end
    end
    
end

endmodule
