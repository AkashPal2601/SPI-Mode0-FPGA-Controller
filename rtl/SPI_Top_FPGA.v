`timescale 1ns/1ps
`define FPGA_DEBUG

module SPI_Top_FPGA (
    start_btn,
    rst_btn,
    clk,
    tx_data_in_sw,
    rx_data_out_LED,
    data_ready_LED,
    an,
    seg,
    SCLK_LED,
    display_mode_sw1,
    display_mode_sw2
);

parameter DATA_WIDTH = 8; // 8 bit data to be exchanged
parameter CLOCK_DIV_VAL = 10000; // (ideally 10^8)number of times the frequency of SCLK is slower than clk (even number)
parameter CLOCK_PERIOD = 10; // 10 ns clock period
// parameter HALF_PERIOD = CLOCK_DIV_VAL/2; // Half period when SCLK needs to toggle

parameter DEBOUNCE_COUNT = 1000; // (ideally 10^6) number of clock cycles the button signals must stay constant

input wire start_btn;
input wire rst_btn;
input wire clk;
input wire [DATA_WIDTH-1:0] tx_data_in_sw;
input wire display_mode_sw1;
input wire display_mode_sw2;

output wire [DATA_WIDTH-1:0] rx_data_out_LED;

output wire data_ready_LED;
output wire [3:0] an;
output wire [6:0] seg;
output wire SCLK_LED;

// Internal Nets and Reg
wire [DATA_WIDTH-1:0] dbg_Master_tx_reg_Top_FPGA;
wire [DATA_WIDTH-1:0] dbg_Master_rx_reg_Top_FPGA;
wire [DATA_WIDTH-1:0] dbg_Slave_tx_reg_Top_FPGA;
wire [DATA_WIDTH-1:0] dbg_Slave_rx_reg_Top_FPGA;

reg [(2*DATA_WIDTH-1):0] display_driver; 

// Single Cycel Start Pulse Generator
wire start_pulse;
assign start_pulse = ((start_btn_debounced) && !(start_btn_debounced_delay))? 1'b1 : 1'b0; // Active HIGH start pulse
//

//reg [2:1] start_sync;
reg start_sync_1;
reg start_sync_2;


//reg [$clog2(DEBOUNCE_COUNT):0] start_count; // never used !!
//reg start_btn_FF; // never used !!
reg start_btn_debounced_delay;

wire start_btn_debounced; /////

// start_sync = {1'b0,1'b0};
// start_btn_debounced = 1'b0;
// start_count = 0;

//reg [2:1] rst_sync = 2'b00; ////
reg rst_sync_1 = 1'b0;
reg rst_sync_2 = 1'b0;
wire rst_btn_synchronized;
assign rst_btn_synchronized = ~(rst_sync_2); ////


// rst_sync = {1'b0,1'b0};
// rst_btn_debounced = 1'b0;
// rst_count = 0;

// wire rst_n_pulse;
// assign rst_n_pulse = ((rst_btn_debounced) && !(rst_btn_debounced_delay))? 1'b0 : 1'b1;


//

// assign dbg_Master_tx_reg_Top_FPGA = dbg_Master_tx_reg_Top;
// assign dbg_Master_rx_reg_Top_FPGA = dbg_Master_rx_reg_Top;
// assign dbg_Slave_tx_reg_Top_FPGA = dbg_Slave_tx_reg_Top;
// assign dbg_Slave_rx_reg_Top_FPGA = dbg_Slave_rx_reg_Top;
//









// SPI Top level module instantiation

SPI_Top_Behav #(
    .DATA_WIDTH(DATA_WIDTH),
    .CLOCK_DIV_VAL(CLOCK_DIV_VAL)
    // .HALF_PERIOD(HALF_PERIOD)
)
SPI_Top (
    .start(start_pulse),
    .rst_n(rst_btn_synchronized),
    .clk(clk),
    .data_ready(data_ready_LED),
    .tx_data_in(tx_data_in_sw),
    .rx_data_out(rx_data_out_LED),
    .dbg_SCLK(SCLK_LED),
    .dbg_Master_tx_reg_Top(dbg_Master_tx_reg_Top_FPGA),
    .dbg_Master_rx_reg_Top(dbg_Master_rx_reg_Top_FPGA),
    .dbg_Slave_tx_reg_Top(dbg_Slave_tx_reg_Top_FPGA),
    .dbg_Slave_rx_reg_Top(dbg_Slave_rx_reg_Top_FPGA)
);

Seven_Seg_Controller Seg_Display_Unit (
    .clk(clk),
    .rst_n(rst_btn_synchronized), // but it isnt exactly deounced, its only synchronized
    .display_driver(display_driver),
    .an(an),
    .seg(seg)
);

Debouncer #(
    .DEBOUNCE_COUNT(DEBOUNCE_COUNT),
    .CLOCK_PERIOD(CLOCK_PERIOD)
) Debounce_start (
    .clk(clk),
    .rst_n(rst_btn_synchronized),
    .signal(start_sync_2), /////
    .signal_debounced(start_btn_debounced)
);


// Multiplexing Circuit for display mode switching on 7 segment display

always @(*)
begin
    case ({display_mode_sw1,display_mode_sw2})

    2'b00: // Master TX | Master RX (Full Master)
    begin
        display_driver = {dbg_Master_tx_reg_Top_FPGA,dbg_Master_rx_reg_Top_FPGA};
    end

    2'b01: // Slave TX | Slave RX (Full Slave)
    begin
        display_driver = {dbg_Slave_tx_reg_Top_FPGA,dbg_Slave_rx_reg_Top_FPGA};
    end

    2'b10: // Master TX | Slave RX (Outgoing (MOSI) Data Path)
    begin
        display_driver = {dbg_Master_tx_reg_Top_FPGA,dbg_Slave_rx_reg_Top_FPGA};
    end

    2'b11: // Slave TX | Master RX (Incoming (MISO) Data Path)
    begin
        display_driver = {dbg_Slave_tx_reg_Top_FPGA,dbg_Master_rx_reg_Top_FPGA};
    end

    default: // case 2'b10, since it shows the bit by bit full duplex transfer of data
    begin
        display_driver = {dbg_Master_tx_reg_Top_FPGA,dbg_Slave_rx_reg_Top_FPGA};    
    end

    endcase

end
//





// // start button synchronizer and debouncer

// 2 FF Synchronizer
always @(posedge clk or negedge rst_btn_synchronized)
begin
    if(!rst_btn_synchronized)
    begin
//        start_sync <= {1'b0,1'b0};
          start_sync_1 <= 1'b0;
          start_sync_2 <= 1'b0;
    end
    else
    begin
        start_sync_1 <= start_btn;
        start_sync_2 <= start_sync_1;
    end
end
//

// // Counter Circuit (Debouncer)
// always @(posedge clk or negedge rst_btn_synchronized)
// begin
//     if(!rst_btn_synchronized)
//     begin
//         start_btn_FF <= 1'b0;
//         start_btn_debounced <= 1'b0;
//         start_count <= 0;
//     end
//     else
//     begin
//         if(start_sync[2] != start_btn_FF)
//         begin
//             start_btn_FF <= start_sync[2];
//             start_count <= 0;
//         end
//         else if(start_count < DEBOUNCE_COUNT)
//         begin
//             start_count <= start_count + 1'b1;
//             if(start_count == DEBOUNCE_COUNT-1)
//             begin
//                 start_btn_debounced <= start_btn_FF; // holds start_btn_debounced steady until start_sync[2] changes
//             end
//         end
//         // else
//         // begin
//         //     start_btn_debounced <= start_btn_FF;
//         // end
//     end
// end
// //

// One cycle delayed version of debounced start signal
always @(posedge clk or negedge rst_btn_synchronized)
begin
    if(!rst_btn_synchronized)
    begin
        start_btn_debounced_delay <= 1'b0;
    end
    else
    begin
        start_btn_debounced_delay <= start_btn_debounced;
    end
end
//
// //

// // reset button synchronizer

// 2 FF Synchronizer for reset btn
always @(posedge clk)
begin
    rst_sync_1 <= rst_btn;
    rst_sync_2 <= rst_sync_1; // rst_sync[2] acts as debounced rst_btn
//    rst_sync <= {rst_sync[1],rst_btn}; // modified way of writing the same thing
end
//

// // Counter Circuit
// always @(posedge clk)
// begin
//     if(rst_count >= DEBOUNCE_COUNT)
//     begin
//         rst_btn_debounced <= rst_btn_FF;
//     end
//     else
//     begin
//         if(rst_sync[2] != rst_btn_FF)
//         begin
//             rst_btn_FF <= rst_sync[2];
//             rst_count <= 0;
//         end
//         else
//         begin
//             rst_count <= rst_count + 1;
//         end
//     end
// end
// //

// // One cycle reset pulse generator
// always @(posedge clk)
// begin
//     rst_btn_debounced_delay <= rst_btn_debounced;
// end
// //
// // //

endmodule