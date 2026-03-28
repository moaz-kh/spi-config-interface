# spi-config-interface

SPI Slave + Register File for post-silicon configuration and debug. SystemVerilog implementation targeting FPGAs, with a Python-based register file generator.

## Features

- **SPI Mode 0** (CPOL=0, CPHA=0) slave interface
- **8-bit address, 8-bit data** register file
- **3-byte transactions**: Command + Address + Data
- **CSV-driven register map** — `regfile.sv` is auto-generated from `sources/regmap/regfile.csv`
- **Four register types**: `RW`, `RO`, `RO_CONST`, `RESERVED`
- **Partial registers** — multiple field types packed into a single address (mask-based writes)
- **Non-zero reset values** supported per field
- **i_/o_ port naming** on all module ports
- **Clock Domain Crossing** using [fpga_cdc_lib](https://github.com/moaz-kh/fpga_cdc_lib) (`cdc_bit`, `cdc_reset`)
- **FSM-based** SPI slave (two-block, `typedef enum`)
- **FPGA-friendly** — synchronous reset + `initial` blocks for power-up

## Architecture

```
                    +------------------+
    SCLK  --------->|                  |
    CS_n  --------->|    spi_slave     |-----> rf_addr[7:0]
    MOSI  --------->|      (FSM)       |-----> rf_wdata[7:0]
    MISO <----------|                  |<----- rf_rdata[7:0]
                    +--------+---------+-----> rf_wr_en
                             |
                    +--------v---------+
                    |     regfile      |  <-- auto-generated from CSV
                    |  (SCLK domain)   |
                    +--+------------+--+
                       |            |
          SCLK→sys_clk |            | sys_clk→SCLK
          (cs_n latch) |            | (per-bit cdc_bit)
                       v            ^
                  cfg_* outputs   status_* inputs
                  (sys_clk)       (sys_clk)
```

**Clock domains:**
- **SCLK domain**: SPI slave + register file storage
- **sys_clk domain**: config outputs (latched on cs_n rising), status inputs (synchronized via cdc_bit)

## Register Map

Defined in `sources/regmap/regfile.csv` and regenerated with `make gen-regfile`.

| Address | Field | Type | Bits | Reset | Description |
|---------|-------|------|------|-------|-------------|
| 0x00 | VERSION | RO_CONST | 7:0 | 0x01 | Version register |
| 0x01 | CFG_ENABLE | RW | 7:0 | 0x00 | Enable configuration |
| 0x02 | CFG_CLK_DIV | RW | 7:0 | 0x00 | Clock divider |
| 0x03 | CFG_THRESH | RW | 7:0 | 0x1A | Threshold (non-zero reset) |
| 0x04 | reserved | RESERVED | 7:0 | — | — |
| 0x05 | CFG_CTRL | RW | 7:4 | 0x0 | Control bits |
| 0x05 | STATUS_BUSY | RO | 3 | — | Busy flag |
| 0x05 | reserved | RESERVED | 2:0 | — | — |
| 0x06 | reserved | RESERVED | 7:0 | — | — |
| 0x07 | CFG_TX_EN | RW | 7 | 1 | TX enable |
| 0x07 | CFG_RX_EN | RW | 6 | 1 | RX enable |
| 0x07 | reserved | RESERVED | 5:3 | — | (implicit gap) |
| 0x07 | CFG_LANE_SEL | RW | 2:1 | 0 | Lane select |
| 0x07 | CFG_LOOPBACK | RW | 0 | 0 | Loopback enable |
| 0x08 | STATUS_CODE | RO | 7:4 | — | 4-bit status code |
| 0x08 | HW_REV | RO_CONST | 3:0 | 0x3 | Hardware revision |
| 0x09 | CFG_GAIN_FINE | RW | 7:5 | 0 | Fine gain adjust |
| 0x09 | STATUS_TEMP_WARN | RO | 4 | — | Temperature warning |
| 0x09 | HW_VARIANT | RO_CONST | 3:2 | 0x2 | Hardware variant |
| 0x09 | reserved | RESERVED | 1:0 | — | — |
| 0x0A | STATUS_FLAGS | RO | 7:0 | — | Full-byte status flags |
| 0x0B | STATUS_RX_ERR | RO | 7:4 | — | RX error code |
| 0x0B | STATUS_TX_ERR | RO | 3:0 | — | TX error code |
| 0x80 | STATUS_LOCK | RO | 0 | — | PLL lock |
| 0x81 | STATUS_FIFO_EMPTY | RO | 0 | — | FIFO empty |
| 0x82 | STATUS_FIFO_FULL | RO | 0 | — | FIFO full |
| 0x83 | STATUS_ERROR | RO | 0 | — | Error flag |
| 0x84 | CFG_GAIN | RW | 7:0 | 0x00 | Gain configuration |
| 0x85 | CFG_MODE | RW | 7:0 | 0x00 | Mode selection |

## SPI Transaction Format

```
Write: [0x80] [ADDR] [DATA]   — Command MSB=1 for write
Read:  [0x00] [ADDR] [DATA]   — Command MSB=0 for read
```

Multi-byte transfers auto-increment the address after each data byte.

## Register File Generator

The register file is auto-generated — **do not edit `regfile.sv` manually**.

```bash
# Edit the register map
vim sources/regmap/regfile.csv

# Regenerate RTL
make gen-regfile
```

### CSV Format

```csv
addr,name,type,reset_value,field_bits,port_name,description
0x01,CFG_ENABLE,RW,0x00,7:0,cfg_enable,Enable configuration register
0x05,CFG_CTRL,RW,0x00,7:4,cfg_ctrl,Control bits
0x05,STATUS_BUSY,RO,0x00,3,status_busy,Busy flag
0x05,reserved,,,2:0,,Reserved
0x80,STATUS_LOCK,RO,0x00,0,status_lock,PLL lock status
```

**Register types:**

| Type | RTL | Port |
|------|-----|------|
| `RW` | FF storage + write mask | `output logic o_<port_name>` |
| `RO` | Input directly to read mux | `input logic i_<port_name>` |
| `RO_CONST` | `localparam` constant | none |
| `RESERVED` | Reads 0, writes ignored | none |

## Directory Structure

```
spi-config-interface/
├── scripts/
│   └── gen_regfile.py          # Register file generator
├── sources/
│   ├── rtl/
│   │   ├── spi_regfile_top.sv  # Top-level (CDC + instantiation)
│   │   ├── spi_slave.sv        # SPI slave FSM
│   │   └── regfile.sv          # AUTO-GENERATED — do not edit
│   ├── regmap/
│   │   └── regfile.csv         # Register map definition
│   ├── lib/
│   │   └── fpga_cdc_lib/       # CDC library (git submodule)
│   ├── tb/
│   │   └── spi_regfile_tb.sv   # Testbench (48 tests, 15 groups)
│   └── rtl_list.f              # Simulation file list
├── sim/
│   ├── waves/                  # VCD waveform dumps
│   └── logs/                   # Simulation logs
├── backend/                    # Synthesis / PnR outputs
├── Makefile
├── CLAUDE.md
├── spi_regfile_spec.md         # Design specification
└── README.md
```

## Quick Start

```bash
# Initialize CDC submodule
git submodule update --init --recursive

# Check tools
make check-tools

# Regenerate register file from CSV
make gen-regfile

# Run simulation
make sim

# View waveforms
make waves
```

## Test Results

**48/48 tests passing** across 15 test groups:

| Group | Coverage |
|-------|----------|
| 1 | Version register read/write protection |
| 2 | Full-byte RW read/write |
| 3 | CDC config transfer to sys_clk |
| 4 | Single-bit RO status registers |
| 5 | Write to RO silently ignored |
| 6 | Unmapped address returns 0x00 |
| 7 | Overwrite and independence of RW regs |
| 8 | Dynamic status signal change |
| 9 | Reset behavior |
| 10 | Non-zero reset value (CFG_THRESH=0x1A) |
| 11 | Multi-field RW at same address with implicit gap |
| 12 | Multi-bit RO + partial RO_CONST at same address |
| 13 | Three-way RW+RO+RO_CONST at same address |
| 14 | Full-byte RO (8-bit input) |
| 15 | Two multi-bit RO fields packed at same address |

## Dependencies

- [fpga_cdc_lib](https://github.com/moaz-kh/fpga_cdc_lib) — CDC primitives, included as a git submodule

```bash
git submodule update --init --recursive
```

## Requirements

- **Icarus Verilog**: `sudo apt install iverilog`
- **GTKWave**: `sudo apt install gtkwave`
- **Yosys** (optional, for synthesis): `sudo apt install yosys`
- **Python 3.6+** (stdlib only, for `gen_regfile.py`)

## License

MIT License — Copyright (c) 2026 [moaz khaled](https://github.com/moaz-kh).
