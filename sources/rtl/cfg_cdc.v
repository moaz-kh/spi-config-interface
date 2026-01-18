//==============================================================================
// Config CDC (SPI -> sysclk domain)
// 2FF synchronize cs_n into sysclk domain
// On synced cs_n rising edge: latch config outputs
// Config is stable because SPI transaction ended when cs_n goes high
//==============================================================================

module cfg_cdc (
    // System Clock Domain
    input  wire       sys_clk,
    input  wire       sys_rst_n,

    // CS_n from SPI (SCLK domain, but directly sampled)
    input  wire       cs_n,

    // Config Inputs from Register File (SCLK domain, but stable after cs_n rises)
    input  wire [7:0] cfg_enable_in,
    input  wire [7:0] cfg_clk_div_in,
    input  wire [7:0] cfg_gain_in,
    input  wire [7:0] cfg_mode_in,

    // Config Outputs (sysclk domain, latched)
    output reg  [7:0] cfg_enable_out,
    output reg  [7:0] cfg_clk_div_out,
    output reg  [7:0] cfg_gain_out,
    output reg  [7:0] cfg_mode_out
);

    //--------------------------------------------------------------------------
    // 2FF Synchronizer for cs_n
    //--------------------------------------------------------------------------
    reg [1:0] cs_n_sync;
    reg       cs_n_prev;

    wire cs_n_synced;
    wire cs_n_rising;

    assign cs_n_synced = cs_n_sync[1];
    assign cs_n_rising = cs_n_synced && !cs_n_prev;

    //--------------------------------------------------------------------------
    // FPGA Power-up Initialization
    //--------------------------------------------------------------------------
    initial begin
        cs_n_sync      = 2'b11;  // Assume idle (cs_n high)
        cs_n_prev      = 1'b1;
        cfg_enable_out = 8'd0;
        cfg_clk_div_out = 8'd0;
        cfg_gain_out   = 8'd0;
        cfg_mode_out   = 8'd0;
    end

    //--------------------------------------------------------------------------
    // CS_n Synchronization and Edge Detection
    //--------------------------------------------------------------------------
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            cs_n_sync <= 2'b11;
            cs_n_prev <= 1'b1;
        end else begin
            // 2FF synchronizer
            cs_n_sync <= {cs_n_sync[0], cs_n};
            // Edge detection register
            cs_n_prev <= cs_n_synced;
        end
    end

    //--------------------------------------------------------------------------
    // Config Latch on cs_n Rising Edge
    // When cs_n goes high, SPI transaction has ended and config is stable
    //--------------------------------------------------------------------------
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            cfg_enable_out  <= 8'd0;
            cfg_clk_div_out <= 8'd0;
            cfg_gain_out    <= 8'd0;
            cfg_mode_out    <= 8'd0;
        end else if (cs_n_rising) begin
            // Latch config values - they are stable now
            cfg_enable_out  <= cfg_enable_in;
            cfg_clk_div_out <= cfg_clk_div_in;
            cfg_gain_out    <= cfg_gain_in;
            cfg_mode_out    <= cfg_mode_in;
        end
    end

endmodule
