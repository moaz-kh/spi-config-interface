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
    logic [7:0]  cfg_gain;
    logic [7:0]  cfg_mode;

    // Status Inputs
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
        // SPI Interface
        .sclk       (sclk),
        .cs_n       (cs_n),
        .mosi       (mosi),
        .miso       (miso),
        // System Interface
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        // Config Outputs
        .cfg_enable      (cfg_enable),
        .cfg_clk_div     (cfg_clk_div),
        .cfg_gain        (cfg_gain),
        .cfg_mode        (cfg_mode),
        // Status Inputs
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

    // SPI clock is generated in tasks (not free-running)

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

    // Send a single byte over SPI
    task automatic spi_send_byte(input logic [7:0] data);
        for (int i = 7; i >= 0; i--) begin
            mosi = data[i];
            #(SPI_CLK_PERIOD/2);
            sclk = 1'b1;  // Rising edge - data sampled
            #(SPI_CLK_PERIOD/2);
            sclk = 1'b0;  // Falling edge - data shifted
        end
    endtask

    // Receive a single byte over SPI
    task automatic spi_recv_byte(output logic [7:0] data);
        data = 8'd0;
        for (int i = 7; i >= 0; i--) begin
            mosi = 1'b0;  // Don't care for read
            #(SPI_CLK_PERIOD/2);
            sclk   = 1'b1;    // Rising edge
            data[i] = miso;   // Capture MISO
            #(SPI_CLK_PERIOD/2);
            sclk = 1'b0;  // Falling edge
        end
    endtask

    // SPI Write Transaction
    task automatic spi_write(input logic [7:0] addr, input logic [7:0] data);
        cs_n = 1'b0;
        #(SPI_CLK_PERIOD/2);

        // Command byte (bit[7]=1 for write)
        spi_send_byte(8'h80);

        // Address byte
        spi_send_byte(addr);

        // Data byte
        spi_send_byte(data);

        #(SPI_CLK_PERIOD/2);
        cs_n = 1'b1;
        #(SPI_CLK_PERIOD);
    endtask

    // SPI Read Transaction
    task automatic spi_read(input logic [7:0] addr, output logic [7:0] data);
        cs_n = 1'b0;
        #(SPI_CLK_PERIOD/2);

        // Command byte (bit[7]=0 for read)
        spi_send_byte(8'h00);

        // Address byte
        spi_send_byte(addr);

        // Small delay to let address propagate to regfile
        #1;

        // Data byte (receive)
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
        // Wait for CDC to propagate (several sys_clk cycles)
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
        test_pass = 0;
        test_fail = 0;
        test_num  = 0;

        sclk              = 1'b0;
        cs_n              = 1'b1;
        mosi              = 1'b0;
        sys_rst_n         = 1'b0;
        status_lock       = 1'b0;
        status_fifo_empty = 1'b1;
        status_fifo_full  = 1'b0;
        status_error      = 1'b0;

        // Reset sequence
        #100;
        sys_rst_n = 1'b1;
        #100;

        // Provide SCLK edges while CS_n high to release SCLK domain reset
        // Reset sync requires 2 SCLK edges after sys_rst_n deasserts
        repeat (4) begin
            #(SPI_CLK_PERIOD/2);
            sclk = 1'b1;
            #(SPI_CLK_PERIOD/2);
            sclk = 1'b0;
        end
        #100;

        $display("\n--- Test Group 1: Version Register ---");

        // Test 1: Read version register (should be 0x01)
        spi_read(8'h00, read_data);
        check_result(8'h01, read_data, "Read VERSION register");

        // Test 2: Write to version register (should be ignored)
        spi_write(8'h00, 8'hFF);
        spi_read(8'h00, read_data);
        check_result(8'h01, read_data, "VERSION unchanged after write");

        $display("\n--- Test Group 2: RW Config Registers ---");

        // Test 3: Write and read CFG_ENABLE
        spi_write(8'h01, 8'hA5);
        spi_read(8'h01, read_data);
        check_result(8'hA5, read_data, "Write/Read CFG_ENABLE");

        // Test 4: Write and read CFG_CLK_DIV
        spi_write(8'h02, 8'h3C);
        spi_read(8'h02, read_data);
        check_result(8'h3C, read_data, "Write/Read CFG_CLK_DIV");

        // Test 5: Write and read CFG_GAIN
        spi_write(8'h03, 8'h0F);
        spi_read(8'h03, read_data);
        check_result(8'h0F, read_data, "Write/Read CFG_GAIN");

        // Test 6: Write and read CFG_MODE
        spi_write(8'h04, 8'h03);
        spi_read(8'h04, read_data);
        check_result(8'h03, read_data, "Write/Read CFG_MODE");

        $display("\n--- Test Group 3: CDC Config Transfer ---");

        // Wait for CDC to complete
        wait_cdc();

        // Test 7-10: Check CDC transferred config values
        check_result(8'hA5, cfg_enable,  "CDC cfg_enable");
        check_result(8'h3C, cfg_clk_div, "CDC cfg_clk_div");
        check_result(8'h0F, cfg_gain,    "CDC cfg_gain");
        check_result(8'h03, cfg_mode,    "CDC cfg_mode");

        $display("\n--- Test Group 4: RO Status Registers ---");

        // Set status signals
        status_lock       = 1'b1;
        status_fifo_empty = 1'b0;
        status_fifo_full  = 1'b1;
        status_error      = 1'b1;

        // Wait for status CDC
        #500;

        // Test 11: Read STATUS_LOCK
        spi_read(8'h80, read_data);
        check_result(8'h01, read_data, "Read STATUS_LOCK");

        // Test 12: Read STATUS_FIFO_EMPTY
        spi_read(8'h81, read_data);
        check_result(8'h00, read_data, "Read STATUS_FIFO_EMPTY");

        // Test 13: Read STATUS_FIFO_FULL
        spi_read(8'h82, read_data);
        check_result(8'h01, read_data, "Read STATUS_FIFO_FULL");

        // Test 14: Read STATUS_ERROR
        spi_read(8'h83, read_data);
        check_result(8'h01, read_data, "Read STATUS_ERROR");

        $display("\n--- Test Group 5: Write to RO (Should Ignore) ---");

        // Test 15: Write to STATUS_LOCK (should be ignored)
        spi_write(8'h80, 8'hFF);
        spi_read(8'h80, read_data);
        check_result(8'h01, read_data, "STATUS_LOCK unchanged after write");

        $display("\n--- Test Group 6: Unmapped Addresses ---");

        // Test 16: Read unmapped RW address
        spi_read(8'h7F, read_data);
        check_result(8'h00, read_data, "Read unmapped RW addr 0x7F");

        // Test 17: Read unmapped RO address
        spi_read(8'hFF, read_data);
        check_result(8'h00, read_data, "Read unmapped RO addr 0xFF");

        $display("\n--- Test Group 7: Multiple Writes ---");

        // Test 18: Overwrite CFG_ENABLE
        spi_write(8'h01, 8'h12);
        spi_read(8'h01, read_data);
        check_result(8'h12, read_data, "Overwrite CFG_ENABLE");

        // Test 19: Verify other registers unchanged
        spi_read(8'h02, read_data);
        check_result(8'h3C, read_data, "CFG_CLK_DIV still 0x3C");

        $display("\n--- Test Group 8: Status Change ---");

        // Change status signals
        status_lock  = 1'b0;
        status_error = 1'b0;

        // Wait for CDC
        #500;

        // Test 20: Read updated STATUS_LOCK
        spi_read(8'h80, read_data);
        check_result(8'h00, read_data, "STATUS_LOCK now 0");

        // Test 21: Read updated STATUS_ERROR
        spi_read(8'h83, read_data);
        check_result(8'h00, read_data, "STATUS_ERROR now 0");

        $display("\n--- Test Group 9: Reset Behavior ---");

        // Apply reset
        sys_rst_n = 1'b0;
        #100;
        sys_rst_n = 1'b1;
        #100;

        // Test 22: Verify CFG_ENABLE reset to 0
        spi_read(8'h01, read_data);
        check_result(8'h00, read_data, "CFG_ENABLE reset to 0");

        // Test 23: VERSION still correct after reset
        spi_read(8'h00, read_data);
        check_result(8'h01, read_data, "VERSION correct after reset");

        // Wait for CDC
        wait_cdc();

        // Test 24: CDC outputs reset
        check_result(8'h00, cfg_enable, "CDC cfg_enable reset");

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
        #100000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
