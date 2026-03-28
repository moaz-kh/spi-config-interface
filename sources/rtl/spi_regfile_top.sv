//==============================================================================
// SPI Slave + Register File Top Level
// Post-silicon configuration and debug interface
//==============================================================================

module spi_regfile_top (
    //--------------------------------------------------------------------------
    // SPI Interface (Directly to Pads)
    //--------------------------------------------------------------------------
    input  logic       sclk,
    input  logic       cs_n,
    input  logic       mosi,
    output logic       miso,        // Hi-Z when cs_n high

    //--------------------------------------------------------------------------
    // System Interface
    //--------------------------------------------------------------------------
    input  logic       sys_clk,
    input  logic       sys_rst_n,

    //--------------------------------------------------------------------------
    // Config Outputs (sysclk domain, latched after SPI transaction)
    //--------------------------------------------------------------------------
    output logic [7:0] cfg_enable,      // addr 0x01
    output logic [7:0] cfg_clk_div,     // addr 0x02
    output logic [7:0] cfg_gain,        // addr 0x03
    output logic [7:0] cfg_mode,        // addr 0x04

    //--------------------------------------------------------------------------
    // Status Inputs (sysclk domain, synchronized to SCLK for read)
    //--------------------------------------------------------------------------
    input  logic       status_lock,        // addr 0x80, bit[0]
    input  logic       status_fifo_empty,  // addr 0x81, bit[0]
    input  logic       status_fifo_full,   // addr 0x82, bit[0]
    input  logic       status_error        // addr 0x83, bit[0]
);

    //--------------------------------------------------------------------------
    // Internal Signals
    //--------------------------------------------------------------------------
    // Reset synchronizer output
    logic sclk_rst_n;

    // SPI slave to register file interface
    logic       rf_wr_en;
    logic [7:0] rf_addr;
    logic [7:0] rf_wdata;
    logic [7:0] rf_rdata;

    // Config from regfile (SCLK domain, raw)
    logic [7:0] cfg_enable_raw;
    logic [7:0] cfg_clk_div_raw;
    logic [7:0] cfg_gain_raw;
    logic [7:0] cfg_mode_raw;

    // Status synchronized to SCLK domain
    logic status_lock_sync;
    logic status_fifo_empty_sync;
    logic status_fifo_full_sync;
    logic status_error_sync;

    // CS_n synchronized to sysclk domain (for config latching)
    logic cs_n_synced;
    logic cs_n_prev;
    logic cs_n_rising;

    assign cs_n_rising = cs_n_synced && !cs_n_prev;

    //--------------------------------------------------------------------------
    // FPGA Power-up Initialization
    //--------------------------------------------------------------------------
    initial begin
        cs_n_prev   = 1'b1;
        cfg_enable  = 8'd0;
        cfg_clk_div = 8'd0;
        cfg_gain    = 8'd0;
        cfg_mode    = 8'd0;
    end

    //--------------------------------------------------------------------------
    // Reset Synchronizer (async assert, sync deassert for SCLK domain)
    //--------------------------------------------------------------------------
    cdc_reset #(
        .SYNC_STAGES (2)
    ) u_reset_sync (
        .clk         (sclk),
        .async_rst_n (sys_rst_n),
        .sync_rst_n  (sclk_rst_n)
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
    // Synchronize cs_n, latch config on rising edge
    //--------------------------------------------------------------------------
    cdc_bit #(.SYNC_STAGES(2), .RESET_VALUE(1'b1)) u_sync_cs_n (
        .clk       (sys_clk),
        .rst_n     (sys_rst_n),
        .async_in  (cs_n),
        .sync_out  (cs_n_synced)
    );

    // CS_n edge detection
    always_ff @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            cs_n_prev <= 1'b1;
        else
            cs_n_prev <= cs_n_synced;
    end

    // Latch config on cs_n rising edge (SPI transaction complete, data stable)
    always_ff @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            cfg_enable  <= 8'd0;
            cfg_clk_div <= 8'd0;
            cfg_gain    <= 8'd0;
            cfg_mode    <= 8'd0;
        end else if (cs_n_rising) begin
            cfg_enable  <= cfg_enable_raw;
            cfg_clk_div <= cfg_clk_div_raw;
            cfg_gain    <= cfg_gain_raw;
            cfg_mode    <= cfg_mode_raw;
        end
    end

    //--------------------------------------------------------------------------
    // Status CDC (sysclk -> SCLK domain)
    // Per-bit synchronizer, continuous sync
    //--------------------------------------------------------------------------
    cdc_bit #(.SYNC_STAGES(2), .RESET_VALUE(1'b0)) u_sync_lock (
        .clk       (sclk),
        .rst_n     (sclk_rst_n),
        .async_in  (status_lock),
        .sync_out  (status_lock_sync)
    );

    cdc_bit #(.SYNC_STAGES(2), .RESET_VALUE(1'b0)) u_sync_fifo_empty (
        .clk       (sclk),
        .rst_n     (sclk_rst_n),
        .async_in  (status_fifo_empty),
        .sync_out  (status_fifo_empty_sync)
    );

    cdc_bit #(.SYNC_STAGES(2), .RESET_VALUE(1'b0)) u_sync_fifo_full (
        .clk       (sclk),
        .rst_n     (sclk_rst_n),
        .async_in  (status_fifo_full),
        .sync_out  (status_fifo_full_sync)
    );

    cdc_bit #(.SYNC_STAGES(2), .RESET_VALUE(1'b0)) u_sync_error (
        .clk       (sclk),
        .rst_n     (sclk_rst_n),
        .async_in  (status_error),
        .sync_out  (status_error_sync)
    );

endmodule
