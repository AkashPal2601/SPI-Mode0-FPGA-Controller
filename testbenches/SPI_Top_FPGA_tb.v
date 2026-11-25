`timescale 1ns/1ps

module testbench;

// =====================================================
// ----PARAMETER DECLARATION AND CLOCK TIMING----
// =====================================================
parameter DATA_WIDTH = 8; // decides number of bits of full duplex data transfer per frame
parameter CLOCK_PERIOD = 10; // fast system clock period in ns
parameter CPOL = 1'b0; // Clock Polarity
parameter CPHA = 1'b0; // Clock Phase
parameter CLOCK_DIV_VAL = 10000; // (practically 10^8) number of times the frequency of SCLK is slower than clk (even number)
parameter DEBOUNCE_COUNT = 1000; // (practically 10^6) number of clock cycles the button signals must stay constant

// 

// SPI Master Module parameters
parameter Master_STATE_IDLE = 2'b00;
parameter Master_STATE_LOAD = 2'b01;
parameter Master_STATE_TRANSMIT = 2'b10;
parameter Master_STATE_STOP = 2'b11;
//

// SPI Slave Module Parameters
parameter Slave_STATE_IDLE = 2'b00; 
parameter Slave_STATE_TRANSMIT = 2'b01; 
parameter Slave_STATE_COMPUTE = 2'b10; 
//

// =====================================================
// ----DECLARING I/O PIN CONNECTIONS----
// =====================================================
reg                    start_btn; 
reg                    rst_btn;
reg                    clk;
reg  [DATA_WIDTH-1:0]  tx_data_in_sw;
reg                    display_mode_sw1;
reg                    display_mode_sw2;

wire                   [DATA_WIDTH-1:0] rx_data_out_LED;
wire                   data_ready_LED;
wire [3:0]             an;
wire [6:0]             seg;
wire                   SCLK_LED;
// //

// =====================================================
// ----Internal Nets and Registers----
// =====================================================
reg [DATA_WIDTH-1:0] temp; // used to hold the random generated 8 bit data for TEST 4
// //

// =====================================================
// ----TEST STATUS FLAGS----
// =====================================================
integer pass_count = 0;
integer fail_count = 0;
integer test_count = 0;
integer flag = 0; // flag = 1 implies there has been an error in a particular test fragment
// //

// =====================================================
// ----RANDOM SEED & INTERMEDIATE VARIABLES----
// =====================================================
integer seed_cycles1 = 7;
integer seed_cycles2 = 5;
integer seed_delay = 14;
integer data_seed = 5;
integer delay1;
integer delay2;
integer cycles1;
integer cycles2;
integer i; // loop variable 
integer j; // loop variable
integer k; // loop variable
//

// =====================================================
// ----CLOCK GENERATOR (100 MHz)----
// =====================================================
initial
begin
    clk = 1'b0;
end

always #(CLOCK_PERIOD/2) clk = ~clk;
// //

// =====================================================
// ----DUT Instantiation----
// =====================================================

SPI_Top_FPGA #(
    .DATA_WIDTH(DATA_WIDTH),
    .CLOCK_PERIOD(CLOCK_PERIOD),
    .CLOCK_DIV_VAL(CLOCK_DIV_VAL),
    .DEBOUNCE_COUNT(DEBOUNCE_COUNT)
) SPI_FPGA (
    .start_btn(start_btn),
    .rst_btn(rst_btn),
    .clk(clk),
    .tx_data_in_sw(tx_data_in_sw),
    .display_mode_sw1(display_mode_sw1),
    .display_mode_sw2(display_mode_sw2),
    .rx_data_out_LED(rx_data_out_LED),
    .data_ready_LED(data_ready_LED),
    .an(an),
    .seg(seg),
    .SCLK_LED(SCLK_LED)
);
// //

// =====================================================
// ----MODULAR TASK DEFINITIONS----
// =====================================================

// // Task 1: Bouncy Signal Generator
// task Bouncy_Signal_Generate;
// output reg signal;
// begin
//     signal = 1'b0; // initial value

//     cycles1 = ({$random(seed_cycles1)}%10)+5;
//     cycles2 = ({$random(seed_cycles2)}%10)+5;
//     delay1 = ({$random(seed_delay)}%3)+1;
//     delay2 = ({$random(seed_delay)}%3)+1;
//     $display ("Cycles 1 = %0d",cycles1);
//     $display ("Cycles 2 = %0d",cycles2);
//     $display ("Delay 1 = %0d",delay1);
//     $display ("Delay 2 = %0d",delay2);
//     #(CLOCK_PERIOD * 10); // buffer delay
//     $display ("\n\nPassing jittery signal...\n\n");
//     for(i = 0; i < cycles1; i = i + 1)
//     begin
//         signal = ~signal;
//         // $display("\n[%0t]\n",$time);
//         #(delay1); // Upto 3 ns width micro pulses to simulate jitter
//         // $display("\n[%0t]\n",$time);
//         signal = ~signal;
//         #(delay2); 
//     end

//     signal = ~signal;
//     // #(CLOCK_PERIOD * 20);
//     #(CLOCK_PERIOD * (DEBOUNCE_COUNT + 10));
//     signal = ~signal;

//     for(i = 0; i < cycles2; i = i + 1)
//     begin
//         signal = ~signal;
//         #(({$random(seed_delay)}%3)+1); // Upto 3 ns width micro pulses to simulate jitter
//         signal = ~signal;
//         #(({$random(seed_delay)}%3)+1);
//     end


//     #(CLOCK_PERIOD * (DEBOUNCE_COUNT + 10)); // buffer time
//     $display ("\n\nJittery signal passed.\n\n");
// end
// endtask
// //


// Task 2: Bouncy Reset Button Push
task push_rst_btn;
begin
    // Bouncy_Signal_Generate(rst_btn);
    
    @(negedge clk); // .. //
    rst_btn = 1'b0; // initial value

    cycles1 = ({$random(seed_cycles1)}%10)+5;
    cycles2 = ({$random(seed_cycles2)}%10)+5;
    delay1 = ({$random(seed_delay)}%3)+1;
    delay2 = ({$random(seed_delay)}%3)+1;
    $display ("Cycles 1 = %0d",cycles1);
    $display ("Cycles 2 = %0d",cycles2);
    $display ("Delay 1 = %0d",delay1);
    $display ("Delay 2 = %0d",delay2);
//    #(CLOCK_PERIOD * 10); // buffer delay // .. //
    for(k = 0; k < 20; k = k + 1)
    begin
        @(negedge clk);
    end

    $display ("\n\nPassing jittery signal...\n\n");
    for(i = 0; i < cycles1; i = i + 1)
    begin
        rst_btn = ~rst_btn;
        // $display("\n[%0t]\n",$time);
//        #(delay1); // Upto 3 ns width micro pulses to simulate jitter
        for(k = 0; k < delay1; k = k + 1)
        begin
            @(negedge clk);
        end
        
        // $display("\n[%0t]\n",$time);
        rst_btn = ~rst_btn;
        for(k = 0; k < delay2; k = k + 1)
        begin
            @(negedge clk);
        end
//        #(delay2); // .. // 
    end

    rst_btn = ~rst_btn;
    // #(CLOCK_PERIOD * 20);
//    #(CLOCK_PERIOD * (DEBOUNCE_COUNT + 10)); // .. //
    for(k = 0; k < (DEBOUNCE_COUNT + 10); k = k + 1)
    begin
        @(negedge clk);
    end
    
    rst_btn = ~rst_btn;
    @(negedge clk);

    for(i = 0; i < cycles2; i = i + 1)
    begin
        rst_btn = ~rst_btn;
//      #(({$random(seed_delay)}%3)+1); // Upto 3 ns width micro pulses to simulate jitter // .. //
        for(k = 0; k < (({$random(seed_delay)}%3)+1); k = k + 1)
        begin
            @(negedge clk);
        end


        rst_btn = ~rst_btn;
//        #(({$random(seed_delay)}%3)+1); // .. //
        for(k = 0; k < (({$random(seed_delay)}%3)+1); k = k + 1)
        begin
            @(negedge clk);
        end
    end


//    #(CLOCK_PERIOD * (DEBOUNCE_COUNT + 10)); // buffer time //////
    for(k = 0; k < (DEBOUNCE_COUNT + 10); k = k + 1)
    begin
        @(negedge clk);
    end
    
    $display ("\n\nJittery signal passed.\n\n");
end
endtask
//


// Task 3: Bouncy Start Button Push
task push_start_btn;
begin
    // Bouncy_Signal_Generate(start_btn);
    @(negedge clk);
    start_btn = 1'b0; // initial value

    cycles1 = ({$random(seed_cycles1)}%10)+5;
    cycles2 = ({$random(seed_cycles2)}%10)+5;
    delay1 = ({$random(seed_delay)}%3)+1;
    delay2 = ({$random(seed_delay)}%3)+1;
    $display ("Cycles 1 = %0d",cycles1);
    $display ("Cycles 2 = %0d",cycles2);
    $display ("Delay 1 = %0d",delay1);
    $display ("Delay 2 = %0d",delay2);
    
//    #(CLOCK_PERIOD * 10); // buffer delay // .. //
    for(k = 0; k < 10; k = k + 1)
    begin
        @(negedge clk);
    end

    $display ("\n\nPassing jittery signal...\n\n");
    for(i = 0; i < cycles1; i = i + 1)
    begin
        start_btn = ~start_btn;
        // $display("\n[%0t]\n",$time);
//        #(delay1); // Upto 3 ns width micro pulses to simulate jitter // .. //
        for(k = 0; k < delay1; k = k + 1)
        begin
            @(negedge clk);
        end
        // $display("\n[%0t]\n",$time);
        start_btn = ~start_btn;
//        #(delay2); // .. //
        for(k = 0; k < delay2; k = k + 1)
        begin
            @(negedge clk);
        end
    end

    start_btn = ~start_btn;
    // #(CLOCK_PERIOD * 20);
//    #(CLOCK_PERIOD * (DEBOUNCE_COUNT + 10)); // .. //
    for(k = 0; k < (DEBOUNCE_COUNT + 10); k = k + 1)
    begin
        @(negedge clk);
    end

    start_btn = ~start_btn;
    @(negedge clk);

    for(i = 0; i < cycles2; i = i + 1)
    begin
        start_btn = ~start_btn;
//        #(({$random(seed_delay)}%3)+1); // Upto 3 ns width micro pulses to simulate jitter // .. //
        for(k = 0; k < (({$random(seed_delay)}%3)+1); k = k + 1)
        begin
            @(negedge clk);
        end

        start_btn = ~start_btn;
//        #(({$random(seed_delay)}%3)+1); // .. //
        for(k = 0; k < (({$random(seed_delay)}%3)+1); k = k + 1)
        begin
            @(negedge clk);
        end

    end


//    #(CLOCK_PERIOD * (DEBOUNCE_COUNT + 10)); // buffer time ///////
        for(k = 0; k < (DEBOUNCE_COUNT + 10); k = k + 1)
        begin
            @(negedge clk);
        end

    $display ("\n\nJittery signal passed.\n\n");
end
endtask
//

// Task 4: Buffer Time between 2 consecutive tests
// This corresponds to around 100 ms minimum delay between user pressing a button twice consecutively, for example
task buffer_time;
begin
    #(CLOCK_PERIOD * 50); // 100 ms delay
end
endtask
//

// Task 5: 2 Frame SPI Full Duplex Data Exchange ( 1 frame computation latency)
// Data sent over to the Slave in the 1st transfer is processed and received back by the Master in the 2nd transfer
// We transfer a dummy value 0x00 to the Slave in every 2nd iteration in order to receive the processed output of the data sent over in 1st transfer
task SPI_transfer_execute;
    input [DATA_WIDTH-1:0] tx_data;
    input [DATA_WIDTH-1:0] expected_frame1_rx;
    input [DATA_WIDTH-1:0] expected_frame2_rx;
    begin

        // Frame 1: Passing tx_data over to the Slave and receiving the pre-existing value sitting in the Slave's tx

        $display ("\n\n[%0t ns] [FRAME 1] Sending data to Slave: 0x%02x...\n\n",$time,tx_data);
        @(negedge clk);
        tx_data_in_sw = tx_data;
        
        fork
            // Thread 1: Pushing Start Button
            begin
                push_start_btn();
            end
            // Thread 2: Waiting for data_ready signal and comparisons
            begin
                wait (data_ready_LED == 1'b1);
            @(negedge clk);
            @(negedge clk);
            #(CLOCK_PERIOD * 2); 
            // data should be ready in rx_data_out by now...
            if(rx_data_out_LED === expected_frame1_rx)
            begin
                $display ("[PASS]...[FRAME 1] data verified: Expected 0x%02x, Received 0x%02x.\n\n",expected_frame1_rx,rx_data_out_LED);
                pass_count = pass_count + 1;
                test_count = test_count + 1;
            end
            else
            begin
                $display ("[FAIL]...[FRAME 1] data mismatch: Expected 0x%02x, Received 0x%02x.\n\n",expected_frame1_rx,rx_data_out_LED);
                fail_count = fail_count + 1;
                test_count = test_count + 1;
            end
    
            // Frame 2: Sending dummy value 0x00 over to Slave to receive the computed value of 1st transfer
    
            $display ("\n\n[%0t ns] [FRAME 2] Sending dummy data 0x00 to Slave...\n\n",$time);
            @(negedge clk);
            tx_data_in_sw = 8'h00;
            push_start_btn();
            wait (data_ready_LED == 1'b1);
            @(negedge clk);
            @(negedge clk);
            #(CLOCK_PERIOD * 2);
            // data should be ready in rx_data_out by now...
            if(rx_data_out_LED == expected_frame2_rx)
            begin
                $display ("[PASS]...[FRAME 2] data verified: Expected 0x%02x, Received 0x%02x.\n\n",expected_frame2_rx,rx_data_out_LED);
                pass_count = pass_count + 1;
                test_count = test_count + 1;
            end
            else
            begin
                $display ("[FAIL]...[FRAME 2] data mismatch: Expected 0x%02x, Received 0x%02x.\n\n",expected_frame2_rx,rx_data_out_LED);
                fail_count = fail_count + 1;
                test_count = test_count + 1;
            end
          end
        join 
        
           
    end
endtask
//

// Task 5: Mid-Transfer Asynchronous Reset 
// This pulls an asynchronous reset operation abruptly in between a data transmission
// Passing this test implies that the reset pin can be used anytime to force a reset, not just power on initialization

//

// =====================================================
// ----GTKWAVE .vcd FILE GENERATION----
// =====================================================
initial
begin
    $dumpfile("SPI_Protocol/SPI_Top/waves/SPI_Top_FPGA.vcd");
    $dumpvars(0,testbench);
end
//

// =====================================================
// ----ASSIGNING INITIAL VALUES TO DATA INPUT PINS----
// =====================================================
initial 
begin
    start_btn = 1'b0;
    rst_btn = 1'b0;
    tx_data_in_sw = 0;
    display_mode_sw1 = 1'b0;
    display_mode_sw2 = 1'b0;
end
//

// =====================================================
// ----MAIN TESTBENCH EXECUTION----
// =====================================================

initial
begin

    #10000; // a significant delay before providing input signals


    $display ("\n===================================================\n");
    $display ("--------STARTING VERIFICATION OF TOP LEVEL SPI FPGA WRAPPER---------");
    $display ("\n===================================================\n");

    $display ("\n--- TEST 1: Power On Initialization and Asynchronous Reset Checks ---\n\n");

    buffer_time(); // to observe in waveform that pins were in unknown state before reset pulse is applied
    push_rst_btn(); // sending over a reset pulse to the system

    // We expect reset pulse to act on 'data_ready' pins at the I/O Level
    // We shall probe into the internal FSM States and shift register status of Master and Slave Modules later

    // we use !== comparison and not !=, so that unknown state 'x' and '0' are distinct
    // if(start !== 1'b0)
    // begin
    //     $display("\n\n[FAIL] TEST 1: ACTIVE LOW Reset Pin --- 'start' expected: %1b, 'start' obtained: %1b\n\n",1'b0,start);
    //     fail_count = fail_count + 1;
    //     test_count = test_count + 1;
    //     flag = 1;
    // end

    if(data_ready_LED !== 1'b0)
    begin
        $display("\n\n[FAIL] TEST 1: ACTIVE LOW Reset Pin --- 'data_ready_LED' expected: %1b, 'data_ready_LED' obtained: %1b\n\n",1'b0,data_ready_LED);
        fail_count = fail_count + 1;
        test_count = test_count + 1;
        flag = 1;
    end

    if(SCLK_LED !== 1'b0)
    begin
        $display("\n\n[FAIL] TEST 1: ACTIVE LOW Reset Pin --- 'SCLK_LED' expected: %1b, 'SCLK_LED' obtained: %1b\n\n",1'b0,SCLK_LED);
        fail_count = fail_count + 1;
        test_count = test_count + 1;
        flag = 1;
    end


    if(flag == 0) // no errors
    begin
        $display("\n\n[PASS] TEST 1: ACTIVE LOW Reset Pin functions functions smoothly.\n\n");
        pass_count = pass_count + 1;
        test_count = test_count + 1;
    end

    flag = 0; // preparing flag variable for other tests

    // Probe into internal Master and Slave states and shift registers as a continuation of this test !!

    buffer_time(); // ensures a gap of 100 ms between two consecutive tests

    // end of TEST 1

    $display ("\n\n--- TEST 2: Start Button Verification and Basic Operation of the Circuit ---\n\n");

    // we supply input data as 8'h00 and test if the start pulse actually activates the data transmission
    
    @(negedge clk);
    tx_data_in_sw = 8'h00; // input data

    buffer_time();

    fork
        // Thread 1: Start Button Pressed
        begin
            $display ("\n[%0t]Pressing start button....\n",$time);
            push_start_btn(); // pressing start button to initiate full duplex data transfer
            $display ("\n[%0t]Start Button Successfully Pressed\n",$time);
        end
        // Thread 2: data_ready_LED wait and watchdog timer
        begin
            $display ("\n[%0t]Waiting for data_ready...\n",$time);
            wait (data_ready_LED == 1'b1);
            $display ("\n[%0t]data_ready wait is over !!\n",$time);
            // for the first iteration frame, just after reset, we expect rx_data_out = 8'h00
            // actually, the sole fact that data_ready goes high and the terminal doesnt get caught up in an infinite loop is proof that start pulse worked
        end
        // //
    join

    

    if(rx_data_out_LED !== 8'h00)
    begin
        $display ("\n\n[FAIL] TEST 2: Start Button does not function as expected");
        fail_count = fail_count + 1;
        test_count = test_count + 1;
        flag = 1;
    end

    if(flag == 0) // no errors
    begin
        $display("\n\n[PASS] TEST 2: Start Button functions as intended.\n\n");
        pass_count = pass_count + 1;
        test_count = test_count + 1;
    end

    flag = 0; // preparing flag variable for other tests

    buffer_time(); // ensures a gap of a few clock cycles between consecutive tests  
    

    $display ("\n\n--- TEST 3: Full Duplex Data Transfer Verification on specific input bytes ---\n\n");

    $display ("TEST 3(A): Alternating Bit Pattern (Data: 0xA5):\n\n");
    // Our last transferred data was 8'h00, so we expect the first transfer frame to return 8'hFF
    // For the second transfer frame, we expect 8'h5A
    SPI_transfer_execute(8'hA5,8'hFF,8'h5A);

    $display ("TEST 3(B): Alternating Bit Pattern (Data: 0x55):\n\n");
    // Our last transferred data was 8'h00, so we expect the first transfer frame to return 8'hFF
    // For the second transfer frame, we expect 8'hAA
    SPI_transfer_execute(8'h55,8'hFF,8'hAA);

    $display ("TEST 3(C): Border Case Pattern (Data: 0xFF):\n\n");
    // Our last transferred data was 8'h00, so we expect the first transfer frame to return 8'hFF
    // For the second transfer frame, we expect 8'h00
    SPI_transfer_execute(8'hFF,8'hFF,8'h00);

    $display ("TEST 3(D): Border Case Pattern (Data: 0x00):\n\n");
    // Our last transferred data was 8'h00, so we expect the first transfer frame to return 8'hFF
    // For the second transfer frame, we expect 8'hFF again
    SPI_transfer_execute(8'h00,8'hFF,8'hFF);

    buffer_time(); // buffer or settling time between two consecutive tests

    $display ("\n\n--- TEST 4: Robust Full Duplex Data Transfer Verification on random test data: ---\n\n");

    // Right now, we have 8'hFF sitting in the tx_shift_reg of Slave Module

    for(j = 0; j < 10; j = j + 1)
    begin
        temp = $random(data_seed) & 8'hFF; // generates a random 8 bit binary sequence
        SPI_transfer_execute(temp,8'hFF,~(temp));
    end

    //

    buffer_time();

    $display ("\n\n\n\n");

    $display("\n\n==============================\n\n");
    $display(" ------------ FINAL VERIFICATION REPORT ---------\n\n");
    $display("==============================\n\n");

    $display ("TOTAL TESTS    : %d\n",test_count);
    $display ("PASSED TESTS   : %d\n",pass_count);
    $display ("FAILED TESTS   : %d\n",fail_count);
    
    $display ("\n\n -------------------------- x ------------------------\n\n\n");
    
    buffer_time();

    $finish;

end

endmodule

