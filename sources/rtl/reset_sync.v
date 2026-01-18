//==============================================================================
// Reset Synchronizer
// Async assert, sync deassert for SCLK domain
// Required because SCLK may not be running at reset time
//==============================================================================

module reset_sync (
    input  wire sclk,
    input  wire sys_rst_n,
    output wire sclk_rst_n
);

    // 2-stage synchronizer for reset release
    reg [1:0] rst_sync;

    // Initialize for FPGA power-up
    initial begin
        rst_sync = 2'b00;
    end

    // Async assert (immediate when sys_rst_n falls)
    // Sync deassert (waits for 2 SCLK edges after sys_rst_n rises)
    always @(posedge sclk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            rst_sync <= 2'b00;
        end else begin
            rst_sync <= {rst_sync[0], 1'b1};
        end
    end

    assign sclk_rst_n = rst_sync[1];

endmodule
