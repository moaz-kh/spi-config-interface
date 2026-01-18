//==============================================================================
// SPI Slave + Register File Top Level
// Post-silicon configuration and debug interface
//==============================================================================

module spi_regfile_top (
    //--------------------------------------------------------------------------
    // SPI Interface (Directly to Pads)
    //--------------------------------------------------------------------------
    input  wire       sclk,
    input  wire       cs_n,
    input  wire       mosi,
    output wire       miso,        // Hi-Z when cs_n high

    //--------------------------------------------------------------------------
    // System Interface
    //--------------------------------------------------------------------------
    input  wire       sys_clk,
    input  wire       sys_rst_n,

    //--------------------------------------------------------------------------
    // Config Outputs (sysclk domain, latched after SPI transaction)
    //--------------------------------------------------------------------------
    output wire [7:0] cfg_enable,      // addr 0x01
    output wire [7:0] cfg_clk_div,     // addr 0x02
    output wire [7:0] cfg_gain,        // addr 0x03
    output wire [7:0] cfg_mode,        // addr 0x04

    //--------------------------------------------------------------------------
    // Status Inputs (sysclk domain, synchronized to SCLK for read)
    //--------------------------------------------------------------------------
    input  wire       status_lock,        // addr 0x80, bit[0]
    input  wire       status_fifo_empty,  // addr 0x81, bit[0]
    input  wire       status_fifo_full,   // addr 0x82, bit[0]
    input  wire       status_error        // addr 0x83, bit[0]
);

    //--------------------------------------------------------------------------
    // Internal Signals
    //--------------------------------------------------------------------------
    // Reset synchronizer output
    wire sclk_rst_n;

    // SPI slave to register file interface
    wire       rf_wr_en;
    wire [7:0] rf_addr;
    wire [7:0] rf_wdata;
    wire [7:0] rf_rdata;

    // Config from regfile (SCLK domain, raw)
    wire [7:0] cfg_enable_raw;
    wire [7:0] cfg_clk_div_raw;
    wire [7:0] cfg_gain_raw;
    wire [7:0] cfg_mode_raw;

    // Status synchronized to SCLK domain
    wire status_lock_sync;
    wire status_fifo_empty_sync;
    wire status_fifo_full_sync;
    wire status_error_sync;

    //--------------------------------------------------------------------------
    // Reset Synchronizer
    // Async assert, sync deassert for SCLK domain
    //--------------------------------------------------------------------------
    reset_sync u_reset_sync (
        .sclk       (sclk),
        .sys_rst_n  (sys_rst_n),
        .sclk_rst_n (sclk_rst_n)
    );

    //--------------------------------------------------------------------------
    // SPI Slave Interface
    // Handles SPI Mode 0 protocol, deserialize cmd/addr/data
    //--------------------------------------------------------------------------
    spi_slave u_spi_slave (
        // SPI Interface
        .sclk       (sclk),
        .cs_n       (cs_n),
        .mosi       (mosi),
        .miso       (miso),
        // Register File Interface
        .rf_wr_en   (rf_wr_en),
        .rf_addr    (rf_addr),
        .rf_wdata   (rf_wdata),
        .rf_rdata   (rf_rdata)
    );

    //--------------------------------------------------------------------------
    // Register File
    // Version reg, RW config regs, RO status mux
    //--------------------------------------------------------------------------
    regfile u_regfile (
        .sclk       (sclk),
        .sclk_rst_n (sclk_rst_n),
        // SPI Slave Interface
        .wr_en      (rf_wr_en),
        .addr       (rf_addr),
        .wdata      (rf_wdata),
        .rdata      (rf_rdata),
        // Config Outputs (SCLK domain)
        .cfg_enable  (cfg_enable_raw),
        .cfg_clk_div (cfg_clk_div_raw),
        .cfg_gain    (cfg_gain_raw),
        .cfg_mode    (cfg_mode_raw),
        // Status Inputs (synchronized)
        .status_lock       (status_lock_sync),
        .status_fifo_empty (status_fifo_empty_sync),
        .status_fifo_full  (status_fifo_full_sync),
        .status_error      (status_error_sync)
    );

    //--------------------------------------------------------------------------
    // Config CDC (SPI -> sysclk domain)
    // 2FF sync cs_n, latch config on rising edge
    //--------------------------------------------------------------------------
    cfg_cdc u_cfg_cdc (
        // System Clock Domain
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        // CS_n from SPI
        .cs_n       (cs_n),
        // Config Inputs (SCLK domain)
        .cfg_enable_in  (cfg_enable_raw),
        .cfg_clk_div_in (cfg_clk_div_raw),
        .cfg_gain_in    (cfg_gain_raw),
        .cfg_mode_in    (cfg_mode_raw),
        // Config Outputs (sysclk domain)
        .cfg_enable_out  (cfg_enable),
        .cfg_clk_div_out (cfg_clk_div),
        .cfg_gain_out    (cfg_gain),
        .cfg_mode_out    (cfg_mode)
    );

    //--------------------------------------------------------------------------
    // Status CDC (sysclk -> SCLK domain)
    // 2FF per bit, continuous sync
    //--------------------------------------------------------------------------
    status_cdc u_status_cdc (
        // SCLK Domain
        .sclk       (sclk),
        .sclk_rst_n (sclk_rst_n),
        // Status Inputs (sysclk domain)
        .status_lock_in       (status_lock),
        .status_fifo_empty_in (status_fifo_empty),
        .status_fifo_full_in  (status_fifo_full),
        .status_error_in      (status_error),
        // Status Outputs (SCLK domain)
        .status_lock_out       (status_lock_sync),
        .status_fifo_empty_out (status_fifo_empty_sync),
        .status_fifo_full_out  (status_fifo_full_sync),
        .status_error_out      (status_error_sync)
    );

endmodule
