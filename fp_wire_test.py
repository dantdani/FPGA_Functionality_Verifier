#!/usr/bin/env python3
"""
fp_wire_test.py -- FrontPanel data-path test + full LED exercise for XEM7310.

What it proves:
  - okHost link is up                       (IsFrontPanelEnabled)
  - FPGA -> PC reads work and design is live (WireOut 0x20 counter changes)
  - PC -> FPGA writes work, every step       (WireIn 0x00 -> LEDs, loopback 0x21)
  - EVERY LED individually                   (walks a single lit LED 0..7)

Usage:  python3 fp_wire_test.py fp_wire_test.bit
"""
import sys, time, ok

bit = sys.argv[1] if len(sys.argv) > 1 else "fp_wire_test.bit"

dev = ok.okCFrontPanel()
if dev.OpenBySerial("") != 0:
    print("ERROR: no XEM7310 found over USB."); sys.exit(1)

info = ok.okTDeviceInfo(); dev.GetDeviceInfo(info)
print(f"Board: {info.productName}  serial: {info.serialNumber}")

if dev.ConfigureFPGA(bit) != 0:
    print(f"ERROR: failed to configure with '{bit}'."); sys.exit(1)

if not dev.IsFrontPanelEnabled():
    print("ERROR: FrontPanel not responding -- data path FAILED."); sys.exit(1)
print("FrontPanel link up.")

# --- FPGA -> PC: counter must advance between two reads ---
dev.UpdateWireOuts(); c1 = dev.GetWireOutValue(0x20)
time.sleep(0.05)
dev.UpdateWireOuts(); c2 = dev.GetWireOutValue(0x20)
counter_ok = (c1 != c2)
print(f"counter: read1=0x{c1:08X} read2=0x{c2:08X}  changing={counter_ok}")

# --- PC -> FPGA: drive LEDs through every pattern, verify loopback each time ---
# 0xFF = all LEDs on (active-low handled in HW), 0x00 = all off,
# then a single lit LED walking 0..7 so each LED is tested on its own.
patterns  = [("ALL ON", 0xFF), ("ALL OFF", 0x00)]
patterns += [(f"LED {i}", 1 << i) for i in range(8)]

leds_ok = True
for name, val in patterns:
    dev.SetWireInValue(0x00, val)
    dev.UpdateWireIns()
    dev.UpdateWireOuts()
    loop = dev.GetWireOutValue(0x21) & 0xFF
    ok_step = (loop == val)
    leds_ok &= ok_step
    print(f"  {name:7s}  wrote=0x{val:02X}  loopback=0x{loop:02X}  {'ok' if ok_step else 'MISMATCH'}")
    time.sleep(0.4)   # slow enough for your eyes to confirm the LED

# leave all LEDs on at the end so you can eyeball the whole row
dev.SetWireInValue(0x00, 0xFF); dev.UpdateWireIns()

print("-" * 40)
if counter_ok and leds_ok:
    print("RESULT: PASS -- data path works both ways and all 8 LEDs respond.")
    print("(Watch the row: it lit all-on, all-off, then walked LED0->LED7.)")
    sys.exit(0)
else:
    print("RESULT: FAIL -- check counter/loopback output above.")
    sys.exit(1)