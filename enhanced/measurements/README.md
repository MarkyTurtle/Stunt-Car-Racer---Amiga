# Measurements on real Amigas

What the telemetry build (`../src/telemetry.i`, `../src/calibrate.i`) measured on real machines
(or WinUAE's cycle-exact ones), kept to compare the emulator's figures and later versions with.
Each file is the telemetry saved in WinUAE's debugger after a race; `../tools/telemetry.py` reads
it (`a500_6ea8ff7_race.txt` is its report, `.json` its figures).

## `a500_6ea8ff7_race.bin` - an A500, the disk of 6ea8ff7 (November 2026)

A race played by hand (not the benchmark's race): 246 race frames, **151.4 ms a frame on average,
6.6 frames a second**; the work 7.55 vertical blanks a frame (the limit allows 6); 46 frames of 6
vertical blanks, 68 of 7, 98 of 8, 34 of 9 or more. Near the end, frames of 3,000-3,500 lines (10-11
vertical blanks, about 4.5 frames a second): drawing up to 2,000 lines, geometry up to 1,000.

It cannot be compared phase by phase with the emulator's benchmark: the race is another (other
parts of the track in view, the opponent elsewhere) and even the cockpit's work changes with the
race - the chains are drawn as more cut-outs while the car bounces (`RaceView`: `dat_1BB62`), so
its 264-294 lines a frame here against 185-193 in the benchmark are not the same work. What it does
show: on a real A500 a frame's work is nearer 7.5 vertical blanks than the emulator's 6.5.

To compare like with like: F7 in a race of the telemetry build runs the calibration run - the same
fixed tests on any machine (`../src/calibrate.i`) - and `S telemetry.bin 3780 500` saves its
results with the race's; `bench.py --calibrate` gives the emulator's figures for the same tests
(`telemetry.py FILE --calibration EMULATOR.json` puts them side by side), from which the emulator's
timing (scremu's `chipbus`) is to be fitted.

## The emulator's calibration figures

`scremu_calibration.json` (each instruction its 68000 cycles, as scremu runs by default) and
`scremu_chipbus_calibration.json` (`chipbus`: rounded up to 4 cycles from chip memory): the same
calibration run in the emulator (`bench.py --calibrate [--chipbus] --json`), for
`telemetry.py A500.bin --calibration scremu_calibration.json`.
