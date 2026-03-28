# spi-config-interface

SPI Slave + Register File for post-silicon configuration and debug. Verilog implementation targeting FPGAs.

## Features

- **SPI Mode 0** (CPOL=0, CPHA=0) slave interface
- **8-bit address, 8-bit data** register file
- **3-byte transactions**: Command + Address + Data
- **RW registers** (0x01-0x7F) for configuration
- **RO registers** (0x80-0xFF) for status
- **Version register** at 0x00 (fixed 0x01)
- **Clock Domain Crossing** (CDC) using [fpga_cdc_lib](https://github.com/moaz-kh/fpga_cdc_lib) (`cdc_bit`, `cdc_reset`)
- **FSM-based** SPI slave design
- **FPGA-friendly** architecture (no async set+reset)

## Architecture

```
                    +------------------+
    SCLK  --------->|                  |
    CS_n  --------->|    spi_slave     |------> rf_addr[7:0]
    MOSI  --------->|      (FSM)       |------> rf_wdata[7:0]
    MISO <----------|                  |<------ rf_rdata[7:0]
                    +--------+---------+------> rf_wr_en
                             |
                    +--------v---------+
                    |     regfile      |
                    |  (RW + RO regs)  |
                    +--------+---------+
                             |
              +--------------+---------------+
              |                              |
     +--------v---------+           +--------v---------+
     |  cdc_bit (cs_n)  |           |  4x cdc_bit      |
     |  + edge detect   |           |  (continuous      |
     |  + config latch  |           |   synchronizers)  |
     | (SPI -> sysclk)  |           | (sysclk -> SPI)   |
     +--------+---------+           +--------+---------+
              |                              |
              v                              ^
        cfg_enable[7:0]                status_lock
        cfg_clk_div[7:0]               status_fifo_empty
        cfg_gain[7:0]                  status_fifo_full
        cfg_mode[7:0]                  status_error
```

## Register Map

| Address | Name | Type | Description |
|---------|------|------|-------------|
| 0x00 | VERSION | RO | Version ID (fixed 0x01) |
| 0x01 | CFG_ENABLE | RW | Enable configuration |
| 0x02 | CFG_CLK_DIV | RW | Clock divider setting |
| 0x03 | CFG_GAIN | RW | Gain configuration |
| 0x04 | CFG_MODE | RW | Mode selection |
| 0x80 | STATUS_LOCK | RO | Lock status (bit 0) |
| 0x81 | STATUS_FIFO_EMPTY | RO | FIFO empty flag (bit 0) |
| 0x82 | STATUS_FIFO_FULL | RO | FIFO full flag (bit 0) |
| 0x83 | STATUS_ERROR | RO | Error flag (bit 0) |

## SPI Transaction Format

```
Write: [0x80] [ADDR] [DATA]   (Command MSB=1 for write)
Read:  [0x00] [ADDR] [DATA]   (Command MSB=0 for read)
```

## Directory Structure

```
spi-config-interface/
├── sources/
│   ├── rtl/
│   │   ├── spi_regfile_top.v   # Top-level module (CDC logic inline)
│   │   ├── spi_slave.v         # SPI slave FSM
│   │   └── regfile.v           # Register file
│   ├── lib/
│   │   └── fpga_cdc_lib/       # CDC library (git submodule)
│   ├── tb/
│   │   └── spi_regfile_tb.v    # Comprehensive testbench
│   └── constraints/            # FPGA constraint files
├── sim/                        # Simulation outputs
├── backend/                    # Synthesis/PnR outputs
├── Makefile                    # Build system
└── spi_regfile_spec.md         # Design specification
```

## Quick Start

### Check Tools
```bash
make check-tools
```

### Run Simulation
```bash
make sim TOP_MODULE=spi_regfile_top TESTBENCH=spi_regfile_tb
```

### View Waveforms
```bash
make waves TOP_MODULE=spi_regfile_top TESTBENCH=spi_regfile_tb
```

### FPGA Synthesis (iCE40)
```bash
make synth-ice40 TOP_MODULE=spi_regfile_top
```

## Test Results

All 24 tests passing:
- Version register read/write protection
- RW config register operations
- CDC config transfer verification
- RO status register reads
- Write-to-RO ignored
- Unmapped address handling
- Reset behavior

## Dependencies

- [fpga_cdc_lib](https://github.com/moaz-kh/fpga_cdc_lib) — CDC primitives (`cdc_bit`, `cdc_reset`), included as a git submodule

After cloning, initialize the submodule:
```bash
git submodule update --init --recursive
```

## Requirements

- **Icarus Verilog**: `sudo apt install iverilog`
- **GTKWave**: `sudo apt install gtkwave`
- **Yosys** (optional): `sudo apt install yosys`

## License

MIT License — Copyright (c) 2026 [moaz khaled](https://github.com/moaz-kh).

Free to use, modify, and distribute for any purpose. Attribution required — keep the copyright notice in all copies or substantial portions of the code.
