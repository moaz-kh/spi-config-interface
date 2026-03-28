#!/usr/bin/env python3
"""
gen_regfile.py - Register file generator for SPI config interface.

Reads a CSV register map definition and generates a SystemVerilog regfile module.
Supports multiple fields per address (partial registers with mask-based writes).

Usage:
    python3 scripts/gen_regfile.py --input sources/regmap/regfile.csv --output sources/rtl/regfile.sv
    python3 scripts/gen_regfile.py --input sources/regmap/regfile.csv --output -   # stdout

CSV columns:
    addr        - Hex address (0x00-0xFF). Multiple rows may share the same address.
    name        - SCREAMING_SNAKE_CASE field name (or "reserved" for reserved bits)
    type        - RW | RO_CONST | RO (ignored for reserved rows)
    reset_value - Hex value: reset value (RW), fixed constant (RO_CONST), ignored (RO/reserved)
    field_bits  - Bit range in the 8-bit register: "7:0" (full byte), "7:5", or "0" (single bit)
    port_name   - Output port (RW), input port (RO), empty (RO_CONST/reserved)
    description - Human-readable description, used as a comment in generated SV
"""

import csv
import sys
import argparse
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Dict


REQUIRED_COLS = {"addr", "name", "type", "reset_value", "field_bits", "port_name", "description"}
VALID_TYPES   = {"RW", "RO_CONST", "RO"}


@dataclass
class RegEntry:
    """One field within a register (one CSV row)."""
    addr:        int
    addr_hex:    str   # SV literal, e.g. "8'h01"
    addr_2d:     str   # Two-digit hex string for names, e.g. "01"
    name:        str
    reg_type:    str   # RW | RO_CONST | RO | RESERVED
    reset_value: int
    reset_hex:   str   # SV literal, e.g. "8'h00"
    field_bits:  str   # Raw string from CSV, e.g. "7:0" or "0"
    field_hi:    int
    field_lo:    int
    field_width: int
    port_name:   str
    description: str


@dataclass
class AddrGroup:
    """All fields at one address, plus computed masks."""
    addr:       int
    addr_hex:   str
    addr_2d:    str
    fields:     List[RegEntry]  # sorted by field_hi descending
    wr_mask:    int = 0         # bitmask of writable bits
    rst_val:    int = 0         # composite reset value for the FF
    has_rw:     bool = False


def parse_args():
    p = argparse.ArgumentParser(
        description="Generate SystemVerilog regfile from a CSV register map."
    )
    p.add_argument("--input",  required=True, help="Input CSV file path")
    p.add_argument("--output", required=True, help="Output SV file path (use - for stdout)")
    return p.parse_args()


def sv_hex(val: int) -> str:
    return f"8'h{val:02X}"


def parse_field_bits(raw: str, row_id: str):
    """Parse field_bits string. Returns (hi, lo, width)."""
    raw = raw.strip()
    if ":" in raw:
        parts = raw.split(":")
        if len(parts) != 2:
            raise ValueError(f"{row_id}: field_bits '{raw}' must be 'hi:lo' or a single bit index")
        hi, lo = int(parts[0].strip()), int(parts[1].strip())
    else:
        hi = lo = int(raw)
    if not (0 <= lo <= hi <= 7):
        raise ValueError(f"{row_id}: field_bits '{raw}' — values must be in range 0-7 with hi >= lo")
    return hi, lo, hi - lo + 1


def load_and_validate(path: str) -> List[RegEntry]:
    entries    = []
    seen_ports = {}

    with open(path, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        reader.fieldnames = [c.strip() for c in (reader.fieldnames or [])]

        missing = REQUIRED_COLS - set(reader.fieldnames)
        if missing:
            print(f"ERROR: CSV missing required columns: {sorted(missing)}", file=sys.stderr)
            sys.exit(1)

        for i, row in enumerate(reader, start=2):
            row = {k: v.strip() for k, v in row.items()}

            if not any(row.values()):
                continue

            row_id = f"row {i} ({row.get('name', '?')})"

            # --- addr ---
            try:
                addr = int(row["addr"], 16)
            except ValueError:
                print(f"ERROR: {row_id}: cannot parse addr '{row['addr']}' as hex", file=sys.stderr)
                sys.exit(1)
            if not 0 <= addr <= 255:
                print(f"ERROR: {row_id}: addr 0x{addr:02X} out of range 0x00-0xFF", file=sys.stderr)
                sys.exit(1)

            # --- reserved field ---
            if row["name"].lower() == "reserved":
                try:
                    fhi, flo, fwidth = parse_field_bits(row["field_bits"], row_id)
                except (ValueError, KeyError):
                    fhi, flo, fwidth = 7, 0, 8
                entries.append(RegEntry(
                    addr=addr, addr_hex=sv_hex(addr), addr_2d=f"{addr:02X}",
                    name="reserved", reg_type="RESERVED",
                    reset_value=0, reset_hex="8'h00",
                    field_bits=f"{fhi}:{flo}", field_hi=fhi, field_lo=flo, field_width=fwidth,
                    port_name="", description="Reserved",
                ))
                continue

            # --- type ---
            reg_type = row["type"]
            if reg_type not in VALID_TYPES:
                print(f"ERROR: {row_id}: type must be RW, RO_CONST, or RO — got '{reg_type}'", file=sys.stderr)
                sys.exit(1)

            # --- reset_value ---
            try:
                reset_val = int(row["reset_value"], 16)
            except ValueError:
                print(f"ERROR: {row_id}: cannot parse reset_value '{row['reset_value']}' as hex", file=sys.stderr)
                sys.exit(1)

            # --- field_bits ---
            try:
                fhi, flo, fwidth = parse_field_bits(row["field_bits"], row_id)
            except ValueError as e:
                print(f"ERROR: {e}", file=sys.stderr)
                sys.exit(1)

            # --- validate reset fits in field width ---
            if reg_type == "RW" and reset_val >= (1 << fwidth):
                print(f"ERROR: {row_id}: reset_value 0x{reset_val:02X} does not fit in {fwidth}-bit field", file=sys.stderr)
                sys.exit(1)

            # --- port_name ---
            port_name = row["port_name"]
            if reg_type in ("RW", "RO") and not port_name:
                print(f"ERROR: {row_id}: port_name is required for type {reg_type}", file=sys.stderr)
                sys.exit(1)
            if reg_type == "RO_CONST" and port_name:
                print(f"ERROR: {row_id}: RO_CONST registers must have an empty port_name", file=sys.stderr)
                sys.exit(1)
            if port_name and port_name in seen_ports:
                print(f"ERROR: {row_id}: duplicate port_name '{port_name}' (already used by {seen_ports[port_name]})", file=sys.stderr)
                sys.exit(1)
            if port_name:
                seen_ports[port_name] = row["name"]

            entries.append(RegEntry(
                addr        = addr,
                addr_hex    = sv_hex(addr),
                addr_2d     = f"{addr:02X}",
                name        = row["name"],
                reg_type    = reg_type,
                reset_value = reset_val,
                reset_hex   = sv_hex(reset_val),
                field_bits  = row["field_bits"],
                field_hi    = fhi,
                field_lo    = flo,
                field_width = fwidth,
                port_name   = port_name,
                description = row["description"],
            ))

    if not entries:
        print("ERROR: No valid register entries found in CSV", file=sys.stderr)
        sys.exit(1)

    entries.sort(key=lambda e: (e.addr, -e.field_hi))
    return entries


def group_by_address(entries: List[RegEntry]) -> List[AddrGroup]:
    """Group entries by address, compute write masks and reset values, validate overlaps."""
    addr_map: Dict[int, List[RegEntry]] = {}
    for e in entries:
        addr_map.setdefault(e.addr, []).append(e)

    groups = []
    for addr in sorted(addr_map.keys()):
        fields = sorted(addr_map[addr], key=lambda f: -f.field_hi)

        # --- validate no overlapping bits ---
        used_bits = [False] * 8
        for f in fields:
            for bit in range(f.field_lo, f.field_hi + 1):
                if used_bits[bit]:
                    print(f"ERROR: addr 0x{addr:02X} field '{f.name}': bit {bit} overlaps with another field", file=sys.stderr)
                    sys.exit(1)
                used_bits[bit] = True

        # --- compute write mask and composite reset ---
        wr_mask = 0
        rst_val = 0
        has_rw  = False
        for f in fields:
            if f.reg_type == "RW":
                has_rw = True
                for bit in range(f.field_lo, f.field_hi + 1):
                    wr_mask |= (1 << bit)
                rst_val |= (f.reset_value << f.field_lo)

        groups.append(AddrGroup(
            addr     = addr,
            addr_hex = sv_hex(addr),
            addr_2d  = f"{addr:02X}",
            fields   = fields,
            wr_mask  = wr_mask,
            rst_val  = rst_val,
            has_rw   = has_rw,
        ))

    return groups


def build_read_expr(g: AddrGroup) -> str:
    """Build the 8-bit read expression for one address by walking bits 7→0."""
    # Optimization: single field covering all 8 bits
    if len(g.fields) == 1:
        f = g.fields[0]
        if f.field_hi == 7 and f.field_lo == 0:
            if f.reg_type == "RW":
                return f"reg_{g.addr_2d}"
            if f.reg_type == "RO_CONST":
                return f.name
            if f.reg_type == "RESERVED":
                return "8'h00"
            if f.reg_type == "RO":
                return f"i_{f.port_name}"

    # Build a bit-map: for each bit, what is its source?
    bit_source = [None] * 8  # None = gap (implicit reserved)
    for f in g.fields:
        for bit in range(f.field_lo, f.field_hi + 1):
            bit_source[bit] = f

    # Walk from bit 7 to 0, building concatenation parts
    parts = []
    bit = 7
    while bit >= 0:
        src = bit_source[bit]
        if src is None or src.reg_type == "RESERVED":
            # Count consecutive zero bits
            zero_start = bit
            while bit >= 0 and (bit_source[bit] is None or bit_source[bit].reg_type == "RESERVED"):
                bit -= 1
            width = zero_start - bit
            parts.append(f"{width}'b0")
        else:
            # Emit the field (from its hi down to its lo)
            f = src
            if f.reg_type == "RW":
                if f.field_hi == 7 and f.field_lo == 0:
                    parts.append(f"reg_{g.addr_2d}")
                else:
                    parts.append(f"reg_{g.addr_2d}[{f.field_hi}:{f.field_lo}]")
            elif f.reg_type == "RO":
                parts.append(f"i_{f.port_name}")
            elif f.reg_type == "RO_CONST":
                # Extract the relevant bits of the constant
                const_bits = (f.reset_value >> 0) & ((1 << f.field_width) - 1)
                parts.append(f"{f.field_width}'h{const_bits:X}")
            bit = f.field_lo - 1

    if len(parts) == 1:
        return parts[0]
    return "{" + ", ".join(parts) + "}"


def generate_sv(groups: List[AddrGroup], all_entries: List[RegEntry], csv_path: str) -> str:
    # Collect typed entries across all groups
    rw_fields  = [e for e in all_entries if e.reg_type == "RW"]
    ro_fields  = [e for e in all_entries if e.reg_type == "RO"]
    ro_const   = [e for e in all_entries if e.reg_type == "RO_CONST"]
    rw_groups  = [g for g in groups if g.has_rw]

    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    L = []

    # -------------------------------------------------------------------------
    # Auto-generated header
    # -------------------------------------------------------------------------
    L += [
        "// " + "=" * 77,
        "// AUTO-GENERATED FILE — DO NOT EDIT MANUALLY",
        f"// Source:    {csv_path}",
        f"// Generated: {now}",
        "// Generator: scripts/gen_regfile.py",
        "// " + "=" * 77,
        "//",
        "// Register File",
        "// 8-bit data, 8-bit address",
    ]
    for g in groups:
        for f in g.fields:
            L.append(f"// {f.addr_hex}[{f.field_hi}:{f.field_lo}]: {f.name:<20} ({f.reg_type:<8}) {f.description}")
    L += ["", ""]

    # -------------------------------------------------------------------------
    # Module declaration — fixed ports
    # -------------------------------------------------------------------------
    L += [
        "module regfile (",
        "    input  logic       i_sclk,",
        "    input  logic       i_sclk_rst_n,",
        "",
        "    // SPI Slave Interface",
        "    input  logic       i_wr_en,",
        "    input  logic [7:0] i_addr,",
        "    input  logic [7:0] i_wdata,",
        "    output logic [7:0] o_rdata,",
    ]

    # RW output ports (width matches field)
    if rw_fields:
        L.append("")
        L.append("    // Config Outputs (RW fields)")
        for e in rw_fields:
            if e.field_width == 8:
                decl = f"    output logic [7:0] o_{e.port_name}"
            else:
                decl = f"    output logic [{e.field_hi - e.field_lo}:0] o_{e.port_name}"
            L.append(f"{decl},  // {e.addr_hex}[{e.field_hi}:{e.field_lo}]: {e.name}")

    # RO input ports (last group — no trailing comma on final entry)
    if ro_fields:
        L.append("")
        L.append("    // Status Inputs (RO fields)")
        for i, e in enumerate(ro_fields):
            is_last = (i == len(ro_fields) - 1)
            if e.field_width == 1:
                decl = f"    input  logic       i_{e.port_name}"
            else:
                decl = f"    input  logic [{e.field_hi - e.field_lo}:0] i_{e.port_name}"
            comment = f"  // {e.addr_hex}[{e.field_hi}:{e.field_lo}]: {e.name}"
            comma   = "" if is_last else ","
            L.append(decl + comma + comment)

    L.append(");")

    # -------------------------------------------------------------------------
    # Localparams
    # -------------------------------------------------------------------------
    L += [
        "",
        "    " + "/" * 74,
        "    // Parameters",
        "    " + "/" * 74,
    ]
    for e in ro_const:
        L.append(f"    localparam logic [7:0] {e.name:<12} = {e.reset_hex};  // {e.description}")
    L.append("    // Reset Values")
    for g in rw_groups:
        L.append(f"    localparam logic [7:0] RW_RST_{g.addr_2d}  = {sv_hex(g.rst_val)};")
    L.append("    // Write Masks")
    for g in rw_groups:
        L.append(f"    localparam logic [7:0] WR_MASK_{g.addr_2d} = {sv_hex(g.wr_mask)};")

    # -------------------------------------------------------------------------
    # RW Register Storage (one FF per address with RW bits)
    # -------------------------------------------------------------------------
    if rw_groups:
        L += [
            "",
            "    " + "/" * 74,
            "    // RW Register Storage",
            "    " + "/" * 74,
        ]
        for g in rw_groups:
            rw_names = [f.name for f in g.fields if f.reg_type == "RW"]
            L.append(f"    logic [7:0] reg_{g.addr_2d};  // {', '.join(rw_names)}")

    # -------------------------------------------------------------------------
    # FPGA Power-up Initialization
    # -------------------------------------------------------------------------
    L += [
        "",
        "    " + "/" * 74,
        "    // FPGA Power-up Initialization",
        "    " + "/" * 74,
        "    initial begin",
    ]
    for g in rw_groups:
        L.append(f"        reg_{g.addr_2d} = RW_RST_{g.addr_2d};")
    L.append("        o_rdata  = 8'd0;")
    L.append("    end")

    # -------------------------------------------------------------------------
    # Write Logic (always_ff) — mask-based
    # -------------------------------------------------------------------------
    L += [
        "",
        "    " + "/" * 74,
        "    // Write Logic — RW Registers Only (mask-based)",
        "    // Writes to RO and unmapped addresses are silently ignored",
        "    " + "/" * 74,
        "    always_ff @(posedge i_sclk or negedge i_sclk_rst_n) begin",
        "        if (!i_sclk_rst_n) begin",
    ]
    for g in rw_groups:
        L.append(f"            reg_{g.addr_2d} <= RW_RST_{g.addr_2d};")
    L += [
        "        end else if (i_wr_en) begin",
        "            case (i_addr)",
    ]
    for g in rw_groups:
        L.append(f"                {g.addr_hex}: reg_{g.addr_2d} <= i_wdata & WR_MASK_{g.addr_2d};")
    L += [
        "                default: ; // RO and unmapped addresses ignored",
        "            endcase",
        "        end",
        "    end",
    ]

    # -------------------------------------------------------------------------
    # Read Logic (always_comb) — one case item per address
    # -------------------------------------------------------------------------
    L += [
        "",
        "    " + "/" * 74,
        "    // Read Logic — Combinational (no latency)",
        "    " + "/" * 74,
        "    always_comb begin",
        "        case (i_addr)",
    ]
    for g in groups:
        expr = build_read_expr(g)
        L.append(f"            {g.addr_hex}: o_rdata = {expr};")
    L += [
        "            default: o_rdata = 8'h00;  // Unmapped addresses",
        "        endcase",
        "    end",
    ]

    # -------------------------------------------------------------------------
    # Config Output Assignments (bit-sliced)
    # -------------------------------------------------------------------------
    if rw_fields:
        L += [
            "",
            "    " + "/" * 74,
            "    // Config Output Assignments",
            "    " + "/" * 74,
        ]
        for e in rw_fields:
            pname = f"o_{e.port_name}"
            if e.field_hi == 7 and e.field_lo == 0:
                L.append(f"    assign {pname:<22} = reg_{e.addr_2d};")
            else:
                L.append(f"    assign {pname:<22} = reg_{e.addr_2d}[{e.field_hi}:{e.field_lo}];")

    L += ["", "endmodule", ""]
    return "\n".join(L)


def main():
    args    = parse_args()
    entries = load_and_validate(args.input)
    groups  = group_by_address(entries)
    sv_text = generate_sv(groups, entries, args.input)

    if args.output == "-":
        sys.stdout.write(sv_text)
    else:
        try:
            out = Path(args.output)
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(sv_text, encoding="utf-8")
            n_addr = len(groups)
            n_fields = len(entries)
            print(f"Generated: {args.output}  ({n_addr} addresses, {n_fields} fields)")
        except OSError as e:
            print(f"ERROR: cannot write to '{args.output}': {e}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
