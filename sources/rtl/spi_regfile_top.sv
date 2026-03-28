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
    output logic [7:0] cfg_thresh,      // addr 0x03
    output logic [3:0] cfg_ctrl,        // addr 0x05[7:4]
    output logic       cfg_tx_en,       // addr 0x07[7]
    output logic       cfg_rx_en,       // addr 0x07[6]
    output logic [1:0] cfg_lane_sel,    // addr 0x07[2:1]
    output logic       cfg_loopback,    // addr 0x07[0]
    output logic [2:0] cfg_gain_fine,   // addr 0x09[7:5]
    output logic [7:0] cfg_gain,        // addr 0x84
    output logic [7:0] cfg_mode,        // addr 0x85

    //--------------------------------------------------------------------------
    // Status Inputs (sysclk domain, synchronized to SCLK for read)
    //--------------------------------------------------------------------------
    input  logic       status_busy,        // addr 0x05, bit[3]
    input  logic [3:0] status_code,        // addr 0x08, bits[7:4]
    input  logic       status_temp_warn,   // addr 0x09, bit[4]
    input  logic [7:0] status_flags,       // addr 0x0A
    input  logic [3:0] status_rx_err,      // addr 0x0B, bits[7:4]
    input  logic [3:0] status_tx_err,      // addr 0x0B, bits[3:0]
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
    logic [7:0] cfg_thresh_raw;
    logic [3:0] cfg_ctrl_raw;
    logic       cfg_tx_en_raw;
    logic       cfg_rx_en_raw;
    logic [1:0] cfg_lane_sel_raw;
    logic       cfg_loopback_raw;
    logic [2:0] cfg_gain_fine_raw;
    logic [7:0] cfg_gain_raw;
    logic [7:0] cfg_mode_raw;

    // Status synchronized to SCLK domain
    logic       status_busy_sync;
    logic [3:0] status_code_sync;
    logic       status_temp_warn_sync;
    logic [7:0] status_flags_sync;
    logic [3:0] status_rx_err_sync;
    logic [3:0] status_tx_err_sync;
    logic       status_lock_sync;
    logic       status_fifo_empty_sync;
    logic       status_fifo_full_sync;
    logic       status_error_sync;

    // CS_n synchronized to sysclk domain (for config latching)
    logic cs_n_synced;
    logic cs_n_prev;
    logic cs_n_rising;

    assign cs_n_rising = cs_n_synced && !cs_n_prev;

    //--------------------------------------------------------------------------
    // FPGA Power-up Initialization
    //--------------------------------------------------------------------------
    initial begin
        cs_n_prev     = 1'b1;
        cfg_enable    = 8'd0;
        cfg_clk_div   = 8'd0;
        cfg_thresh    = 8'd0;
        cfg_ctrl      = 4'd0;
        cfg_tx_en     = 1'b0;
        cfg_rx_en     = 1'b0;
        cfg_lane_sel  = 2'd0;
        cfg_loopback  = 1'b0;
        cfg_gain_fine = 3'd0;
        cfg_gain      = 8'd0;
        cfg_mode      = 8'd0;
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
    //--------------------------------------------------------------------------
    spi_slave u_spi_slave (
        .sclk       (sclk),
        .cs_n       (cs_n),
        .mosi       (mosi),
        .miso       (miso),
        .rf_wr_en   (rf_wr_en),
        .rf_addr    (rf_addr),
        .rf_wdata   (rf_wdata),
        .rf_rdata   (rf_rdata)
    );

    //--------------------------------------------------------------------------
    // Register File
    //--------------------------------------------------------------------------
    regfile u_regfile (
        .i_sclk           (sclk),
        .i_sclk_rst_n     (sclk_rst_n),
        // SPI Slave Interface
        .i_wr_en          (rf_wr_en),
        .i_addr           (rf_addr),
        .i_wdata          (rf_wdata),
        .o_rdata          (rf_rdata),
        // Config Outputs (SCLK domain)
        .o_cfg_enable     (cfg_enable_raw),
        .o_cfg_clk_div    (cfg_clk_div_raw),
        .o_cfg_thresh     (cfg_thresh_raw),
        .o_cfg_ctrl       (cfg_ctrl_raw),
        .o_cfg_tx_en      (cfg_tx_en_raw),
        .o_cfg_rx_en      (cfg_rx_en_raw),
        .o_cfg_lane_sel   (cfg_lane_sel_raw),
        .o_cfg_loopback   (cfg_loopback_raw),
        .o_cfg_gain_fine  (cfg_gain_fine_raw),
        .o_cfg_gain       (cfg_gain_raw),
        .o_cfg_mode       (cfg_mode_raw),
        // Status Inputs (synchronized)
        .i_status_busy        (status_busy_sync),
        .i_status_code        (status_code_sync),
        .i_status_temp_warn   (status_temp_warn_sync),
        .i_status_flags       (status_flags_sync),
        .i_status_rx_err      (status_rx_err_sync),
        .i_status_tx_err      (status_tx_err_sync),
        .i_status_lock        (status_lock_sync),
        .i_status_fifo_empty  (status_fifo_empty_sync),
        .i_status_fifo_full   (status_fifo_full_sync),
        .i_status_error       (status_error_sync)
    );

    //--------------------------------------------------------------------------
    // Config CDC (SPI -> sysclk domain)
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
            cfg_enable    <= 8'd0;
            cfg_clk_div   <= 8'd0;
            cfg_thresh    <= 8'd0;
            cfg_ctrl      <= 4'd0;
            cfg_tx_en     <= 1'b0;
            cfg_rx_en     <= 1'b0;
            cfg_lane_sel  <= 2'd0;
            cfg_loopback  <= 1'b0;
            cfg_gain_fine <= 3'd0;
            cfg_gain      <= 8'd0;
            cfg_mode      <= 8'd0;
        end else if (cs_n_rising) begin
            cfg_enable    <= cfg_enable_raw;
            cfg_clk_div   <= cfg_clk_div_raw;
            cfg_thresh    <= cfg_thresh_raw;
            cfg_ctrl      <= cfg_ctrl_raw;
            cfg_tx_en     <= cfg_tx_en_raw;
            cfg_rx_en     <= cfg_rx_en_raw;
            cfg_lane_sel  <= cfg_lane_sel_raw;
            cfg_loopback  <= cfg_loopback_raw;
            cfg_gain_fine <= cfg_gain_fine_raw;
            cfg_gain      <= cfg_gain_raw;
            cfg_mode      <= cfg_mode_raw;
        end
    end

    //--------------------------------------------------------------------------
    // Status CDC (sysclk -> SCLK domain) — per-bit synchronizers
    //--------------------------------------------------------------------------
    cdc_bit #(.SYNC_STAGES(2), .RESET_VALUE(1'b0)) u_sync_busy (
        .clk       (sclk),
        .rst_n     (sclk_rst_n),
        .async_in  (status_busy),
        .sync_out  (status_busy_sync)
    );

    // status_code[3:0] — 4 per-bit synchronizers
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_sync_code
            cdc_bit #(.SYNC_STAGES(2), .RESET_VALUE(1'b0)) u_bit (
                .clk       (sclk),
                .rst_n     (sclk_rst_n),
                .async_in  (status_code[i]),
                .sync_out  (status_code_sync[i])
            );
        end
    endgenerate

    cdc_bit #(.SYNC_STAGES(2), .RESET_VALUE(1'b0)) u_sync_temp_warn (
        .clk       (sclk),
        .rst_n     (sclk_rst_n),
        .async_in  (status_temp_warn),
        .sync_out  (status_temp_warn_sync)
    );

    // status_flags[7:0] — 8 per-bit synchronizers
    generate
        for (i = 0; i < 8; i++) begin : gen_sync_flags
            cdc_bit #(.SYNC_STAGES(2), .RESET_VALUE(1'b0)) u_bit (
                .clk       (sclk),
                .rst_n     (sclk_rst_n),
                .async_in  (status_flags[i]),
                .sync_out  (status_flags_sync[i])
            );
        end
    endgenerate

    // status_rx_err[3:0] — 4 per-bit synchronizers
    generate
        for (i = 0; i < 4; i++) begin : gen_sync_rx_err
            cdc_bit #(.SYNC_STAGES(2), .RESET_VALUE(1'b0)) u_bit (
                .clk       (sclk),
                .rst_n     (sclk_rst_n),
                .async_in  (status_rx_err[i]),
                .sync_out  (status_rx_err_sync[i])
            );
        end
    endgenerate

    // status_tx_err[3:0] — 4 per-bit synchronizers
    generate
        for (i = 0; i < 4; i++) begin : gen_sync_tx_err
            cdc_bit #(.SYNC_STAGES(2), .RESET_VALUE(1'b0)) u_bit (
                .clk       (sclk),
                .rst_n     (sclk_rst_n),
                .async_in  (status_tx_err[i]),
                .sync_out  (status_tx_err_sync[i])
            );
        end
    endgenerate

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
