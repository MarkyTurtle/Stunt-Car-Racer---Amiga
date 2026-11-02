# Stunt Car Racer - the enhanced game

The game on an ordinary AmigaDOS-format disk with a file table, loaded through the
[4489_byteloader](https://github.com/MarkyTurtle/4489_byteloader), as the Ghosts'n Goblins and
New Zealand Story disks are. The game is assembled from its own source, `src/scr_game.s`,
forked from `original/scr_game.s`, where the improvements go (the disk's SHA-1 is checked by the
workflow). So far it differs from the original in:

* **no self-modifying code** - the game's (`PlotPixel`'s colours, `ColourWordJump`) and the
  helper block's (the turbo), so that the 68020's and later processors' caches can be left on
  ([`../original/docs/RENDER.md`](../original/docs/RENDER.md)); the helper block is assembled from
  [`src/helper_c0.s`](src/helper_c0.s);
* **`ScanEdge` steps a wide edge a line at a time** (`ScanXMajor`), not a pixel at a time: the
  same x on every line as the release (checked for every edge up to 700 pixels wide, and the edge
  buffers compared in play), the race 4.5% faster than before it - 2.1% faster than the released
  game, the cost of removing the self-modifying code won back;
* **the cockpit is drawn by the blitter** (`src/blitcutout.i`): its cut-outs copied at start-up
  into the blitter's form and blitted (cookie-cut) instead of masked word by word by the CPU -
  the cockpit's time halved;
* **`FillBetweenEdges` writes two words a plane at once**, from an unrolled sequence: the track's
  surfaces filled faster;
* **the race keeps to the clock, and faster machines draw more pictures**
  ([`src/interp.i`](src/interp.i)): the physics steps every 6 vertical blanks, as the game was
  designed (8.33 a second), whatever the drawing takes - the release slowed the whole game down
  when a frame took longer (most frames on an A500); a late step is caught up by running the next
  without drawing it. Between steps, a machine with time to spare draws pictures of the moments in
  between: the car's place and angles and the opponent's blended between the last two steps. On
  an A500 each picture is the latest step's, as before (about 8.3 a second); measured in the
  emulator with a faster CPU, 15 a second at twice the A500's speed, 23 at three times, 30 at four,
  50 (every frame) at eight. **F8** switches back to the release's timing; a two-player link race
  always uses it;
* **F9 in a race draws the view at half its height**, each line doubled ([`src/halfres.i`](src/halfres.i)):
  the track, the sky and ground, the mountains and the cars drawn in 64 lines and doubled by the
  blitter, the cockpit and the sparks over them at full height - the drawing 19% quicker, for a
  coarser view;
* **the fills' partial words without the calls**: `FillBetweenEdges` and `FillPolygon` call
  `PlotWord<colour>` at once and work out the edge masks; `FillPolygon`'s whole words unrolled;
* **the track's lines are drawn a run at a time** (`DrawEdgeLine`): each screen line's pixels
  written a word at a time, not one `PlotPixel` call a pixel; edges with both ends in the view skip
  `ScanEdge`'s clipping, and step on their own lean path (`ScanEdgeInView`);
* **the sky and ground are filled by the blitter while the CPU works out the view**
  ([`src/blitqueue.i`](src/blitqueue.i)): the horizon's line found before the geometry and the 8
  fills queued, each started by the blitter's interrupt when the one before is done - 4.6 ms of
  the blitter's time no longer waited for (the race's work 3.5% less); the view's roll is
  skipped when the car is level (`RollPointXY`: the same points without its 4 multiplications);
* **F4 in a race draws the track less far ahead**: 6 of the far pieces' cross-sections instead of
  12 (`ProjectFarPieces`) - the race's work 15% less; the cut is near the horizon, and the
  opponent's car beyond it is not drawn;
* **F10 in a race turns the horizon's mountains off and on**: the race's work about 11% less
  (113 ms to 101 ms a frame on the benchmark; 92 ms with F9's half height too) - the 6 mountain
  polygons and their 23 edges (most of them clipped at the view's sides) are not drawn;
* **F6 in a race turns the cockpit off and on**: its parts are not drawn over the view, to see
  the track to the bottom of the view and what the cockpit costs.
* **the pictures shown between races and in the Hall of Fame are loaded from the disk** when they
  are shown (wreck, season_win, season_crowd, champion, hall_of_fame: 124,485 bytes no longer in
  memory all the time - [`src/diskload.i`](src/diskload.i)): the game is 123,808 bytes smaller and
  about 89K of chip memory is free for the enhancements. The 4489_byteloader reads them from the
  drive the game was booted from; if the game's disk is not in it (a save disk, no disk), the game
  says "Insert the Stunt Car Racer disc into drive n" and waits for it.

Keys in a race: F1 the audio filter, F2 PAL / NTSC, F3 the turbo (no frame limit), F4 the draw
distance, F6 the cockpit, F7 the calibration run (the telemetry disk), F8 the release's timing, F9
half height, F10 the mountains, P pause - and the game's own. Its data (`sound/`, `gfx/`, `tracks/`) is the
original's: the build finds it with `-I original`.

```
python3 enhanced/tools/build_disk.py               # -> enhanced/build/scr.adf
python3 enhanced/tools/test_boot.py                # boots it in the emulator harness: every check "ok"
python3 enhanced/tools/build_disk.py --telemetry   # -> enhanced/build/scr_telemetry.adf (below)
python3 enhanced/tools/bench.py --compare enhanced/bench_baseline.json   # the race benchmark
python3 enhanced/tools/reloc_test.py               # the game still works with its code moved
```

## The disk

| Disk offset | What |
|---|---|
| `$000-$3FF` | the bootblock, [`src/boot_4489.s`](src/boot_4489.s), with the 4489_byteloader ([`src/byteloader.i`](src/byteloader.i)) |
| `$400-$5FF` | the file table: `'SCRF'`, version.w, count.w, 8 bytes zero, then offset.l and length.l per file |
| `$600-` | file 0 the game (`src/scr_game.s`, to `$E700`), file 1 the loading picture (to `$78000`, from `original/bin/`), file 2 the helper block (`src/helper_c0.s`, to `$C0`), files 3-7 the pictures the game loads while it runs (hall_of_fame, wreck, season_win, season_crowd, champion: `original/gfx/`) |

About half the disk is free.

## The boot

The bootblock does what the source disk's boot chain did ([`../original/docs/BOOT.md`](../original/docs/BOOT.md)),
without its decruncher and loader:

1. finds the drive booted from: trackdisk.device's units 3 to 0 opened until one is the boot
   IORequest's (DF0 if none is; Kickstart 1.3 boots only from DF0);
2. takes over: interrupts and DMA off, supervisor mode, stack at `$80000`;
3. copies its loader to `$1000` (file table read to `$1C00`, MFM buffer `$2000-$4EBF`);
4. reads the file table, loads the loading picture and shows it as the original loader did
   (same display registers, copper list and colours);
5. loads the helper block to `$C0` and the game to `$E700`;
6. enters the game as the original loader did: blitter idle, DF0 deselected, DMACON `$0450` off,
   USP `$7FFFC`, SSP `$3D80`, a0 = `$E700`, d0 = 0.

A load that fails is tried again; after 8 failures COLOR00 flashes red while it goes on trying.

## Tests

`tools/test_boot.py` boots the disk in Unicorn with `tools/floppy.py` (from the Ghosts'n Goblins
repository): booted from DF0, DF1, DF3 and from a unit of another device, each with the disk DMA
starting at sector 0 and at a random sector. It checks the game, the picture and the helper block
in memory, the registers and stack at `$E700`, the display and the drive; then calls the game's
own loader (`DiskInit`, `LoadPicture` for each picture file) and compares what it read.

`tools/test_pictures.py` plays the game in the study emulator, with its disk answered from the
ADF: the Hall of Fame and the four pictures shown after races, each loaded and checked; then the
wreck with no disk in, with another disk in (the game asks for its disk and waits) and with its
disk back. `--png DIR` draws the screens.

`tools/measure_keep.py --check` checks `src/interp_keep.i` - the variables the view's drawing
keeps from picture to picture - against two races measured in the emulator: every byte the
drawing alone writes is on the list, and none on it is written by the rest of the game (without
`--check` it merges the measurement into the list).

Both scremu tests (`test_pictures.py`, `reloc_test.py`) fail on any word or long read or written at
an odd address: a 68000 stops there with an address error (a Guru in WinUAE), while the emulators
here would carry on. (The first disk with the pictures loaded from the disk crashed so after a won
race: removing the odd-sized pictures had left `PictureTable` on an odd address.)

## Measuring the speed

**The telemetry build** is the game with each race frame timed: `build_disk.py --telemetry`
assembles `src/scr_game.s` with `TELEMETRY` defined, which swaps 8 of the game's calls for calls of
the same size into [`src/telemetry.i`](src/telemetry.i) (its code fills the space of the unused
`CopylockRoutine`, so no address in the game changes). Each frame is timed in raster lines (64 us)
from the beam's position and a count of vertical blanks, and split into 7 phases - input, cars,
geometry, drawing, cockpit, rest, wait ([`../original/docs/RENDER.md`](../original/docs/RENDER.md)).
The results stay in memory at `$3800-$3C7F` from race to race: the totals of each phase, the
shortest and longest frame, the frames by length in vertical blanks, and the last 64 frames. The
timing costs about 3,700 cycles a frame (0.4%; measured in the emulator).

On a real Amiga or in WinUAE (cycle-exact, A500): play a race with the telemetry disk - and press
**F7** once in it: the calibration run, a second of fixed tests timed to the colour clock
([`src/calibrate.i`](src/calibrate.i)) - then in WinUAE's debugger (Shift+F12) save the results
with `S telemetry.bin 3780 500` and read them:

```
python3 enhanced/tools/telemetry.py telemetry.bin [--list] [--calibration EMULATOR.json]
```

Measurements made so far are in [`measurements/`](measurements).

**The benchmark** (`tools/bench.py`) plays the same race the same way every time in the study
emulator (`original/tools/scremu`): Division 4's first race, a minute of it with the throttle held.
`--opponent` keeps the opponent's car in view all the race (`bench_opponent.json`); `--calibrate`
runs the calibration run in it (the emulator's figures for it).
`--json FILE` keeps its figures and `--compare FILE` shows the change in each phase, so every
change to the game can be measured against `bench_baseline.json` (the game as released: the
original code with the telemetry build's hooks). The
workflow runs it and shows the report on the run's page. The emulator's timing is fitted to an
A500's - its calibration run matches the A500's within 1.2% (`measurements/README.md`) - so the
times are an A500's, and exact from run to run. The released game: 6.65 vertical blanks of work a
frame, 7.5 frames a second; the enhanced game 6.07 and 7.95 (8.8% less work: `ScanEdge`, the
fill and the blitter's cockpit) - near `FrameLimiter`'s limit of a frame every 6 vertical
blanks (8.33 a second). The blitter is timed (scremu's `blittime`).

**The relocation test** (`tools/reloc_test.py`) assembles the game with 16 bytes put in before its
code and checks that it plays the benchmark's race exactly as before - that nothing in the source
holds an address as a number. Run by the workflow: improvements will move code.

## Releases

Publishing a release on GitHub builds the disk from the release's tag (`.github/workflows/release.yml`)
and attaches it as `StuntCarRacer_Enhanced_<tag>.adf`, with the telemetry build as
`StuntCarRacer_Enhanced_<tag>_telemetry.adf`.

Status: plays on an A500 and an A1200 (the disk of 6ea8ff7, November 2026). What is planned:
[`TODO.md`](TODO.md).
