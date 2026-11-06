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
race - the chains are drawn as more cut-outs while the car bounces (`RaceView`: `BoostOn`), so
its 264-294 lines a frame here against 185-193 in the benchmark are not the same work. The
calibration run (below) compares like with like.

## `a500_dec9b39_calibration.bin` - an A500, the telemetry disk of dec9b39 (November 2026)

A second race, with F7 pressed: the calibration run's results (`$3780`) with the race's (515
frames, 147.2 ms a frame, 6.8 frames a second, the work 7.32 vertical blanks). The calibration run
does the same fixed work on any machine (`../src/calibrate.i`: each test from line 300 with the
interrupts off, timed by the beam to the colour clock). (Its count of runs, 43,691, is not one:
that disk did not clear the count before its first run - fixed since.) Against the emulator
(`telemetry.py a500_dec9b39_calibration.bin --calibration scremu_calibration.json`):

| Test | A500 (CPU cycles) | Emulator | A500 / emulator | What |
|---|---:|---:|---:|---|
| regs | 53,654 | 53,012 | 1.012 | registers only: 2,000 `add.l`, `eor.l`, `dbra` |
| mul | 27,600 | 27,884 | 0.990 | 400 `mulu` |
| read | 36,992 | 36,816 | 1.005 | chip memory read: 2,000 words |
| write | 45,414 | 44,928 | 1.011 | chip memory written: 2,000 longs |
| rmw | 45,414 | 44,928 | 1.011 | chip memory read and written: 2,000 words |
| cutout | 91,950 | 91,948 | 1.000 | `DrawCutout`: the cockpit's widest part, twice |
| plotpixel | 100,352 | 100,374 | 1.000 | `PlotPixel`: 500 pixels |
| fill | 90,436 | 90,656 | 0.998 | `ClearWordPlanes`/`PlotWord`: 500 words |

## The emulator's model, fitted to it

Before the fit the emulator was 8-20% fast (the A500's figures 1.08-1.20 times its own). Three
changes to scremu (`original/tools/scremu`) bring every test within 1.2%:

* **The 68000's cycles corrected**: Musashi gives `add.l`, `sub.l`, `and.l`, `or.l` (to a data
  register) and `adda.l`, `suba.l` from a register 6 cycles; a 68000 takes 8 (patched in `build.sh`).
* **Each raster line's overrun carried** into the next: an instruction that ends past a line's 454
  cycles takes the time from the next line (it had been forgiven, so the time lost to DMA below
  was lost twice in some tests and not at all in others).
* **6 CPU cycles a line lost to DMA** (`cpulost`, the default): the display's 4 low-resolution
  bitplanes, the sprites, the disk and the audio take some of the bus's slots the 68000 would use.
  A flat 6 cycles a line fits every test, the chip memory ones and the ones in registers alike - a
  68000 at 7 MHz leaves most of the slots free in low resolution. (Rounding each instruction's
  chip memory accesses to the bus's 4-cycle slots - scremu's `chipbus` - does not fit: the tests
  with no memory access are slowed too.)

The race benchmark's figures (`../tools/bench.py`) are therefore an A500's: the released game
6.65 vertical blanks of work a frame, 7.5 frames a second (the hand-played races, other parts of
the track: 7.3-7.55). `scremu_calibration.json` is the emulator's calibration run under this
model (`bench.py --calibrate --json`), for `telemetry.py A500.bin --calibration
scremu_calibration.json`.
