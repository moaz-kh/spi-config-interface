// =============================================================================
// AUTO-GENERATED FILE — DO NOT EDIT MANUALLY
// Source:    sources/regmap/regfile.csv
// Generated: 2026-03-28 20:02:40 UTC
// Generator: scripts/gen_regfile.py
// =============================================================================
//
// Register File
// 8-bit data, 8-bit address
// 8'h00[7:0]: VERSION              (RO_CONST) Version register - fixed constant 0x01
// 8'h01[7:0]: CFG_ENABLE           (RW      ) Enable configuration register
// 8'h02[7:0]: CFG_CLK_DIV          (RW      ) Clock divider configuration register
// 8'h03[7:0]: CFG_THRESH           (RW      ) Threshold register with non-zero reset (case 1)
// 8'h04[7:0]: reserved             (RESERVED) Reserved
// 8'h05[7:4]: CFG_CTRL             (RW      ) Control bits
// 8'h05[3:3]: STATUS_BUSY          (RO      ) Busy flag
// 8'h05[2:0]: reserved             (RESERVED) Reserved
// 8'h06[7:0]: reserved             (RESERVED) Reserved
// 8'h07[7:7]: CFG_TX_EN            (RW      ) TX enable - single-bit MSB (cases 2 3)
// 8'h07[6:6]: CFG_RX_EN            (RW      ) RX enable - single-bit
// 8'h07[5:3]: reserved             (RESERVED) Reserved
// 8'h07[2:1]: CFG_LANE_SEL         (RW      ) Lane select - middle bits (case 3)
// 8'h07[0:0]: CFG_LOOPBACK         (RW      ) Loopback enable - single-bit LSB (case 3)
// 8'h08[7:4]: STATUS_CODE          (RO      ) 4-bit status code (case 5)
// 8'h08[3:0]: HW_REV               (RO_CONST) Hardware revision constant (case 6)
// 8'h09[7:5]: CFG_GAIN_FINE        (RW      ) Fine gain adjust (case 7 - three-way mix)
// 8'h09[4:4]: STATUS_TEMP_WARN     (RO      ) Temperature warning (case 7)
// 8'h09[3:2]: HW_VARIANT           (RO_CONST) Hardware variant ID (case 7)
// 8'h09[1:0]: reserved             (RESERVED) Reserved
// 8'h0A[7:0]: STATUS_FLAGS         (RO      ) Full-byte RO register (case 8)
// 8'h0B[7:4]: STATUS_RX_ERR        (RO      ) RX error code (case 9)
// 8'h0B[3:0]: STATUS_TX_ERR        (RO      ) TX error code (case 9)
// 8'h80[0:0]: STATUS_LOCK          (RO      ) PLL lock status - bit[0] only
// 8'h81[0:0]: STATUS_FIFO_EMPTY    (RO      ) FIFO empty status - bit[0] only
// 8'h82[0:0]: STATUS_FIFO_FULL     (RO      ) FIFO full status - bit[0] only
// 8'h83[0:0]: STATUS_ERROR         (RO      ) Error status - bit[0] only
// 8'h84[7:0]: CFG_GAIN             (RW      ) Gain configuration register
// 8'h85[7:0]: CFG_MODE             (RW      ) Mode configuration register


module regfile (
    input  logic       i_sclk,
    input  logic       i_sclk_rst_n,

    // SPI Slave Interface
    input  logic       i_wr_en,
    input  logic [7:0] i_addr,
    input  logic [7:0] i_wdata,
    output logic [7:0] o_rdata,

    // Config Outputs (RW fields)
    output logic [7:0] o_cfg_enable,  // 8'h01[7:0]: CFG_ENABLE
    output logic [7:0] o_cfg_clk_div,  // 8'h02[7:0]: CFG_CLK_DIV
    output logic [7:0] o_cfg_thresh,  // 8'h03[7:0]: CFG_THRESH
    output logic [3:0] o_cfg_ctrl,  // 8'h05[7:4]: CFG_CTRL
    output logic [0:0] o_cfg_tx_en,  // 8'h07[7:7]: CFG_TX_EN
    output logic [0:0] o_cfg_rx_en,  // 8'h07[6:6]: CFG_RX_EN
    output logic [1:0] o_cfg_lane_sel,  // 8'h07[2:1]: CFG_LANE_SEL
    output logic [0:0] o_cfg_loopback,  // 8'h07[0:0]: CFG_LOOPBACK
    output logic [2:0] o_cfg_gain_fine,  // 8'h09[7:5]: CFG_GAIN_FINE
    output logic [7:0] o_cfg_gain,  // 8'h84[7:0]: CFG_GAIN
    output logic [7:0] o_cfg_mode,  // 8'h85[7:0]: CFG_MODE

    // Status Inputs (RO fields)
    input  logic       i_status_busy,  // 8'h05[3:3]: STATUS_BUSY
    input  logic [3:0] i_status_code,  // 8'h08[7:4]: STATUS_CODE
    input  logic       i_status_temp_warn,  // 8'h09[4:4]: STATUS_TEMP_WARN
    input  logic [7:0] i_status_flags,  // 8'h0A[7:0]: STATUS_FLAGS
    input  logic [3:0] i_status_rx_err,  // 8'h0B[7:4]: STATUS_RX_ERR
    input  logic [3:0] i_status_tx_err,  // 8'h0B[3:0]: STATUS_TX_ERR
    input  logic       i_status_lock,  // 8'h80[0:0]: STATUS_LOCK
    input  logic       i_status_fifo_empty,  // 8'h81[0:0]: STATUS_FIFO_EMPTY
    input  logic       i_status_fifo_full,  // 8'h82[0:0]: STATUS_FIFO_FULL
    input  logic       i_status_error  // 8'h83[0:0]: STATUS_ERROR
);

    //////////////////////////////////////////////////////////////////////////
    // Parameters
    //////////////////////////////////////////////////////////////////////////
    localparam logic [7:0] VERSION      = 8'h01;  // Version register - fixed constant 0x01
    localparam logic [7:0] HW_REV       = 8'h03;  // Hardware revision constant (case 6)
    localparam logic [7:0] HW_VARIANT   = 8'h02;  // Hardware variant ID (case 7)
    // Reset Values
    localparam logic [7:0] RW_RST_01  = 8'h00;
    localparam logic [7:0] RW_RST_02  = 8'h00;
    localparam logic [7:0] RW_RST_03  = 8'h1A;
    localparam logic [7:0] RW_RST_05  = 8'h00;
    localparam logic [7:0] RW_RST_07  = 8'hC0;
    localparam logic [7:0] RW_RST_09  = 8'h00;
    localparam logic [7:0] RW_RST_84  = 8'h00;
    localparam logic [7:0] RW_RST_85  = 8'h00;
    // Write Masks
    localparam logic [7:0] WR_MASK_01 = 8'hFF;
    localparam logic [7:0] WR_MASK_02 = 8'hFF;
    localparam logic [7:0] WR_MASK_03 = 8'hFF;
    localparam logic [7:0] WR_MASK_05 = 8'hF0;
    localparam logic [7:0] WR_MASK_07 = 8'hC7;
    localparam logic [7:0] WR_MASK_09 = 8'hE0;
    localparam logic [7:0] WR_MASK_84 = 8'hFF;
    localparam logic [7:0] WR_MASK_85 = 8'hFF;

    //////////////////////////////////////////////////////////////////////////
    // RW Register Storage
    //////////////////////////////////////////////////////////////////////////
    logic [7:0] reg_01;  // CFG_ENABLE
    logic [7:0] reg_02;  // CFG_CLK_DIV
    logic [7:0] reg_03;  // CFG_THRESH
    logic [7:0] reg_05;  // CFG_CTRL
    logic [7:0] reg_07;  // CFG_TX_EN, CFG_RX_EN, CFG_LANE_SEL, CFG_LOOPBACK
    logic [7:0] reg_09;  // CFG_GAIN_FINE
    logic [7:0] reg_84;  // CFG_GAIN
    logic [7:0] reg_85;  // CFG_MODE

    //////////////////////////////////////////////////////////////////////////
    // FPGA Power-up Initialization
    //////////////////////////////////////////////////////////////////////////
    initial begin
        reg_01 = RW_RST_01;
        reg_02 = RW_RST_02;
        reg_03 = RW_RST_03;
        reg_05 = RW_RST_05;
        reg_07 = RW_RST_07;
        reg_09 = RW_RST_09;
        reg_84 = RW_RST_84;
        reg_85 = RW_RST_85;
        o_rdata  = 8'd0;
    end

    //////////////////////////////////////////////////////////////////////////
    // Write Logic — RW Registers Only (mask-based)
    // Writes to RO and unmapped addresses are silently ignored
    //////////////////////////////////////////////////////////////////////////
    always_ff @(posedge i_sclk or negedge i_sclk_rst_n) begin
        if (!i_sclk_rst_n) begin
            reg_01 <= RW_RST_01;
            reg_02 <= RW_RST_02;
            reg_03 <= RW_RST_03;
            reg_05 <= RW_RST_05;
            reg_07 <= RW_RST_07;
            reg_09 <= RW_RST_09;
            reg_84 <= RW_RST_84;
            reg_85 <= RW_RST_85;
        end else if (i_wr_en) begin
            case (i_addr)
                8'h01: reg_01 <= i_wdata & WR_MASK_01;
                8'h02: reg_02 <= i_wdata & WR_MASK_02;
                8'h03: reg_03 <= i_wdata & WR_MASK_03;
                8'h05: reg_05 <= i_wdata & WR_MASK_05;
                8'h07: reg_07 <= i_wdata & WR_MASK_07;
                8'h09: reg_09 <= i_wdata & WR_MASK_09;
                8'h84: reg_84 <= i_wdata & WR_MASK_84;
                8'h85: reg_85 <= i_wdata & WR_MASK_85;
                default: ; // RO and unmapped addresses ignored
            endcase
        end
    end

    //////////////////////////////////////////////////////////////////////////
    // Read Logic — Combinational (no latency)
    //////////////////////////////////////////////////////////////////////////
    always_comb begin
        case (i_addr)
            8'h00: o_rdata = VERSION;
            8'h01: o_rdata = reg_01;
            8'h02: o_rdata = reg_02;
            8'h03: o_rdata = reg_03;
            8'h04: o_rdata = 8'h00;
            8'h05: o_rdata = {reg_05[7:4], i_status_busy, 3'b0};
            8'h06: o_rdata = 8'h00;
            8'h07: o_rdata = {reg_07[7:7], reg_07[6:6], 3'b0, reg_07[2:1], reg_07[0:0]};
            8'h08: o_rdata = {i_status_code, 4'h3};
            8'h09: o_rdata = {reg_09[7:5], i_status_temp_warn, 2'h2, 2'b0};
            8'h0A: o_rdata = i_status_flags;
            8'h0B: o_rdata = {i_status_rx_err, i_status_tx_err};
            8'h80: o_rdata = {7'b0, i_status_lock};
            8'h81: o_rdata = {7'b0, i_status_fifo_empty};
            8'h82: o_rdata = {7'b0, i_status_fifo_full};
            8'h83: o_rdata = {7'b0, i_status_error};
            8'h84: o_rdata = reg_84;
            8'h85: o_rdata = reg_85;
            default: o_rdata = 8'h00;  // Unmapped addresses
        endcase
    end

    //////////////////////////////////////////////////////////////////////////
    // Config Output Assignments
    //////////////////////////////////////////////////////////////////////////
    assign o_cfg_enable           = reg_01;
    assign o_cfg_clk_div          = reg_02;
    assign o_cfg_thresh           = reg_03;
    assign o_cfg_ctrl             = reg_05[7:4];
    assign o_cfg_tx_en            = reg_07[7:7];
    assign o_cfg_rx_en            = reg_07[6:6];
    assign o_cfg_lane_sel         = reg_07[2:1];
    assign o_cfg_loopback         = reg_07[0:0];
    assign o_cfg_gain_fine        = reg_09[7:5];
    assign o_cfg_gain             = reg_84;
    assign o_cfg_mode             = reg_85;

endmodule
