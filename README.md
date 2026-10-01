# FPGA_Functionality_Verifier

Go/no-go bring-up test for Opal Kelly XEM7310-A75 boards (Artix-7 XC7A75T). It checks that a board enumerates
over USB, accepts a bitstream, and passes data in both directions through FrontPanel, and it walks the eight
user LEDs so an operator can confirm each one. I used this design as the data-path check when testing the lab's
XEM7310 boards for Harvard's CS 1410.

## Files

| File | What it does |
| --- | --- |
| `fp_wire_test.v` | `okHost` with three endpoints: WireIn 0x00 drives the LEDs (active low), WireOut 0x20 is a free-running 32-bit counter on `okClk`, WireOut 0x21 echoes WireIn 0x00 |
| `fp_wire_test.xdc` | FrontPanel host-interface pins and the eight LEDs |
| `fp_wire_test.py` | Host check: configure, read the counter twice, walk ten patterns through the loopback, print PASS or FAIL |
| `auto_attach_ok.ps1` | Windows helper that watches `usbipd` for Opal Kelly devices (USB ID 151f:0130) and attaches each new board to WSL2 |

## What the host check does

1. Opens the first XEM7310 it finds and prints its serial number.
2. Loads the bitstream and confirms FrontPanel is enabled.
3. Reads WireOut 0x20 twice, 50 ms apart; the counter must change (the design is clocked and FPGA-to-PC reads work).
4. Writes ten values to WireIn 0x00 (all on, all off, then a single bit walking from 0 to 7) and checks each one
   comes back on WireOut 0x21 (PC-to-FPGA writes work); the LEDs show each pattern for 0.4 s.
5. Prints `RESULT: PASS` and exits 0, or `RESULT: FAIL` and exits 1.

It does not test the on-board DDR3, the MC1/MC2 expansion I/O, the GTP transceivers, FrontPanel pipes or
triggers, or operation under thermal load.

## Building and running

The Opal Kelly FrontPanel HDL library (`okHost`, `okWireIn`, `okWireOut`, `okWireOR`) and the FrontPanel SDK
are not included; get them from your FrontPanel installation.

1. In Vivado, create a project for `xc7a75tfgg484-1` with `fp_wire_test.v`, `fp_wire_test.xdc` and the
   FrontPanel HDL sources, then generate the bitstream.
2. Install the FrontPanel SDK so its Python `ok` module is importable.
3. With a board connected:

   ```sh
   python3 fp_wire_test.py fp_wire_test.bit
   ```

To test boards from WSL2, run `auto_attach_ok.ps1` in an administrator PowerShell
(`powershell -ExecutionPolicy Bypass -File .\auto_attach_ok.ps1`). It binds and attaches each board as it is
plugged in; set `$RunTest = $true` in the script to run the Python check automatically on each one.
