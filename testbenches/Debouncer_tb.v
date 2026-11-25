`timescale 1ns/1ps

module testbench;


// Parameters
parameter CLOCK_PERIOD = 10;
parameter DEBOUNCE_COUNT = 1000;
//

// Nets and Registers
reg clk;
reg rst_n;
reg signal;
// reg signal_original; // never used !!

wire signal_debounced;
//

// Internal Variables
integer seed_cycles1 = 7;
integer seed_cycles2 = 5;
integer seed_delay = 14;
integer i;
integer j;
integer delay1;
integer delay2;
integer cycles1;
integer cycles2;
//



// Clock Generator
initial clk = 0;
always #(CLOCK_PERIOD/2) clk = ~clk;
//

// GTKWave .vcd File Generation
initial 
begin
    $dumpfile ("SPI_Protocol/SPI_Top/waves/Debouncer.vcd");
    $dumpvars (0,testbench);
end
//

// Initial Conditions
initial
begin
    signal = 1'b0;
end

initial 
begin
    rst_n = 1'b1;
    @(negedge clk);
    rst_n = 1'b0;
    @(negedge clk);
    rst_n = 1'b1;
end
//

// Module Instantiation
Debouncer #(
    .CLOCK_PERIOD(CLOCK_PERIOD),
    .DEBOUNCE_COUNT(DEBOUNCE_COUNT)
) Debounce_Block (
    .clk(clk),
    .rst_n(rst_n),
    .signal(signal),
    .signal_debounced(signal_debounced)
);
//

task generate_jitter_signal;
begin
    cycles1 = ({$random(seed_cycles1)}%10)+5;
    cycles2 = ({$random(seed_cycles2)}%10)+5;
    delay1 = ({$random(seed_delay)}%3)+1;
    delay2 = ({$random(seed_delay)}%3)+1;
    $display ("Cycles 1 = %0d",cycles1);
    $display ("Cycles 2 = %0d",cycles2);
    $display ("Delay 1 = %0d",delay1);
    $display ("Delay 2 = %0d",delay2);
    #(CLOCK_PERIOD * 10); // buffer delay
    $display ("\n\nPassing jittery signal...\n\n");
    for(i = 0; i < cycles1; i = i + 1)
    begin
        signal = ~signal;
        // $display("\n[%0t]\n",$time);
        #(delay1); // Upto 3 ns width micro pulses to simulate jitter
        // $display("\n[%0t]\n",$time);
        signal = ~signal;
        #(delay2); 
    end

    signal = ~signal;
    // #(CLOCK_PERIOD * 20);
    #(CLOCK_PERIOD * (DEBOUNCE_COUNT + 10));
    signal = ~signal;

    for(i = 0; i < cycles2; i = i + 1)
    begin
        signal = ~signal;
        #(({$random(seed_delay)}%3)+1); // Upto 3 ns width micro pulses to simulate jitter
        signal = ~signal;
        #(({$random(seed_delay)}%3)+1);
    end


    #(CLOCK_PERIOD * (DEBOUNCE_COUNT + 10)); // buffer time
    $display ("\n\nJittery signal passed.\n\n");
end
endtask

initial 
begin
    for(j = 0; j < 2; j = j + 1)
    begin
        generate_jitter_signal ();
    end

    #(CLOCK_PERIOD * 30);

    $finish;
end

endmodule