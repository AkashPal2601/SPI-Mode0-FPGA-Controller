`timescale 1ns/1ps
`define FPGA_DEBUG

module SPI_Top_Behav (start, rst_n, clk, data_ready, tx_data_in, rx_data_out
`ifdef FPGA_DEBUG
    ,
    dbg_Master_tx_reg_Top,
    dbg_Master_rx_reg_Top,
    dbg_Slave_tx_reg_Top,
    dbg_Slave_rx_reg_Top,
    dbg_SCLK
`endif
);

parameter DATA_WIDTH = 8; // 8 bit data to be exchanged
parameter CLOCK_DIV_VAL = 10000; // (ideally 10^8) number of times the frequency of SCLK is slower than clk (even number)
parameter HALF_PERIOD = CLOCK_DIV_VAL/2; // Half period when SCLK needs to toggle

input wire start; // start signal to indicate that input data is provided at tx_data_in pins
input wire rst_n; // asynchronous Active LOW reset pin 
input wire clk; // fast system clock
input wire [DATA_WIDTH-1:0] tx_data_in; // input pins for providing the data to be communicated to the Slave

output wire data_ready; // output signal to indicate that rx_data_out holds the data received from the Slave
output wire [DATA_WIDTH-1:0] rx_data_out; // output pins to hold the received data from the Slave

// FPGA Debug Output Pin Declaration
`ifdef FPGA_DEBUG
    wire [DATA_WIDTH-1:0] dbg_Master_tx_reg;
    wire [DATA_WIDTH-1:0] dbg_Master_rx_reg;
    wire [DATA_WIDTH-1:0] dbg_Slave_tx_reg;
    wire [DATA_WIDTH-1:0] dbg_Slave_rx_reg;

    output wire [DATA_WIDTH-1:0] dbg_Master_tx_reg_Top;
    output wire [DATA_WIDTH-1:0] dbg_Master_rx_reg_Top;
    output wire [DATA_WIDTH-1:0] dbg_Slave_tx_reg_Top;
    output wire [DATA_WIDTH-1:0] dbg_Slave_rx_reg_Top;
    output wire dbg_SCLK;

    assign dbg_Master_tx_reg_Top = dbg_Master_tx_reg;
    assign dbg_Master_rx_reg_Top = dbg_Master_rx_reg;
    assign dbg_Slave_tx_reg_Top = dbg_Slave_tx_reg;
    assign dbg_Slave_rx_reg_Top = dbg_Slave_rx_reg;
    assign dbg_SCLK = SCLK_wire;
`endif
//

// Internal nets and registers used in the top level module
wire SCLK_wire; // wire used to connect the SCLK pins of the Master and the Slave
wire SS_n_wire; // wire used to connect the SS_n pins of the Master and the Slave
wire MOSI_wire; // wire used to connect the MOSI pins of the Master and the Slave
wire MISO_wire; // wire used to connect the MISO pins of the Master and the Slave
//

// Instantiation of the SPI Master
SPI_Master_Behav #(
    .DATA_WIDTH(DATA_WIDTH),
    .CLOCK_DIV_VAL(CLOCK_DIV_VAL)
    // .HALF_PERIOD(HALF_PERIOD)
)
    SPI_Master (
    .start(start),
    .rst_n(rst_n),
    .clk(clk),
    .data_ready(data_ready),
    .tx_data_in(tx_data_in),
    .rx_data_out(rx_data_out),
    .SCLK(SCLK_wire),
    .SS_n(SS_n_wire),
    .MOSI(MOSI_wire),
    .MISO(MISO_wire)
// FPGA Debug Output Pin Declaration
`ifdef FPGA_DEBUG
    ,
    .dbg_Master_tx_reg(dbg_Master_tx_reg),
    .dbg_Master_rx_reg(dbg_Master_rx_reg)
`endif
//
);
//

// Instantiation of the SPI Slave
SPI_Slave_Behav #(
    .DATA_WIDTH(DATA_WIDTH)
)
    SPI_Slave (
    .clk(clk),
    .rst_n(rst_n),
    .SCLK(SCLK_wire),
    .SS_n(SS_n_wire),
    .MOSI(MOSI_wire),
    .MISO(MISO_wire)
// FPGA Debug Output Pins Declaration
`ifdef FPGA_DEBUG
    ,
    .dbg_Slave_tx_reg(dbg_Slave_tx_reg),
    .dbg_Slave_rx_reg(dbg_Slave_rx_reg)
`endif
//
);
//

endmodule