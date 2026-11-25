// Notes:
// 1) Suggested to set rx_data_out = 0 when reset pin is triggered (modify SPI_Master_Behav)


`timescale 1ns/1ps

module testbench;

// =====================================================
// ----PARAMETER DECLARATION AND CLOCK TIMING----
// =====================================================
parameter DATA_WIDTH = 8; // decides number of bits of full duplex data transfer per frame
parameter CLOCK_PERIOD = 10; // fast system clock period in ns
parameter CPOL = 1'b0; // Clock Polarity
parameter CPHA = 1'b0; // Clock Phase
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
reg                    start; 
reg                    rst_n;
reg                    clk;
reg  [DATA_WIDTH-1:0]  tx_data_in;

wire [DATA_WIDTH-1:0]  rx_data_out;
wire                   data_ready;
// //

// =====================================================
// ----TEST STATUS FLAGS----
// =====================================================
integer pass_count = 0;
integer fail_count = 0;
integer test_count = 0;
integer flag = 0; // flag = 1 implies there has been an error in a particular test fragment
integer data_seed = 5;
integer reset_seed = 10;
integer i = 0;
integer random_integer = 0; // used for mid-transfer resets
integer SPI_Master_Error = 0;
integer SPI_Slave_Error = 0;
integer clk_cycles_delay;


// =====================================================
// ----Internal Nets and Registers----
// =====================================================
reg [DATA_WIDTH-1:0] temp; // used to hold the random generated 8 bit data for TEST 4


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

SPI_Top_Behav #(
    .DATA_WIDTH(DATA_WIDTH)
)
SPI_Top (
    .start(start),
    .rst_n(rst_n),
    .clk(clk),
    .tx_data_in(tx_data_in),
    .rx_data_out(rx_data_out),
    .data_ready(data_ready)
);
// //

// =====================================================
// ----MODULAR TASK DEFINITIONS----
// =====================================================

// Task 1: Asynchronous ACTIVE LOW reset pulse
task reset_pulse;
begin
    $display ("\n\n[%0t ns] Applying ACTIVE LOW System Reset...\n\n",$time);
    rst_n = 1'b0; // activated
    #(CLOCK_PERIOD * 5);
    rst_n = 1'b1; // deactivated
    #(CLOCK_PERIOD * 5);
    $display ("[%0t ns] System Reset Successfully applied.",$time);
end
endtask
//

// Task 2: Single Clock Cycle start pulse (generated from bouncy pushbutton input by the Top Level Wrapper debouncer circuit)
task start_pulse;
begin
    $display ("\n[%0t ns] Applying Single Cycle Start Pulse Signal...\n\n",$time);
    @(posedge clk); // the top level debouncer ensures generation of an edge to edge one cycle start pulse
    #1; // models synchronizer and debouncer propagation delays
    start = 1'b1;
    @(posedge clk);
    #1; // models synchronizer and debouncer propagation delays
    start = 1'b0;
    $display("[%0t ns] Single Cycle start pulse successfully applied.\n\n",$time);
end
endtask
//

// Task 3: Buffer time of 10 clock cycles between two tests
// This kind of ensures that bugs and metastable states from one failed test don't affect the other tests
task buffer_time;
begin
    #(CLOCK_PERIOD * 10);
end
endtask
//

// Task 4: 2 Frame SPI Full Duplex Data Exchange ( 1 frame computation latency)
// Data sent over to the Slave in the 1st transfer is processed and received back by the Master in the 2nd transfer
// We transfer a dummy value 0x00 to the Slave in every 2nd iteration in order to receive the processed output of the data sent over in 1st transfer
task SPI_transfer_execute;
    input [DATA_WIDTH-1:0] tx_data;
    input [DATA_WIDTH-1:0] expected_frame1_rx;
    input [DATA_WIDTH-1:0] expected_frame2_rx;
    begin

        // Frame 1: Passing tx_data over to the Slave and receiving the pre-existing value in the Slave's tx

        $display ("\n\n[%0t ns] [FRAME 1] Sending data to Slave: 0x%02x...\n\n",$time,tx_data);
        tx_data_in = tx_data;
        start_pulse();
        wait (data_ready == 1'b1);
        #(CLOCK_PERIOD * 2); 
        // data should be ready in rx_data_out by now...
        if(rx_data_out === expected_frame1_rx)
        begin
            $display ("[PASS]...[FRAME 1] data verified: Expected 0x%02x, Received 0x%02x.\n\n",expected_frame1_rx,rx_data_out);
            pass_count = pass_count + 1;
            test_count = test_count + 1;
        end
        else
        begin
            $display ("[FAIL]...[FRAME 1] data mismatch: Expected 0x%02x, Received 0x%02x.\n\n",expected_frame1_rx,rx_data_out);
            fail_count = fail_count + 1;
            test_count = test_count + 1;
        end

        // Frame 2: Sending dummy value 0x00 over to Slave to receive the computed value of 1st transfer

        $display ("\n\n[%0t ns] [FRAME 2] Sending dummy data 0x00 to Slave...\n\n",$time);
        tx_data_in = 8'h00;
        start_pulse();
        wait (data_ready == 1'b1);
        #(CLOCK_PERIOD * 2);
        // data should be ready in rx_data_out by now...
        if(rx_data_out == expected_frame2_rx)
        begin
            $display ("[PASS]...[FRAME 2] data verified: Expected 0x%02x, Received 0x%02x.\n\n",expected_frame2_rx,rx_data_out);
            pass_count = pass_count + 1;
            test_count = test_count + 1;
        end
        else
        begin
            $display ("[FAIL]...[FRAME 2] data mismatch: Expected 0x%02x, Received 0x%02x.\n\n",expected_frame2_rx,rx_data_out);
            fail_count = fail_count + 1;
            test_count = test_count + 1;
        end
    end
endtask
//

// Task 5: Mid-Transfer Asynchronous Reset 
// This pulls an asynchronous reset operation abruptly in between a data transmission
// Passing this test implies that the reset pin can be used anytime to force a reset, not just power on initialization
task mid_transfer_reset;
input [$clog2(70):0] clock_cycles_delay;
begin
    $display ("Starting a Mid Transfer Reset Test...\n\n");
    tx_data_in = $random(data_seed) & 8'hFF; // generates a data byte to be transmitted
    $display("Data input given: 0x%02x\n\n",tx_data_in);

    #1; // a time delay gap between applying tx_data_in and providing start pulse
    start_pulse(); // applies a start pulse to initiate data transfer...

    $display("[TIME] before delay = %0t",$time);
    $display ("clock_cycles_delay = %d",clock_cycles_delay);
    #(CLOCK_PERIOD * clock_cycles_delay); // we now reach somewhere in the middle of the transfer
    $display("[TIME] after delay = %0t",$time);
    reset_pulse(); // we apply a sudden, asynchronous reset pulse to the hardware

    // Probing internal signals to check if reset functioned correctly..

    // // Checking the internal signals in SPI_Master...

    // curr_state
    if(SPI_Top.SPI_Master.curr_state !== Master_STATE_IDLE)
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Master curr_state Expected: %2b, Received: %2b\n",Master_STATE_IDLE,SPI_Top.SPI_Master.curr_state);
        flag = 1;
    end

    // next_state
    if(SPI_Top.SPI_Master.next_state !== Master_STATE_IDLE)
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Master next_state Expected: %2b, Received: %2b\n",Master_STATE_IDLE,SPI_Top.SPI_Master.next_state);
        flag = 1;
    end

    // tx_shift_reg
    if(SPI_Top.SPI_Master.tx_shift_reg !== 8'h00)
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Master tx_shift_reg Expected: 0x%02x, Received: 0x%02x\n",8'h00,SPI_Top.SPI_Master.tx_shift_reg);
        flag = 1;
    end

    // rx_shift_reg
    if(SPI_Top.SPI_Master.rx_shift_reg !== 8'h00)
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Master rx_shift_reg Expected: 0x%02x, Received: 0x%02x\n",8'h00,SPI_Top.SPI_Master.rx_shift_reg);
        flag = 1;
    end

    // SS_n (Slave Select Pin)
    if(SPI_Top.SPI_Master.SS_n !== 1'b1)
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Master SS_n Expected: %1b, Received: %1b\n",1'b1,SPI_Top.SPI_Master.SS_n);
        flag = 1;
    end

    // SCLK (SPI Clock)
    if(SPI_Top.SPI_Master.SCLK !== CPOL)
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Master SCLK Expected: %1b, Received: %1b\n",CPOL,SPI_Top.SPI_Master.SCLK);
        flag = 1;
    end

    // bit_count
    if(SPI_Top.SPI_Master.bit_count !== 0)
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Master bit_count Expected: %b, Received: %b\n",0,SPI_Top.SPI_Master.bit_count);
        flag = 1;
    end

    // clk_count
    if(SPI_Top.SPI_Master.clk_count !== 0)
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Master clk_count Expected: %b, Received: %b\n",0,SPI_Top.SPI_Master.clk_count);
        flag = 1;
    end

    // data_ready
    if(SPI_Top.SPI_Master.data_ready !== 1'b0)
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Master data_ready Expected: %1b, Received: %1b\n",1'b0,SPI_Top.SPI_Master.data_ready);
        flag = 1;
    end

    if(flag == 1) // reset pin unsuccessful for SPI_Master
    begin
        SPI_Master_Error = 1; // flags that mid-transfer reset was unsuccessful for SPI_Master 
    end

    flag = 0; // getting ready for probing into SPI_Slave

    // // Checking Internal Signals in SPI_Slave...

    // curr_state
    if(SPI_Top.SPI_Slave.curr_state !== Slave_STATE_IDLE)
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Slave curr_state Expected: %2b, Received: %2b\n",Slave_STATE_IDLE,SPI_Top.SPI_Slave.curr_state);
        flag = 1;
    end

    // next_state
    if(SPI_Top.SPI_Slave.next_state !== Slave_STATE_IDLE)
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Slave next_state Expected: %2b, Received: %2b\n",Slave_STATE_IDLE,SPI_Top.SPI_Slave.next_state);
        flag = 1;
    end

    // tx_shift_reg
    if(SPI_Top.SPI_Slave.tx_shift_reg !== 8'h00)
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Slave tx_shift_reg Expected: 0x%02x, Received: 0x%02x\n",8'h00,SPI_Top.SPI_Slave.tx_shift_reg);
        flag = 1;
    end

    // rx_shift_reg
    if(SPI_Top.SPI_Slave.rx_shift_reg !== 8'h00)
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Slave rx_shift_reg Expected: 0x%02x, Received: 0x%02x\n",8'h00,SPI_Top.SPI_Slave.rx_shift_reg);
        flag = 1;
    end

    // bit_count
    if(SPI_Top.SPI_Slave.bit_count !== 0)
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Slave bit_count Expected: %b, Received: %b\n",0,SPI_Top.SPI_Slave.bit_count);
        flag = 1;
    end

    // SS_n_sync (Slave Select Pin 2 FF Synchronizer)
    if(SPI_Top.SPI_Slave.SS_n_sync !== 2'b11)
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Slave SS_n_sync Expected: %2b, Received: %2b\n",2'b11,SPI_Top.SPI_Slave.SS_n_sync);
        flag = 1;
    end

    // SCLK_sync (Serial SPI Clock 2 FF Synchronizer)
    if(SPI_Top.SPI_Slave.SCLK_sync !== {CPOL,CPOL})
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Slave SCLK_sync Expected: %2b, Received: %2b\n",{CPOL,CPOL},SPI_Top.SPI_Slave.SCLK_sync);
        flag = 1;
    end

    // MISO Pin (we expect this to be tri_stated)
    if(SPI_Top.SPI_Slave.MISO !== 1'bz)
    begin
        $display("[FAIL] Mid-Transfer Reset...SPI_Slave MISO Expected: %1b, Received: %1b\n",1'bz,SPI_Top.SPI_Slave.MISO);
        flag = 1;
    end

    
    if(flag == 1)
    begin
        SPI_Slave_Error = 1;
    end

    flag = 0;


    // // Checking Final Results of Mid-Transfer Reset...
    if(SPI_Master_Error == 1)
    begin
        $display ("\n\n[FAIL] Mid-Transfer Reset...SPI_Master did not reset properly\n\n");
    end

    if(SPI_Slave_Error == 1)
    begin
        $display ("\n\n[FAIL] Mid-Transfer Reset...SPI_Slave did not reset properly\n\n");
    end 

    if((SPI_Master_Error == 1) || (SPI_Slave_Error == 1))
    begin
        test_count = test_count + 1;
        fail_count = fail_count + 1;
    end

    if((SPI_Master_Error == 0) && (SPI_Slave_Error == 0))
    begin
        $display("\n\n[PASS] Mid-Transfer Reset...Full Hardware Reset Successful\n\n");
        test_count = test_count + 1;
        pass_count = pass_count + 1;
    end

    SPI_Master_Error = 0;
    SPI_Slave_Error = 0;   

end
endtask

// =====================================================
// ----GTKWAVE .vcd FILE GENERATION----
// =====================================================
initial
begin
    $dumpfile("SPI_Protocol/SPI_Top/waves/SPI_Top_Behav.vcd");
    $dumpvars(0,testbench);
end
//

// =====================================================
// ----ASSIGNING INITIAL VALUES TO DATA I/O PINS----
// =====================================================
initial 
begin
    rst_n = 1'b1;
    start = 1'b0;
end
//

// =====================================================
// ----MAIN TESTBENCH EXECUTION----
// =====================================================

initial
begin
    $display ("\n===================================================\n");
    $display ("--------STARTING VERIFICATION OF TOP LEVEL SPI MODULE---------");
    $display ("\n===================================================\n");


    $display ("\n--- TEST 1: Power On Initialization and Asynchronous Reset Checks ---\n\n");

    #(CLOCK_PERIOD * 5); // to observe in waveform that pins were in unknown state before reset pulse is applied
    reset_pulse(); // sending over a reset pulse to the system

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

    if(data_ready !== 1'b0)
    begin
        $display("\n\n[FAIL] TEST 1: ACTIVE LOW Reset Pin --- 'data_ready' expected: %1b, 'data_ready' obtained: %1b\n\n",1'b0,data_ready);
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

    buffer_time(); // ensures a gap of 10 clock cycles between two consecutive tests



    $display ("\n\n--- TEST 2: Start Pulse Verification and Basic Operation of the Circuit ---\n\n");

    // we supply input data as 8'h00 and test if the start pulse actually activates the data transmission

    tx_data_in = 8'h00; // input data
    start_pulse(); // applies a single cycle start pulse to initiate full duplex data transfer

    wait (data_ready == 1'b1);
    // for the first iteration frame, just after reset, we expect rx_data_out = 8'h00
    // actually, the sole fact that data_ready goes high and the terminal doesnt get caught up in an infinite loop is proof that start pulse worked

    if(rx_data_out !== 8'h00)
    begin
        $display ("\n\n[FAIL] TEST 2: Start Pulse does not function as expected");
        fail_count = fail_count + 1;
        test_count = test_count + 1;
        flag = 1;
    end

    if(flag == 0) // no errors
    begin
        $display("\n\n[PASS] TEST 2: Start Pulse functions as intended.\n\n");
        pass_count = pass_count + 1;
        test_count = test_count + 1;
    end

    flag = 0; // preparing flag variable for other tests

    buffer_time(); // ensures a gap of 10 clock cycles between consecutive tests


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

    for(i = 0; i < 10; i = i + 1)
    begin
        temp = $random(data_seed) & 8'hFF; // generates a random 8 bit binary sequence
        SPI_transfer_execute(temp,8'hFF,~(temp));
    end

    //

    buffer_time();

    $display ("\n\n--- TEST 5: Sudden Asynchronous Mid-Transfer Hardware Reset: ---\n\n");
    // This test ensures the durability and appropriate response of the hardware to mid-transfer resets...

    // From the waveforms, a Single byte transfer takes around 65-70 clock cycles
    // We have generated a random integer between 35 to 70 to test if the circuit resetted appropriately
    for(i = 0; i < 10; i = i + 1)
    begin
        clk_cycles_delay = ({$random(reset_seed)} + 35) % 71; // generates a random number between 0 to 70
        $display ("clk_cycles_delay = %d",clk_cycles_delay);
        // this random number decides the number of clock cycles delay after which a reset will be enforced mid-transfer
        mid_transfer_reset(clk_cycles_delay); 
    end

    buffer_time();

    $display ("\n\n\n\n");

    $display("\n\n==============================\n\n");
    $display(" ------------ FINAL VERIFICATION REPORT ---------\n\n");
    $display("==============================\n\n");

    $display ("TOTAL TESTS    : %d\n",test_count);
    $display ("PASSED TESTS   : %d\n",pass_count);
    $display ("FAILED TESTS   : %d\n",fail_count);

    $display ("\n\n -------------------------- x ------------------------\n\n\n");

    $finish;
end


endmodule