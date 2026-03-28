//==============================================================================
// SPI Regfile Testbench
// Comprehensive verification of SPI slave + register file
//==============================================================================

`timescale 1ns / 1ps

module spi_regfile_tb;

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    localparam int SYS_CLK_PERIOD = 20;   // 50 MHz system clock
    localparam int SPI_CLK_PERIOD = 100;  // 10 MHz SPI clock

    //--------------------------------------------------------------------------
    // DUT Signals
    //--------------------------------------------------------------------------
    // SPI Interface
    logic        sclk;
    logic        cs_n;
    logic        mosi;
    logic        miso;

    // System Interface
    logic        sys_clk;
    logic        sys_rst_n;

    // Config Outputs
    logic [7:0]  cfg_enable;
    logic [7:0]  cfg_clk_div;
    logic [7:0]  cfg_thresh;
    logic [3:0]  cfg_ctrl;
    logic        cfg_tx_en;
    logic        cfg_rx_en;
    logic [1:0]  cfg_lane_sel;
    logic        cfg_loopback;
    logic [2:0]  cfg_gain_fine;
    logic [7:0]  cfg_gain;
    logic [7:0]  cfg_mode;

    // Status Inputs
    logic        status_busy;
    logic [3:0]  status_code;
    logic        status_temp_warn;
    logic [7:0]  status_flags;
    logic [3:0]  status_rx_err;
    logic [3:0]  status_tx_err;
    logic        status_lock;
    logic        status_fifo_empty;
    logic        status_fifo_full;
    logic        status_error;

    //--------------------------------------------------------------------------
    // Test Variables
    //--------------------------------------------------------------------------
    logic [7:0] read_data;
    int         test_pass;
    int         test_fail;
    int         test_num;

    //--------------------------------------------------------------------------
    // DUT Instantiation
    //--------------------------------------------------------------------------
    spi_regfile_top dut (
        .sclk       (sclk),
        .cs_n       (cs_n),
        .mosi       (mosi),
        .miso       (miso),
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        // Config Outputs
        .cfg_enable      (cfg_enable),
        .cfg_clk_div     (cfg_clk_div),
        .cfg_thresh      (cfg_thresh),
        .cfg_ctrl        (cfg_ctrl),
        .cfg_tx_en       (cfg_tx_en),
        .cfg_rx_en       (cfg_rx_en),
        .cfg_lane_sel    (cfg_lane_sel),
        .cfg_loopback    (cfg_loopback),
        .cfg_gain_fine   (cfg_gain_fine),
        .cfg_gain        (cfg_gain),
        .cfg_mode        (cfg_mode),
        // Status Inputs
        .status_busy       (status_busy),
        .status_code       (status_code),
        .status_temp_warn  (status_temp_warn),
        .status_flags      (status_flags),
        .status_rx_err     (status_rx_err),
        .status_tx_err     (status_tx_err),
        .status_lock       (status_lock),
        .status_fifo_empty (status_fifo_empty),
        .status_fifo_full  (status_fifo_full),
        .status_error      (status_error)
    );

    //--------------------------------------------------------------------------
    // Clock Generation
    //--------------------------------------------------------------------------
    initial sys_clk = 1'b0;
    always #(SYS_CLK_PERIOD/2) sys_clk = ~sys_clk;

    //--------------------------------------------------------------------------
    // VCD Dump
    //--------------------------------------------------------------------------
    initial begin
        $dumpfile("sim/waves/spi_regfile_tb.vcd");
        $dumpvars(0, spi_regfile_tb);
    end

    //--------------------------------------------------------------------------
    // SPI Transaction Tasks
    //--------------------------------------------------------------------------
    task automatic spi_send_byte(input logic [7:0] data);
        for (int i = 7; i >= 0; i--) begin
            mosi = data[i];
            #(SPI_CLK_PERIOD/2);
            sclk = 1'b1;
            #(SPI_CLK_PERIOD/2);
            sclk = 1'b0;
        end
    endtask

    task automatic spi_recv_byte(output logic [7:0] data);
        data = 8'd0;
        for (int i = 7; i >= 0; i--) begin
            mosi = 1'b0;
            #(SPI_CLK_PERIOD/2);
            sclk    = 1'b1;
            data[i] = miso;
            #(SPI_CLK_PERIOD/2);
            sclk = 1'b0;
        end
    endtask

    task automatic spi_write(input logic [7:0] addr, input logic [7:0] data);
        cs_n = 1'b0;
        #(SPI_CLK_PERIOD/2);
        spi_send_byte(8'h80);   // write command
        spi_send_byte(addr);
        spi_send_byte(data);
        #(SPI_CLK_PERIOD/2);
        cs_n = 1'b1;
        #(SPI_CLK_PERIOD);
    endtask

    task automatic spi_read(input logic [7:0] addr, output logic [7:0] data);
        cs_n = 1'b0;
        #(SPI_CLK_PERIOD/2);
        spi_send_byte(8'h00);   // read command
        spi_send_byte(addr);
        #1;
        spi_recv_byte(data);
        #(SPI_CLK_PERIOD/2);
        cs_n = 1'b1;
        #(SPI_CLK_PERIOD);
    endtask

    //--------------------------------------------------------------------------
    // Test Utilities
    //--------------------------------------------------------------------------
    task automatic check_result(
        input logic [7:0] expected,
        input logic [7:0] actual,
        input string      test_name
    );
        test_num = test_num + 1;
        if (expected === actual) begin
            $display("[PASS] Test %0d: %0s - Expected: 0x%02X, Got: 0x%02X",
                     test_num, test_name, expected, actual);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] Test %0d: %0s - Expected: 0x%02X, Got: 0x%02X",
                     test_num, test_name, expected, actual);
            test_fail = test_fail + 1;
        end
    endtask

    task automatic wait_cdc();
        repeat (10) @(posedge sys_clk);
    endtask

    //--------------------------------------------------------------------------
    // Main Test Sequence
    //--------------------------------------------------------------------------
    initial begin
        $display("========================================");
        $display("SPI Regfile Testbench");
        $display("========================================");

        // Initialize
        test_pass         = 0;
        test_fail         = 0;
        test_num          = 0;

        sclk              = 1'b0;
        cs_n              = 1'b1;
        mosi              = 1'b0;
        sys_rst_n         = 1'b0;
        status_busy       = 1'b0;
        status_code       = 4'h0;
        status_temp_warn  = 1'b0;
        status_flags      = 8'h00;
        status_rx_err     = 4'h0;
        status_tx_err     = 4'h0;
        status_lock       = 1'b0;
        status_fifo_empty = 1'b1;
        status_fifo_full  = 1'b0;
        status_error      = 1'b0;

        // Reset sequence
        #100;
        sys_rst_n = 1'b1;
        #100;

        // Provide SCLK edges to release SCLK domain reset
        repeat (4) begin
            #(SPI_CLK_PERIOD/2);
            sclk = 1'b1;
            #(SPI_CLK_PERIOD/2);
            sclk = 1'b0;
        end
        #100;

        //----------------------------------------------------------------------
        $display("\n--- Test Group 1: Version Register ---");
        //----------------------------------------------------------------------

        spi_read(8'h00, read_data);
        check_result(8'h01, read_data, "Read VERSION register");

        spi_write(8'h00, 8'hFF);
        spi_read(8'h00, read_data);
        check_result(8'h01, read_data, "VERSION unchanged after write");

        //----------------------------------------------------------------------
        $display("\n--- Test Group 2: RW Config Registers ---");
        //----------------------------------------------------------------------

        spi_write(8'h01, 8'hA5);
        spi_read(8'h01, read_data);
        check_result(8'hA5, read_data, "Write/Read CFG_ENABLE");

        spi_write(8'h02, 8'h3C);
        spi_read(8'h02, read_data);
        check_result(8'h3C, read_data, "Write/Read CFG_CLK_DIV");

        spi_write(8'h84, 8'h0F);
        spi_read(8'h84, read_data);
        check_result(8'h0F, read_data, "Write/Read CFG_GAIN");

        spi_write(8'h85, 8'h03);
        spi_read(8'h85, read_data);
        check_result(8'h03, read_data, "Write/Read CFG_MODE");

        //----------------------------------------------------------------------
        $display("\n--- Test Group 3: CDC Config Transfer ---");
        //----------------------------------------------------------------------

        wait_cdc();
        check_result(8'hA5, cfg_enable,  "CDC cfg_enable");
        check_result(8'h3C, cfg_clk_div, "CDC cfg_clk_div");
        check_result(8'h0F, cfg_gain,    "CDC cfg_gain");
        check_result(8'h03, cfg_mode,    "CDC cfg_mode");

        //----------------------------------------------------------------------
        $display("\n--- Test Group 4: RO Status Registers ---");
        //----------------------------------------------------------------------

        status_lock       = 1'b1;
        status_fifo_empty = 1'b0;
        status_fifo_full  = 1'b1;
        status_error      = 1'b1;
        #500;

        spi_read(8'h80, read_data);
        check_result(8'h01, read_data, "Read STATUS_LOCK");

        spi_read(8'h81, read_data);
        check_result(8'h00, read_data, "Read STATUS_FIFO_EMPTY");

        spi_read(8'h82, read_data);
        check_result(8'h01, read_data, "Read STATUS_FIFO_FULL");

        spi_read(8'h83, read_data);
        check_result(8'h01, read_data, "Read STATUS_ERROR");

        //----------------------------------------------------------------------
        $display("\n--- Test Group 5: Write to RO (Should Ignore) ---");
        //----------------------------------------------------------------------

        spi_write(8'h80, 8'hFF);
        spi_read(8'h80, read_data);
        check_result(8'h01, read_data, "STATUS_LOCK unchanged after write");

        //----------------------------------------------------------------------
        $display("\n--- Test Group 6: Unmapped Addresses ---");
        //----------------------------------------------------------------------

        spi_read(8'h7F, read_data);
        check_result(8'h00, read_data, "Read unmapped addr 0x7F");

        spi_read(8'hFF, read_data);
        check_result(8'h00, read_data, "Read unmapped addr 0xFF");

        //----------------------------------------------------------------------
        $display("\n--- Test Group 7: Multiple Writes ---");
        //----------------------------------------------------------------------

        spi_write(8'h01, 8'h12);
        spi_read(8'h01, read_data);
        check_result(8'h12, read_data, "Overwrite CFG_ENABLE");

        spi_read(8'h02, read_data);
        check_result(8'h3C, read_data, "CFG_CLK_DIV still 0x3C");

        //----------------------------------------------------------------------
        $display("\n--- Test Group 8: Status Change ---");
        //----------------------------------------------------------------------

        status_lock  = 1'b0;
        status_error = 1'b0;
        #500;

        spi_read(8'h80, read_data);
        check_result(8'h00, read_data, "STATUS_LOCK now 0");

        spi_read(8'h83, read_data);
        check_result(8'h00, read_data, "STATUS_ERROR now 0");

        //----------------------------------------------------------------------
        $display("\n--- Test Group 9: Reset Behavior ---");
        //----------------------------------------------------------------------

        sys_rst_n = 1'b0;
        #100;
        sys_rst_n = 1'b1;
        #100;

        spi_read(8'h01, read_data);
        check_result(8'h00, read_data, "CFG_ENABLE reset to 0");

        spi_read(8'h00, read_data);
        check_result(8'h01, read_data, "VERSION correct after reset");

        wait_cdc();
        check_result(8'h00, cfg_enable, "CDC cfg_enable reset");

        //----------------------------------------------------------------------
        $display("\n--- Test Group 10: Non-zero Reset (0x03 CFG_THRESH) ---");
        //----------------------------------------------------------------------

        // After reset, reg_03 = RW_RST_03 = 0x1A
        spi_read(8'h03, read_data);
        check_result(8'h1A, read_data, "CFG_THRESH reset to 0x1A");

        spi_write(8'h03, 8'h55);
        spi_read(8'h03, read_data);
        check_result(8'h55, read_data, "Write/Read CFG_THRESH");

        // Apply reset, check it goes back to 0x1A
        sys_rst_n = 1'b0;
        #100;
        sys_rst_n = 1'b1;
        #100;
        spi_read(8'h03, read_data);
        check_result(8'h1A, read_data, "CFG_THRESH returns to 0x1A after reset");

        //----------------------------------------------------------------------
        $display("\n--- Test Group 11: Multi-field RW with gaps (0x07) ---");
        //----------------------------------------------------------------------

        // WR_MASK_07 = 0xC7 (bits 7,6,2,1,0), RW_RST_07 = 0xC0 (TX_EN=1 RX_EN=1)
        // After reset, reg_07 = 0xC0
        spi_read(8'h07, read_data);
        check_result(8'hC0, read_data, "0x07 reset value = 0xC0");

        // Write 0xFF — mask strips gap bits[5:3], result = 0xC7
        spi_write(8'h07, 8'hFF);
        spi_read(8'h07, read_data);
        check_result(8'hC7, read_data, "0x07 write 0xFF masked to 0xC7");

        // Write 0x00 — all RW bits cleared
        spi_write(8'h07, 8'h00);
        spi_read(8'h07, read_data);
        check_result(8'h00, read_data, "0x07 write 0x00");

        // Write specific field values: TX_EN=1, RX_EN=0, LANE_SEL=2'b10, LOOPBACK=1
        // = bit7=1, bit6=0, bit2=1, bit1=0, bit0=1 → 0x85 & mask = 0x85
        spi_write(8'h07, 8'h85);
        spi_read(8'h07, read_data);
        check_result(8'h85, read_data, "0x07 write 0x85 (TX_EN=1 LANE_SEL=10 LOOPBACK=1)");

        wait_cdc();
        check_result(8'h01, {7'b0, cfg_tx_en},  "CDC cfg_tx_en=1");
        check_result(8'h00, {7'b0, cfg_rx_en},  "CDC cfg_rx_en=0");
        check_result(8'h02, {6'b0, cfg_lane_sel}, "CDC cfg_lane_sel=2'b10");
        check_result(8'h01, {7'b0, cfg_loopback}, "CDC cfg_loopback=1");

        //----------------------------------------------------------------------
        $display("\n--- Test Group 12: RO + partial RO_CONST (0x08) ---");
        //----------------------------------------------------------------------

        // 0x08: STATUS_CODE[7:4]=RO, HW_REV[3:0]=RO_CONST=4'h3
        // Read with status_code=0, expect 0x03
        status_code = 4'h0;
        #500;
        spi_read(8'h08, read_data);
        check_result(8'h03, read_data, "0x08 HW_REV constant = 0x3");

        // Set status_code = 0xA, read → {0xA, 0x3} = 0xA3
        status_code = 4'hA;
        #500;
        spi_read(8'h08, read_data);
        check_result(8'hA3, read_data, "0x08 status_code=0xA, HW_REV=3 → 0xA3");

        // Write to 0x08 (no RW fields, should be ignored)
        spi_write(8'h08, 8'hFF);
        spi_read(8'h08, read_data);
        check_result(8'hA3, read_data, "0x08 unchanged after write");

        //----------------------------------------------------------------------
        $display("\n--- Test Group 13: Three-way mix RW+RO+RO_CONST (0x09) ---");
        //----------------------------------------------------------------------

        // 0x09: GAIN_FINE[7:5]=RW, TEMP_WARN[4]=RO, HW_VARIANT[3:2]=RO_CONST=2'b10, rsv[1:0]=0
        // WR_MASK_09 = 0xE0

        status_temp_warn = 1'b0;
        #500;

        // Write 0x00: reg_09 = 0x00 & 0xE0 = 0x00
        spi_write(8'h09, 8'h00);
        spi_read(8'h09, read_data);
        // read = {000, 0, 10, 00} = 0x08
        check_result(8'h08, read_data, "0x09 reg=0 temp=0 → 0x08 (HW_VARIANT constant)");

        // Write 0xFF: reg_09 = 0xFF & 0xE0 = 0xE0, temp_warn=0
        spi_write(8'h09, 8'hFF);
        spi_read(8'h09, read_data);
        // read = {111, 0, 10, 00} = 0xE8
        check_result(8'hE8, read_data, "0x09 reg=0xE0 temp=0 → 0xE8");

        // Set temp_warn=1: read = {111, 1, 10, 00} = 0xF8
        status_temp_warn = 1'b1;
        #500;
        spi_read(8'h09, read_data);
        check_result(8'hF8, read_data, "0x09 reg=0xE0 temp=1 → 0xF8");

        // Verify GAIN_FINE CDC
        wait_cdc();
        check_result(8'h07, {5'b0, cfg_gain_fine}, "CDC cfg_gain_fine=3'b111");

        //----------------------------------------------------------------------
        $display("\n--- Test Group 14: Full-byte RO (0x0A STATUS_FLAGS) ---");
        //----------------------------------------------------------------------

        status_flags = 8'hAB;
        #500;
        spi_read(8'h0A, read_data);
        check_result(8'hAB, read_data, "Read STATUS_FLAGS=0xAB");

        // Write ignored
        spi_write(8'h0A, 8'hFF);
        spi_read(8'h0A, read_data);
        check_result(8'hAB, read_data, "STATUS_FLAGS unchanged after write");

        status_flags = 8'h00;
        #500;
        spi_read(8'h0A, read_data);
        check_result(8'h00, read_data, "STATUS_FLAGS cleared to 0x00");

        //----------------------------------------------------------------------
        $display("\n--- Test Group 15: Multi-bit RO at same addr (0x0B) ---");
        //----------------------------------------------------------------------

        // 0x0B: STATUS_RX_ERR[7:4] + STATUS_TX_ERR[3:0]
        status_rx_err = 4'hC;
        status_tx_err = 4'h5;
        #500;
        spi_read(8'h0B, read_data);
        check_result(8'hC5, read_data, "0x0B rx_err=0xC tx_err=0x5 → 0xC5");

        status_rx_err = 4'h0;
        status_tx_err = 4'hF;
        #500;
        spi_read(8'h0B, read_data);
        check_result(8'h0F, read_data, "0x0B rx_err=0 tx_err=0xF → 0x0F");

        // Write ignored
        spi_write(8'h0B, 8'hFF);
        spi_read(8'h0B, read_data);
        check_result(8'h0F, read_data, "0x0B unchanged after write");

        //----------------------------------------------------------------------
        // Test Summary
        //----------------------------------------------------------------------
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", test_pass + test_fail);
        $display("Passed:      %0d", test_pass);
        $display("Failed:      %0d", test_fail);
        $display("========================================");

        if (test_fail == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");

        $display("========================================\n");

        #100;
        $finish;
    end

    //--------------------------------------------------------------------------
    // Timeout Watchdog
    //--------------------------------------------------------------------------
    initial begin
        #200000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
