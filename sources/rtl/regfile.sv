//==============================================================================
// Register File
// 8-bit data, 8-bit address
// 0x00: Version register (RO, fixed 0x01)
// 0x01-0x7F: RW registers (config outputs)
// 0x80-0xFF: RO registers (status inputs, unmapped returns 0x00)
//==============================================================================

module regfile (
    input  logic       sclk,
    input  logic       sclk_rst_n,

    // SPI Slave Interface
    input  logic       wr_en,
    input  logic [7:0] addr,
    input  logic [7:0] wdata,
    output logic [7:0] rdata,

    // Config Outputs (directly from RW registers)
    output logic [7:0] cfg_enable,      // addr 0x01
    output logic [7:0] cfg_clk_div,     // addr 0x02
    output logic [7:0] cfg_gain,        // addr 0x03
    output logic [7:0] cfg_mode,        // addr 0x04

    // Status Inputs (synchronized from sysclk domain)
    input  logic       status_lock,        // addr 0x80, bit[0]
    input  logic       status_fifo_empty,  // addr 0x81, bit[0]
    input  logic       status_fifo_full,   // addr 0x82, bit[0]
    input  logic       status_error        // addr 0x83, bit[0]
);

    //--------------------------------------------------------------------------
    // Parameters - Reset Values (USER: Modify as needed)
    //--------------------------------------------------------------------------
    localparam logic [7:0] VERSION   = 8'h01;  // Version ID
    localparam logic [7:0] RW_RST_01 = 8'h00;  // CFG_ENABLE reset
    localparam logic [7:0] RW_RST_02 = 8'h00;  // CFG_CLK_DIV reset
    localparam logic [7:0] RW_RST_03 = 8'h00;  // CFG_GAIN reset
    localparam logic [7:0] RW_RST_04 = 8'h00;  // CFG_MODE reset

    //--------------------------------------------------------------------------
    // RW Register Storage
    //--------------------------------------------------------------------------
    logic [7:0] reg_01;  // CFG_ENABLE
    logic [7:0] reg_02;  // CFG_CLK_DIV
    logic [7:0] reg_03;  // CFG_GAIN
    logic [7:0] reg_04;  // CFG_MODE

    //--------------------------------------------------------------------------
    // FPGA Power-up Initialization
    //--------------------------------------------------------------------------
    initial begin
        reg_01 = RW_RST_01;
        reg_02 = RW_RST_02;
        reg_03 = RW_RST_03;
        reg_04 = RW_RST_04;
        rdata  = 8'd0;
    end

    //--------------------------------------------------------------------------
    // Write Logic - RW Registers Only (0x01-0x7F)
    // Writes to RO addresses (0x00, 0x80-0xFF) are ignored silently
    //--------------------------------------------------------------------------
    always_ff @(posedge sclk or negedge sclk_rst_n) begin
        if (!sclk_rst_n) begin
            reg_01 <= RW_RST_01;
            reg_02 <= RW_RST_02;
            reg_03 <= RW_RST_03;
            reg_04 <= RW_RST_04;
        end else if (wr_en) begin
            // Only write to RW range (0x01-0x7F)
            // addr[7] = 0 and addr != 0x00
            if (!addr[7] && (addr != 8'h00)) begin
                case (addr)
                    8'h01: reg_01 <= wdata;
                    8'h02: reg_02 <= wdata;
                    8'h03: reg_03 <= wdata;
                    8'h04: reg_04 <= wdata;
                    default: ; // Unmapped RW addresses ignored
                endcase
            end
            // Writes to 0x00 or 0x80-0xFF are silently ignored
        end
    end

    //--------------------------------------------------------------------------
    // Read Logic - Combinational (no latency)
    //--------------------------------------------------------------------------
    always_comb begin
        case (addr)
            // Version register (RO exception at 0x00)
            8'h00: rdata = VERSION;

            // RW Registers (Config)
            8'h01: rdata = reg_01;
            8'h02: rdata = reg_02;
            8'h03: rdata = reg_03;
            8'h04: rdata = reg_04;

            // RO Registers (Status) - 0x80-0xFF
            8'h80: rdata = {7'b0, status_lock};
            8'h81: rdata = {7'b0, status_fifo_empty};
            8'h82: rdata = {7'b0, status_fifo_full};
            8'h83: rdata = {7'b0, status_error};

            default: rdata = 8'h00;  // Unmapped RW and RO addresses
        endcase
    end

    //--------------------------------------------------------------------------
    // Config Output Assignments
    //--------------------------------------------------------------------------
    assign cfg_enable  = reg_01;
    assign cfg_clk_div = reg_02;
    assign cfg_gain    = reg_03;
    assign cfg_mode    = reg_04;

endmodule
