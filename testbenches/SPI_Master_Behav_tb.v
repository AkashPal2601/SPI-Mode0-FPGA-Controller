`timescale 1ns/1ps

module testbench;


// parameters
parameter CPOL = 1'b0;
parameter CPHA = 1'b0;
parameter CLOCK_DIV_VAL = 8; // number of times the frequency of SCLK is slower than clk
parameter HALF_PERIOD = CLOCK_DIV_VAL/2; // Half period when SCLK needs to toggle
parameter DATA_WIDTH = 8;
parameter STATE_IDLE = 2'b00;
parameter STATE_LOAD = 2'b01;
parameter STATE_TRANSMIT = 2'b10;
parameter STATE_STOP = 2'b11;
//

// Dummy Variables used in the testbench
integer flag = 0; // 1 --> errors have been detected; 0 --> no errors detected and success msg is printed
integer i;

// Input Variables
reg start,rst_n,clk; // MISO
reg [DATA_WIDTH-1:0] tx_data_in;
//
// Output Variables
wire SCLK,SS_n,data_ready; // MOSI
wire [DATA_WIDTH-1:0] rx_data_out;
//

// wiring MOSI and MISO pins together 
wire loopback_wire; // wire used to tie MOSI and MISO pins together



SPI_Master_Behav SPI_M (.rst_n(rst_n),.data_ready(data_ready),.start(start),.clk(clk),.MOSI(loopback_wire),.MISO(loopback_wire),.SCLK(SCLK),.SS_n(SS_n),.tx_data_in(tx_data_in),.rx_data_out(rx_data_out));

initial // generating GTKWave executable .vcd file
begin
    $dumpfile ("SPI_Protocol/SPI_Master/waves/SPI_Master_Behav.vcd");
    $dumpvars(0,testbench);    
end

initial // generates the fast microcontroller/FPGA clock
begin
    clk = 1'b0;
    forever #5 clk = ~clk; // time period of 10 ns (100 GHz)
end

initial // sets some default initial values to some variables
begin
    start = 1'b0; 
    tx_data_in = 8'b10101101; // change data input here
    rst_n = 1'b1; 
end

initial // self checking tests
begin

    // PHASE 1: Testing the functioning of the reset pin 

    $display ("\n\n[PHASE 1]...Testing ACTIVE LOW reset pin functioning...\n\n");
    rst_n = 1'b0; // setting reset pin LOW 
    #1; // 1 ns delay for stabilisation of signals
    rst_n = 1'b1; // pulling rst_n back to HIGH

    // if({SPI_M.curr_state[1:0],SS_n,MOSI,SPI_M.bit_count[2:0],data_ready,SCLK,SPI_M.clk_count[2:0],SPI_M.tx_shift_reg[DATA_WIDTH-1:0],SPI_M.rx_shift_reg[DATA_WIDTH-1:0]}
    // === {STATE_IDLE,1'b1,1'b0,3'b000,1'b0,1'b0,3'b000,8'b00000000,8'b00000000})
    // begin
    //     $display ("[SUCCESS]...[PHASE 1]...reset pin works perfectly !!\n\n");
    //     $display ("[EXPECTED]: [%0b]\n",{1'b1,1'b0,3'b000,1'b0,1'b0,3'b000,8'b00000000,8'b00000000});
    //     $display ("[RECEIVED]: [%1b%1b%3b%1b%1b%3b%8b%8b]\n\n",SS_n,MOSI,SPI_M.bit_count,data_ready,SCLK,SPI_M.clk_count,SPI_M.tx_shift_reg,SPI_M.rx_shift_reg);
        
    // end
    // else
    // begin
    //     $display ("[ERROR]...[PHASE 1]...reset pin does NOT function as intended !!\n");
    //     $display ("[EXPECTED]: [%026b]\n",{1'b1,1'b0,3'b000,1'b0,1'b0,3'b000,8'b00000000,8'b00000000});
    //     $display ("[RECEIVED]: [%1b%1b%3b%1b%1b%3b%8b%8b]\n\n",SS_n,MOSI,SPI_M.bit_count,data_ready,SCLK,SPI_M.clk_count,SPI_M.tx_shift_reg,SPI_M.rx_shift_reg);
    // end

    if(SPI_M.curr_state !== STATE_IDLE) // reset pin drops the curr_state to STATE_IDLE
    begin
        $display ("[ERROR]...[PHASE 1]... curr_state expected = %2b, curr_state received = %2b",STATE_IDLE,SPI_M.curr_state);
        flag = 1; // errors have been detected
    end
    if(SPI_M.next_state !== STATE_IDLE) // since start = 0, we expect next state to be the current state
    begin
        $display ("[ERROR]...[PHASE 1]... next_state expected = %2b, next_state received = %2b",STATE_IDLE,SPI_M.next_state);
        flag = 1; // errors have been detected
    end
    if(SS_n !== 1'b1) 
    begin
        $display ("[ERROR]...[PHASE 1]... SS_n expected = %1b, SS_n received = %1b",1'b1,SS_n);
        flag = 1; // errors have been detected
    end
    if(SPI_M.MOSI !== 1'b0) // we decided 1'b0 to be the default reset value of MOSI pin
    begin
         $display ("[ERROR]...[PHASE 1]... MOSI expected = %1b, MOSI received = %1b",1'b0,SPI_M.MOSI);
        flag = 1; // errors have been detected
    end
    if(SPI_M.bit_count !== 3'b000)
    begin
        $display ("[ERROR]...[PHASE 1]... bit_count expected = %3b, bit_count received = %3b",3'b000,SPI_M.bit_count);
        flag = 1; // errors have been detected
    end
    if(data_ready !== 1'b0)
    begin
        $display ("[ERROR]...[PHASE 1]... data_ready expected = %1b, data_ready received = %1b",1'b0,data_ready);
        flag = 1; // errors have been detected
    end
    if(SCLK !== CPOL)
    begin
        $display ("[ERROR]...[PHASE 1]... SCLK expected = %1b, SCLK received = %1b",CPOL,SCLK);
        flag = 1; // errors have been detected
    end
    if(SPI_M.clk_count !== 3'b000) // 
    begin
        $display ("[ERROR]...[PHASE 1]... clk_count expected = %3b, clk_count received = %3b",3'b000,SPI_M.clk_count);
        flag = 1; // errors have been detected
    end
    if(SPI_M.tx_shift_reg !== 8'b00000000)
    begin
        $display ("[ERROR]...[PHASE 1]... tx_shift_reg expected = %8b, tx_shift_reg received = %8b",8'b00000000,SPI_M.tx_shift_reg);
        flag = 1; // errors have been detected
    end
    if(SPI_M.rx_shift_reg !== 8'b00000000)
    begin
        $display ("[ERROR]...[PHASE 1]... rx_shift_reg expected = %8b, rx_shift_reg received = %8b",8'b00000000,SPI_M.rx_shift_reg);
        flag = 1; // errors have been detected
    end

    if(flag === 0) // means no errors have been detected
    begin
        $display ("[SUCCESS]...[PHASE 1]...reset pin works perfectly !!");
    end

    flag = 0; // resetting value of flag for other testing phases



    $display ("\n\n----End of [PHASE 1]----\n\n\n");

    // end of PHASE 1

                   // --------x--------

    // beginning of PHASE 2...

    // PHASE 2: Testing STATE_IDLE of the FSM without triggering the start signal (ACTIVE HIGH)

    $display ("\n\n[PHASE 2]...Testing STATE IDLE of the FSM Controller...\n\n");

    // we have kept start = 0, so that the upcoming posedge clk does not transition the curr_state from STATE_IDLE to STATE_LOAD
    @(posedge clk); // at this 1st clk posedge, the next state value (= STATE_IDLE) is fed into curr_state
    #1; // time allotted for stabilisation of signals

    if(SPI_M.curr_state !== STATE_IDLE)
    begin
        $display ("[ERROR]...[PHASE 2]... curr_state expected = %2b, curr_state received = %2b\n\n",STATE_IDLE,SPI_M.curr_state);
        flag = 1; // errors have been detected
    end
    if(SPI_M.next_state !== STATE_IDLE) // since start = 0, we expect next state to be the current state
    begin
        $display ("[ERROR]...[PHASE 2]... next_state expected = %2b, next_state received = %2b\n\n",STATE_IDLE,SPI_M.next_state);
        flag = 1; // errors have been detected
    end
    if(SS_n !== 1'b1) 
    begin
        $display ("[ERROR]...[PHASE 2]... SS_n expected = %1b, SS_n received = %1b\n\n",1'b1,SS_n);
        flag = 1; // errors have been detected
    end
    if(SPI_M.MOSI !== 1'b0) // we decided 1'b0 to be the default value of MOSI pin in STATE_IDLE
    begin
         $display ("[ERROR]...[PHASE 2]... MOSI expected = %1b, MOSI received = %1b\n\n",1'b0,SPI_M.MOSI);
        flag = 1; // errors have been detected
    end
    if(SPI_M.bit_count !== 3'b000)
    begin
        $display ("[ERROR]...[PHASE 2]... bit_count expected = %3b, bit_count received = %3b\n\n",3'b000,SPI_M.bit_count);
        flag = 1; // errors have been detected
    end
    if(data_ready !== 1'b0)
    begin
        $display ("[ERROR]...[PHASE 2]... data_ready expected = %1b, data_ready received = %1b\n\n",1'b0,data_ready);
        flag = 1; // errors have been detected
    end
    if(SCLK !== CPOL)
    begin
        $display ("[ERROR]...[PHASE 2]... SCLK expected = %1b, SCLK received = %1b\n\n",CPOL,SCLK);
        flag = 1; // errors have been detected
    end
    if(SPI_M.clk_count !== 3'b000)  
    begin
        $display ("[ERROR]...[PHASE 2]... clk_count expected = %3b, clk_count received = %3b\n\n",3'b000,SPI_M.clk_count);
        flag = 1; // errors have been detected
    end

    if(flag === 0) // means no errors have been detected
    begin
        $display ("[SUCCESS]...[PHASE 2]...STATE_IDLE is retained after reset, and next state remains STATE_IDLE (start = 0) !!\n\n");
    end

    flag = 0; // resetting value of flag for other testing phases
    
    $display ("\n\n----End of [PHASE 2]----\n\n\n");

    // end of PHASE 2

                // ------x-------

    // beginning of PHASE 3...

    // PHASE 3A: Testing the next state logic block when start = 1 

    $display ("\n\n[PHASE 3A]...Testing the next state logic block when start = 1...\n\n");

    @(negedge clk); // we are now at the clk negative edge
    start = 1'b1; // activating the start signal
    #1; // time for signal stabilisation
    // We expect the next state combinational block to get triggered, and next state to become STATE_LOAD
    if(SPI_M.next_state !== STATE_LOAD)
    begin
        $display ("[ERROR]...[PHASE 3A]...next_state expected = %2b, next_state received = %2b",STATE_LOAD,SPI_M.next_state);
        flag = 1; // errors have been detected
    end

    if(flag == 0)
    begin
        $display ("[SUCCESS]...[PHASE 3A]...next state updates to STATE_LOAD when start = 1");
    end

    flag = 0; // resetting value of flag for other testing phases

    $display ("\n\n----End of [PHASE 3A]----\n\n\n");

    // end of PHASE 3A...

    // beginning of PHASE 3B

    // PHASE 3B: testing the effect of sudden reset on the next state when start is held at 1

    $display ("\n\n[PHASE 3B]...Testing effect of sudden reset when start is held at 1...\n\n");

    // start is still held at 1, and next state is currently STATE_LOAD
    rst_n = 1'b0; // activating reset operation
    #1; // time for stabilisation of signals
    rst_n = 1'b1; // pulling reset back up high
    // actually we expect no change
    if(SPI_M.next_state !== STATE_LOAD)
    begin
        $display ("[ERROR]...[PHASE 3B]...next_state expected = %2b, next_state received = %2b",STATE_LOAD,SPI_M.next_state);
        flag = 1;
    end

    if(SPI_M.curr_state !== STATE_IDLE) 
    begin
        $display ("[ERROR]...[PHASE 3B]...curr_state expected = %2b, curr_state received = %2b",STATE_IDLE,SPI_M.curr_state);
        flag = 1;
    end

    if(flag == 0)
    begin
        $display ("[SUCCESS]...[PHASE 3B]...sudden reset produces expected outcomes (no change)");
    end

    flag = 0; // resetting value of flag for other testing phases

    $display ("\n\n----End of [PHASE 3B]----\n\n\n");

    // end of PHASE 3B...

            // ------x------

    // beginning of PHASE 4...

    $display ("\n\n[PHASE 4]...Testing STATE_LOAD of FSM Controller...\n\n");

    // at present, curr_state = STATE_IDLE and next_state = STATE_LOAD. start held at 1
    @(posedge clk); // at this posedge, curr_state should become next_state (STATE_LOAD)
    #1; // time alloted for all signals to arrive at a steady state value

    if(SPI_M.curr_state !== STATE_LOAD)
    begin
        $display ("[ERROR]...[PHASE 4]...curr_state expected = %2b, curr_state received = %2b",STATE_LOAD,SPI_M.curr_state);
        flag = 1;
    end

    if(SPI_M.next_state !== STATE_TRANSMIT)
    begin
        $display ("[ERROR]...[PHASE 4]...next_state expected = %2b, next_state received = %2b",STATE_TRANSMIT,SPI_M.next_state);
        flag = 1;
    end

    @(posedge clk); // at this clk posedge, the data loading and MOSI Pin update operations will take place
    #1; // time for stabilisation of signals

    if(SS_n !== 1'b0)
    begin
        $display ("[ERROR]...[PHASE 4]...SS_n expected = %1b, SS_n received = %1b",1'b0,SS_n);
        flag = 1;
    end

    if(SPI_M.MOSI !== tx_data_in[DATA_WIDTH-1])
    begin
        $display ("[ERROR]...[PHASE 4]...MOSI expected = %1b, MOSI received = %1b",tx_data_in[DATA_WIDTH-1],SPI_M.MOSI);
        flag = 1;
    end

    if(SPI_M.tx_shift_reg !== tx_data_in)
    begin
        $display ("[ERROR]...[PHASE 4]...tx_shift_reg expected = [%8b], tx_shift_reg received = [%8b]",tx_data_in,SPI_M.tx_shift_reg);
        flag = 1;
    end

    if(SPI_M.bit_count !== 3'b000)
    begin
        $display ("[ERROR]...[PHASE 4]...bit_count expected = [%3b], bit_count received = [%3b]",3'b000,SPI_M.bit_count);
        flag = 1;
    end

    if(data_ready !== 1'b0)
    begin
        $display ("[ERROR]...[PHASE 4]...data_ready expected = %1b, data_ready received = %1b",1'b0,data_ready);
        flag = 1;
    end

    if(SCLK !== CPOL)
    begin
        $display ("[ERROR]...[PHASE 4]...SCLK expected = %1b,SCLK received = %1b",CPOL,SCLK);
        flag = 1;
    end

    if(SPI_M.clk_count !== 3'b000)
    begin
        $display ("[ERROR]...[PHASE 4]...clk_count expected = [%3b], clk_count received = [%3b]",3'b000,SPI_M.clk_count);
        flag = 1;
    end

    if(flag == 0)
    begin
        $display ("[SUCCESS]...[PHASE 4]...STATE_LOAD Operations execute perfectly !!");
    end

    flag = 0; // resetting value of flag for other testing phases

    $display ("\n\n----End of [PHASE 4]----\n\n\n");

    // end of PHASE 4...

            // ------x------

    // beginning of PHASE 5...

    $display ("\n\n[PHASE 5]...Testing STATE_TRANSMIT of FSM Controller...\n\n");

    // the posedge clk in PHASE 4 should already have modified curr_state and next_state
    // we are currently in between the 1st full clock cycle in STATE_TRANSMIT
    // we shall first test the curr_state and next_state

    if(SPI_M.curr_state !== STATE_TRANSMIT)
    begin
        $display ("[ERROR]...[PHASE 5]...curr_state expected = %2b, curr_state received = %2b",STATE_TRANSMIT,SPI_M.curr_state);
        flag = 1;
    end
    
    if(SPI_M.next_state !== STATE_TRANSMIT)
    begin
        $display ("[ERROR]...[PHASE 5]...next_state expected = %2b, next_state received = %2b",STATE_TRANSMIT,SPI_M.next_state);
        flag = 1;
    end

    if(flag == 0)
    begin
        $display ("[SUCCESS]...[PHASE 5]...curr_state and next_state updated correctly");
    end

    flag = 0; // resetting value of flag for other testing phase

    $display ("\n\n");


    for(i=1;SPI_M.next_state !== STATE_STOP;i=i+1) // testing the data transmission
    begin
        @(posedge clk); // triggers the synchronous operations
        #1; // time for stabilisation of signals to their steady state

        // Checking value of clk_count

        if(SPI_M.clk_count !== (i % CLOCK_DIV_VAL)) 
        begin
            $display ("[ERROR]...[PHASE 5]...clk cycle no. %d...clk_count expected = %3b, clk_count received = %3b",(i+1),(i%(CLOCK_DIV_VAL)),SPI_M.clk_count);
            flag = 1;
        end

        // Checking value of bit_count

        if(SPI_M.bit_count !== (i-(i%CLOCK_DIV_VAL))/(CLOCK_DIV_VAL))
        begin
            $display ("[ERROR]...[PHASE 5]...clk cycle no. %d...bit_count expected = %3b, bit_count received = %3b",(i+1),((i-(i%CLOCK_DIV_VAL))/(CLOCK_DIV_VAL)),SPI_M.bit_count);
            flag = 1;
        end

        // checking value of SCLK

        if((i % CLOCK_DIV_VAL) < HALF_PERIOD) // SCLK should be 1'b0 in ths case
        begin
            if(SCLK !== CPOL)
            begin
                $display ("[ERROR]...[PHASE 5]...clk cycle no. %d...SCLK expected = %1b, SCLK received = %1b",(i+1),CPOL,SCLK);
                flag = 1;
            end
        end
        else // SCLK should be 1'b1
        begin
            if(SCLK !== !(CPOL))
            begin
                $display ("[ERROR]...[PHASE 5]...clk cycle no. %d...SCLK expected = %1b, SCLK received = %1b",(i+1),!(CPOL),SCLK);
                flag = 1;
            end
        end

        // checking value of SCLK_posedge 

        if((i % CLOCK_DIV_VAL) == (HALF_PERIOD - 1)) // means SCLK_posedge must be 1'b1
        begin
            if(SPI_M.SCLK_posedge !== 1'b1)
            begin
                $display ("[ERROR]...[PHASE 5]...clk cycle no. %d...SCLK_posedge expected = %1b, SCLK_posedge received = %1b",(i+1),1'b1,SPI_M.SCLK_posedge);
                flag = 1;
            end
        end
        else // means SCLK_posedge must be 1'b0
        begin
            if(SPI_M.SCLK_posedge !== 1'b0)
            begin
                $display ("[ERROR]...[PHASE 5]...clk cycle no. %d...SCLK_posedge expected = %1b, SCLK_posedge received = %1b",(i+1),1'b0,SPI_M.SCLK_posedge);
                flag = 1;
            end
        end

        // checking value of SCLK_negedge

        if((i % CLOCK_DIV_VAL) == (CLOCK_DIV_VAL - 1)) // means SCLK_negedge must be 1'b1
        begin
            if(SPI_M.SCLK_negedge !== 1'b1)
            begin
                $display ("[ERROR]...[PHASE 5]...clk cycle no. %d...SCLK_negedge expected = %1b, SCLK_negedge received = %1b",(i+1),1'b1,SPI_M.SCLK_negedge);
                flag = 1;
            end
        end
        else // means SCLK_negedge must be 1'b0
        begin
            if(SPI_M.SCLK_negedge !== 1'b0)
            begin
                $display ("[ERROR]...[PHASE 5]...clk cycle no. %d...SCLK_negedge expected = %1b, SCLK_negedge received = %1b",(i+1),1'b0,SPI_M.SCLK_negedge);
                flag = 1;
            end
        end

    end

    // the loop should have ended when next_state becomes STATE_STOP
    // this means we should be in the last clk cycle of STATE_TRANSMIT

    if((SPI_M.rx_shift_reg !== tx_data_in))
    begin
        $display ("[ERROR]...[PHASE 5]...problem with data transmission");
        $display ("%8b",SPI_M.rx_shift_reg);
        flag = 1;
    end

    if(flag == 0)
    begin
        $display ("[SUCCESS]...[PHASE 5]...data transmission takes place perfecty\n");
        $display ("tx_data_in = %8b, rx_shift_reg = %8b",tx_data_in,SPI_M.rx_shift_reg);
    end

    flag = 0; // resetting value of flag for other testing phase

    $display ("\n\n----End of [PHASE 5]----\n\n\n");

    // end of PHASE 5...

            // ------x------

    // beginning of PHASE 6...

    $display ("\n\n[PHASE 6A]...Testing curr_state and next_state of STATE_STOP of FSM Controller...\n\n");

    @(posedge clk); // this clk posedge triggers change of curr_state from STATE_TRANSMIT to STATE_STOP
    #1; // time for stabilisation of signals

    if(SPI_M.curr_state !== STATE_STOP)
    begin
        $display ("[ERROR]...[PHASE 6]...curr_state expected = %2b, curr_state received = %2b",STATE_STOP,SPI_M.curr_state);
        flag = 1;
    end

    if(SPI_M.next_state !== STATE_IDLE)
    begin
        $display ("[ERROR]...[PHASE 6]...next_state expected = %2b, next_state received = %2b",STATE_IDLE,SPI_M.next_state);
        flag = 1;
    end

    if(flag == 0)
    begin
        $display ("[SUCCESS]...[PHASE 6A]...curr_state and next_state modified as expected");
    end

    flag = 0; // resetting value of flag for other testing phase

    // end of PHASE 6A...

    // beginning of PHASE 6B...

    $display ("\n\n[PHASE 6B]...Testing otheer synchronous functionalities of STATE_STOP of FSM Controller...\n\n");

    @(posedge clk); // this clk posedge triggers the synchronous STATE_STOP operations
    #1; // time for stabilisation of signals to their steady state value

    if(SS_n !== 1'b1)
    begin
        $display ("[ERROR]...[PHASE 6]...SS_n expected = %1b, SS_n received = %1b",1'b1,SS_n);
        flag = 1;
    end

    if(SPI_M.MOSI !== 1'b0)
    begin
        $display ("[ERROR]...[PHASE 6]...MOSI expected = %1b, MOSI received = %1b",1'b0,SPI_M.MOSI);
        flag = 1;
    end

    if(SPI_M.bit_count !== 3'b000)
    begin
        $display ("[ERROR]...[PHASE 6]...bit_count expected = %3b, bit_count received = %3b",3'b000,SPI_M.bit_count);
        flag = 1;
    end

    if(data_ready !== 1'b1)
    begin
        $display ("[ERROR]...[PHASE 6]...data_ready expected = %1b, data_ready received = %1b",1'b1,data_ready);
        flag = 1;
    end

    if(rx_data_out !== SPI_M.rx_shift_reg)
    begin
        $display ("[ERROR]...[PHASE 6]...rx_data_out expected = [%8b], rx_data_out received = [%8b]",SPI_M.rx_shift_reg,rx_data_out);
        flag = 1;
    end

    if(flag == 0)
    begin
        $display ("[SUCCESS]...[PHASE 6B]...STATE_STOP of FSM Controller operates perfectly !!");
    end

    flag = 0;

    $display ("\n\n");

    $display ("------End of [PHASE 6]------\n\n\n");

    // end of PHASE 6





    
$finish;

end

endmodule