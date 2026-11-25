`timescale 1ns/1ps
`define FPGA_DEBUG

module SPI_Master_Behav (MISO,MOSI,SCLK,SS_n,clk,start,data_ready,rst_n,tx_data_in,rx_data_out
`ifdef FPGA_DEBUG
    ,
    dbg_Master_tx_reg,
    dbg_Master_rx_reg
`endif
);

// defining SPI Operation Mode
parameter CPOL = 1'b0;
parameter CPHA = 1'b0;
//

parameter DATA_WIDTH = 8; // 8 bit data to be exchanged
parameter CLOCK_DIV_VAL = 10000; // (ideally 10^8) number of times the frequency of SCLK is slower than clk (even number)
parameter HALF_PERIOD = CLOCK_DIV_VAL/2; // Half period when SCLK needs to toggle

// defining the FSM Controller states below
parameter STATE_IDLE = 2'b00;
parameter STATE_LOAD = 2'b01;
parameter STATE_TRANSMIT = 2'b10;
parameter STATE_STOP = 2'b11;
//

input wire start; // a start signal (Active HIGH) to initiate FSM Controller transition from state IDLE to state LOAD
input wire rst_n; // asynchronous reset signal (Active LOW) to force a reset on ongoing operation
(* mark_debug = "true" *) input wire MISO; // Master In Slave Out pin
input wire clk;  // clock running at microcontroller/FPGA's intrinsic frequency
input wire [DATA_WIDTH-1:0] tx_data_in; // input data from microcontroller/FPGA to be copied to tx_shift_reg

output wire MOSI; // Master Out Slave In pin

(* mark_debug = "true" *) output reg SCLK; // SPI Clock with a lower frequency
(* mark_debug = "true" *) output reg SS_n;   // Slave Select Pin (Active LOW)
(* mark_debug = "true" *) output reg data_ready = 1'b0; // signals the microcontroller that the data received from slave is ready (Active HIGH)
output reg [DATA_WIDTH-1:0] rx_data_out; // output data register available to microcontroller/FPGA storing copy of rx_shift_reg

// FPGA Debug Output pin declaration
`ifdef FPGA_DEBUG
    output wire [DATA_WIDTH-1:0] dbg_Master_tx_reg;
    output wire [DATA_WIDTH-1:0] dbg_Master_rx_reg;
    assign dbg_Master_tx_reg = tx_shift_reg;
    assign dbg_Master_rx_reg = rx_shift_reg;
`endif
//


(* mark_debug = "true" *) reg [DATA_WIDTH-1:0] tx_shift_reg; // Transmission Data Register in Master module
(* mark_debug = "true" *) reg [DATA_WIDTH-1:0] rx_shift_reg; // Receiver Data Register in Master module
(* mark_debug = "true" *) reg [1:0] curr_state; // stores the current state of the system
(* mark_debug = "true" *) reg [1:0] next_state; // stores the next state of the system
reg [$clog2(DATA_WIDTH)-1:0] bit_count = 0; // counter variable for state TRANSMIT, to count number of (sample + shift) cycles
reg [$clog2(CLOCK_DIV_VAL)-1:0] clk_count = 0; // counts the number of faster clk cycles during state transmit

// MOSI Output pin continuously driven by MSB of tx_shift_reg
assign MOSI = tx_shift_reg[DATA_WIDTH-1];

// SPI Clock Edge Detector Signals
wire SCLK_posedge = (curr_state == STATE_TRANSMIT) && (clk_count == HALF_PERIOD-1); // Becomes HIGH when positive edge of SPI Clock is detected
wire SCLK_negedge = (curr_state == STATE_TRANSMIT) && (clk_count == CLOCK_DIV_VAL-1); // Becomes HIGH when negative edge of SPI Clock is detected
//

// Finite State Machine Controller

// Next State Logic block (combinational)
always @(*)
begin
    if(!rst_n)
    begin
        next_state = STATE_IDLE; // This ensures no conflict in value of curr_state if rst_n and start are pressed together
    end
    else
    begin
        case (curr_state)

        STATE_IDLE:
        begin
            if(start) // start signal to signal transition to STATE_LOAD
            begin
                next_state = STATE_LOAD; // we assume start signal stays high for a minimum of 1 fast clk cycle, so that next_state = STATE_LOAD hits a clk posedge
            end
            else
            begin
                next_state = curr_state;
            end
        end

        STATE_LOAD:
        begin
            next_state = STATE_TRANSMIT; // STATE_LOAD exists only for 1 clock cycle
        end

        STATE_TRANSMIT:
        begin
            if(bit_count == (DATA_WIDTH-1) && SCLK_negedge) // This signals that the full data exchange has been completed
            // 7 full (sample + shift) cycles and 8th bit has been sampled in at the last SCLK_posedge
            begin
                next_state = STATE_STOP;
            end
            else
            begin
                next_state = curr_state;
            end
        end

        STATE_STOP:
        begin
            next_state = STATE_IDLE; // STATE_STOP exists only for 1 clock cycle
        end

        default: // to avoid unintended latches
        begin
            next_state = STATE_IDLE;
        end
    endcase

    end
end
// Next State Logic block ends


// Next State Register loading (laying out the Flip Flops for the FSM states)

always @(posedge clk or negedge rst_n) // we trigger it at the positive edge of the microcontroller/FPGA's internal clock
begin
    if(!rst_n)
    begin
        curr_state <= STATE_IDLE;
    end
    else
    begin
        curr_state <= next_state;
    end
end
// Next State Register Loading ends


// State Operations

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        SS_n <= 1'b1;
        // MOSI <= 1'b0; // default value
        bit_count <= 0;
        data_ready <= 1'b0;
        tx_shift_reg <= 0;
        rx_shift_reg <= 0;
    end
    else
    begin
        case (curr_state)
            
            STATE_IDLE:
            begin
                SS_n <= 1'b1; // ensures slaves are not active
                // MOSI <= 1'b0; // a default value
                bit_count <= 0;
                data_ready <= 1'b0; // sets data_ready back to 0 as it was 1 during STATE_STOP
            end

            STATE_LOAD:
            begin
                SS_n <= 1'b0; // signals the slave to be activated
                // MOSI <= tx_data_in[DATA_WIDTH-1]; // MSB of input data for tx_shift_reg
                bit_count <= 0;
                data_ready <= 1'b0;
                tx_shift_reg <= tx_data_in; // loading input data from microncontroller to tx_shift_reg
            end

            STATE_TRANSMIT:
            begin
                SS_n <= 1'b0; // keeping the slave activated
                if(SCLK_posedge) // sample the data from MISO pin into rx_shift_reg
                begin
                    rx_shift_reg <= {rx_shift_reg[DATA_WIDTH-2:0],MISO}; // sampling in the MISO pin data into rx_shift_reg
                end
                else if(SCLK_negedge) // shifts data in tx_shift_reg and MOSI pin
                begin
                    // MOSI <= tx_shift_reg[DATA_WIDTH-2]; // MSB of transmitting register
                    bit_count <= bit_count + 1; // end of one SCLK (Sample + Shift) cycle
                    tx_shift_reg <= {tx_shift_reg[DATA_WIDTH-2:0],1'b0}; // 1'b0 is the filler value
                end
                else
                begin
                    
                end
                
            end

            STATE_STOP:
            begin
                SS_n <= 1'b1; // Deactivating the Slave, as data transmission for the current pass is over
                // MOSI <= 1'b0; // a default value
                bit_count <= 0;
                rx_data_out <= rx_shift_reg; // making the received contents in rx_shift_reg accessible at the output pins
                data_ready <= 1'b1; // Signals the microcontroller that received data is ready on output pins rx_data_out
            end

            default: // same as STATE_IDLE
            begin
                SS_n <= 1'b1; // ensures slaves are not active
                // MOSI <= 1'b0; // a default value
                bit_count <= 0;
                data_ready <= 1'b0; // sets data_ready back to 0 as it was 1 during STATE_STOP
            end
            
        endcase
    end

end


// SPI Clock Generator 

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        SCLK <= CPOL;
        clk_count <= 0;
    end
    else
    begin
        if(curr_state == STATE_TRANSMIT)
        begin
            if(clk_count == HALF_PERIOD-1)
            begin
                SCLK <= ~SCLK;
                clk_count <= clk_count + 1;
            end
            else if(clk_count == CLOCK_DIV_VAL-1)
            begin
                SCLK <= ~SCLK;
                clk_count <= 0;
            end
            else
            begin
                clk_count <= clk_count + 1;
            end
        end
        else // if current state is one among IDLE, LOAD or STOP
        begin
            SCLK <= CPOL;
            clk_count <= 0;
        end
    end
end

endmodule