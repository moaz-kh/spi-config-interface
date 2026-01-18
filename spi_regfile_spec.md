# SPI Slave + Register File Specification

## Overview
SPI slave interface with 8-bit register file for post-silicon configuration and debug.

---

## SPI Interface

| Parameter | Value |
|-----------|-------|
| Mode | 0 (CPOL=0, CPHA=0) |
| Signals | `sclk`, `cs_n`, `mosi`, `miso` |
| MISO behavior | Directly driven (tri-state handled at pad level) |

### Transaction Format (3 bytes)

| Byte | Content |
|------|---------|
| 0 | Command: 0x00 = read, 0x80 = write |
| 1 | Address [7:0] |
| 2 | Write: data to write / Read: MISO outputs read data |

### Multi-byte Transfers
- Address auto-increments after each data byte
- Supports continuous read/write without CS_n toggle
- Multi-byte reads: address increments each 8 SCLK cycles
- Multi-byte writes: address increments after each write

---

## Register File

| Parameter | Value |
|-----------|-------|
| Data width | 8-bit |
| Address width | 8-bit |
| RW range | 0x01–0x7F |
| RO range | 0x80–0xFF |
| Exception | 0x00 = Version register (RO, fixed value = 8'h01) |

### Register Behavior

| Address | Type | Behavior |
|---------|------|----------|
| 0x00 | RO (exception) | Always returns 0x01 (version), immutable by sys or SPI |
| 0x01–0x7F | RW | Mapped ones drive config outputs, unmapped ignored |
| 0x80–0xFF | RO | Mapped ones return status input, unmapped return 0x00 |

### Write to RO Address
Ignored silently. No error, no action.

### Reset Values
Parameterized per register. User defines reset value for each RW register:
```verilog
// USER: Modify reset values as needed
localparam [7:0] RW_RST_01 = 8'h00;  // CFG_ENABLE
localparam [7:0] RW_RST_02 = 8'h00;  // CFG_CLK_DIV
localparam [7:0] RW_RST_03 = 8'h00;  // CFG_GAIN
localparam [7:0] RW_RST_04 = 8'h00;  // CFG_MODE
```

---

## Clock Domains & CDC

| Block | Domain |
|-------|--------|
| SPI slave | SCLK |
| Register file | SCLK |
| Config consumers | sysclk |
| Status sources | sysclk |

### SPI Slave Reset
- **Method:** CS_n as async reset
- **Pattern:** `always @(posedge sclk or posedge cs_n)`
- **Reason:** FPGA-friendly (no async set+reset conflict), CS_n naturally resets SPI state
- **Behavior:** When CS_n goes high, SPI FSM resets to idle state

### Register File Reset
- **Method:** Synchronized reset from sys_rst_n
- **Pattern:** `always @(posedge sclk or negedge sclk_rst_n)`
- **Uses:** reset_sync module for async assert, sync deassert

### Reset Synchronizer (reset_sync)
- **Method:** Async assert, sync deassert
- **Reason:** SCLK may not be running at reset time
- **Implementation:**
```verilog
always @(posedge sclk or negedge sys_rst_n)
  if (!sys_rst_n)
    rst_sync <= 2'b00;
  else
    rst_sync <= {rst_sync[0], 1'b1};

assign sclk_rst_n = rst_sync[1];
```
- **Note:** Requires SCLK edges after sys_rst_n deassert to release sclk_rst_n

### Config CDC (SPI → sysclk)
- 2FF synchronize `cs_n` into sysclk domain
- On synced `cs_n` rising edge: latch config outputs
- Config is stable because SPI transaction ended when `cs_n` goes high

### Status CDC (sysclk → SPI)
- All status signals are single-bit
- 2FF synchronizer per bit into SCLK domain
- Continuous sync (always updating)

---

## SPI Slave FSM

The SPI slave uses a 5-state FSM for transaction handling:

| State | Description |
|-------|-------------|
| RX_CMD | Receive command byte (0x00=read, 0x80=write) |
| RX_RD_ADDR | Receive address byte for read operation |
| RX_RD_DATA | Output read data on MISO, auto-increment address |
| RX_WR_ADDR | Receive address byte for write operation |
| RX_WR_DATA | Receive write data, assert rf_wr_en, auto-increment address |

### FSM Diagram
```
         cs_n=0
            │
            v
       ┌─────────┐
       │ RX_CMD  │<─────────────────────┐
       └────┬────┘                      │
            │ byte_complete             │
   ┌────────┴────────┐                  │
   │                 │                  │
   v (cmd=0x00)      v (cmd=0x80)       │ invalid cmd
┌──────────┐    ┌──────────┐            │
│RX_RD_ADDR│    │RX_WR_ADDR│            │
└────┬─────┘    └────┬─────┘            │
     │               │                  │
     v               v                  │
┌──────────┐    ┌──────────┐            │
│RX_RD_DATA│    │RX_WR_DATA│            │
└──────────┘    └──────────┘            │
     │               │                  │
     └───────────────┴──────────────────┘
                     cs_n=1 (async reset)
```

---

## Module Hierarchy

```
spi_regfile_top
├── reset_sync             (sys_rst_n → sclk_rst_n)
│   └── 2-stage sync for async assert, sync deassert
├── spi_slave              (SCLK domain, reset by cs_n)
│   ├── FSM: RX_CMD → RX_RD_ADDR/RX_WR_ADDR → RX_RD_DATA/RX_WR_DATA
│   ├── MOSI shift register (rising edge sample)
│   └── MISO shift register (falling edge shift)
├── regfile                (SCLK domain, reset by sclk_rst_n)
│   ├── Version reg        (0x00, RO, fixed 0x01)
│   ├── RW registers       (0x01-0x04, FFs with reset values)
│   └── RO mux             (0x80-0x83, status inputs)
├── cfg_cdc                (config → sysclk domain)
│   └── 2FF sync cs_n, latch on rising edge
└── status_cdc             (status → SCLK domain)
    └── 2FF per bit, continuous
```

---

## Port List

### Top Level Pads
```verilog
input  wire       sclk,
input  wire       cs_n,
input  wire       mosi,
output wire       miso,
```

### System
```verilog
input  wire       sys_clk,
input  wire       sys_rst_n,
```

### Config Outputs (sysclk domain, latched after SPI transaction)
```verilog
// USER: Add/remove config outputs as needed
output wire [7:0] cfg_enable,      // addr 0x01
output wire [7:0] cfg_clk_div,     // addr 0x02
output wire [7:0] cfg_gain,        // addr 0x03
output wire [7:0] cfg_mode,        // addr 0x04
```

### Status Inputs (sysclk domain, synchronized to SCLK for read)
```verilog
// USER: Add/remove status inputs as needed
input  wire       status_lock,        // addr 0x80, bit[0]
input  wire       status_fifo_empty,  // addr 0x81, bit[0]
input  wire       status_fifo_full,   // addr 0x82, bit[0]
input  wire       status_error,       // addr 0x83, bit[0]
```

---

## Register Map

### RW Registers (Config)

| Address | Name | Reset | Description |
|---------|------|-------|-------------|
| 0x00 | VERSION | 0x01 | RO exception, version ID |
| 0x01 | CFG_ENABLE | 0x00 | [0] TX en, [1] RX en, [7:2] rsvd |
| 0x02 | CFG_CLK_DIV | 0x00 | Clock divider value |
| 0x03 | CFG_GAIN | 0x00 | [3:0] gain, [7:4] rsvd |
| 0x04 | CFG_MODE | 0x00 | [1:0] mode, [7:2] rsvd |

### RO Registers (Status)

| Address | Name | Bit | Description |
|---------|------|-----|-------------|
| 0x80 | STATUS_LOCK | [0] | PLL lock indicator |
| 0x81 | STATUS_FIFO_EMPTY | [0] | FIFO empty flag |
| 0x82 | STATUS_FIFO_FULL | [0] | FIFO full flag |
| 0x83 | STATUS_ERROR | [0] | Error detected |

---

## SPI Slave Interface Signals

### Register File Interface (from spi_slave)
```verilog
output reg        rf_wr_en,      // Write enable pulse (1 SCLK cycle)
output reg  [7:0] rf_addr,       // Register address
output reg  [7:0] rf_wdata,      // Write data
input  wire [7:0] rf_rdata,      // Read data (combinational from regfile)
```

Note: No `rf_rd_en` signal - reads are combinational based on `rf_addr`.

---

## User Customization Checklist

1. **Config registers:** Add/remove entries, update regfile case statements and port list
2. **Status registers:** Add/remove entries, update regfile read mux and port list
3. **Reset values:** Set appropriate defaults for each RW register
4. **Version value:** Change VERSION localparam from 0x01 if needed
5. **CDC modules:** Update cfg_cdc and status_cdc port lists to match

---

## Implementation Notes

1. **FPGA-Friendly Design:**
   - No DFFs with both async set and reset (iCE40 compatible)
   - SPI slave uses only `posedge sclk or posedge cs_n`
   - Register file uses only `posedge sclk or negedge sclk_rst_n`
   - Initial blocks for FPGA power-up initialization

2. **SPI Mode 0 timing:**
   - Sample MOSI on SCLK rising edge
   - Shift MISO on SCLK falling edge

3. **Transaction sequence:**
   - CS_n falls → FSM in RX_CMD state
   - 8 SCLK cycles: command byte (0x00=read, 0x80=write)
   - 8 SCLK cycles: address byte
   - 8 SCLK cycles: data byte (write) or read data out (read)
   - Additional 8-cycle bursts: address auto-increments
   - CS_n rises → FSM resets, config latched to sysclk domain

4. **Read data timing:**
   - Address captured on 8th bit of address byte
   - rf_rdata immediately available (combinational)
   - MISO loads rf_rdata on first falling edge of data byte
   - Subsequent falling edges shift out remaining bits

5. **Write data timing:**
   - rf_wr_en asserted on 8th rising edge of data byte
   - rf_wdata valid with rf_wr_en
   - Single SCLK cycle write pulse

---

## FPGA Synthesis Results (iCE40 UP5K)

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| Logic Cells | 193 | 5280 | 3% |
| Block RAM | 0 | 30 | 0% |
| I/O Pins | ~20 | 96 | ~21% |

All 24 testbench tests passing.
