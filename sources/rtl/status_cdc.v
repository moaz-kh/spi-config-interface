//==============================================================================
// Status CDC (sysclk -> SCLK domain)
// 2FF synchronizer per bit into SCLK domain
// Continuous sync (always updating)
//==============================================================================

module status_cdc (
    // SCLK Domain
    input  wire sclk,
    input  wire sclk_rst_n,

    // Status Inputs (sysclk domain)
    input  wire status_lock_in,
    input  wire status_fifo_empty_in,
    input  wire status_fifo_full_in,
    input  wire status_error_in,

    // Status Outputs (SCLK domain, synchronized)
    output wire status_lock_out,
    output wire status_fifo_empty_out,
    output wire status_fifo_full_out,
    output wire status_error_out
);

    //--------------------------------------------------------------------------
    // 2FF Synchronizers for each status bit
    //--------------------------------------------------------------------------
    reg [1:0] lock_sync;
    reg [1:0] fifo_empty_sync;
    reg [1:0] fifo_full_sync;
    reg [1:0] error_sync;

    //--------------------------------------------------------------------------
    // FPGA Power-up Initialization
    //--------------------------------------------------------------------------
    initial begin
        lock_sync       = 2'b00;
        fifo_empty_sync = 2'b00;
        fifo_full_sync  = 2'b00;
        error_sync      = 2'b00;
    end

    //--------------------------------------------------------------------------
    // Continuous Synchronization
    //--------------------------------------------------------------------------
    always @(posedge sclk or negedge sclk_rst_n) begin
        if (!sclk_rst_n) begin
            lock_sync       <= 2'b00;
            fifo_empty_sync <= 2'b00;
            fifo_full_sync  <= 2'b00;
            error_sync      <= 2'b00;
        end else begin
            // 2FF synchronizers - continuous update
            lock_sync       <= {lock_sync[0], status_lock_in};
            fifo_empty_sync <= {fifo_empty_sync[0], status_fifo_empty_in};
            fifo_full_sync  <= {fifo_full_sync[0], status_fifo_full_in};
            error_sync      <= {error_sync[0], status_error_in};
        end
    end

    //--------------------------------------------------------------------------
    // Synchronized Outputs
    //--------------------------------------------------------------------------
    assign status_lock_out       = lock_sync[1];
    assign status_fifo_empty_out = fifo_empty_sync[1];
    assign status_fifo_full_out  = fifo_full_sync[1];
    assign status_error_out      = error_sync[1];

endmodule
