# Netlist Splitter

## Purpose
This script splits a flattened netlist in two based on the directive in a `.prt` file.
It creates two new netlists `top.v` and `bot.v`.

## Extra files needed
- `LEF/` directory with your `.lef` files.
- A folder with you Verilog netlists, e.g. `prt_spc`
- A partition directive file in which each line is formated as follows:
	`<instance name> <die number>`