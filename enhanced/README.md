# Stunt Car Racer - the enhanced game

The game on an ordinary AmigaDOS-format disk with a file table, loaded through the
[4489_byteloader](https://github.com/MarkyTurtle/4489_byteloader), as the Ghosts'n Goblins and
New Zealand Story disks are. The game is assembled from its own source, `src/scr_game.s`,
forked from `original/scr_game.s`: for now unchanged (the disk's SHA-1 is checked by the
workflow), and where the improvements go. Its data (`sound/`, `gfx/`, `tracks/`) is the
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
| `$600-` | file 0 the game (`src/scr_game.s`, to `$E700`), file 1 the loading picture (to `$78000`), file 2 the helper block (to `$C0`); the last two from `original/bin/` |

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
in memory against `original/`, the registers and stack at `$E700`, the display and the drive.

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

On a real Amiga or in WinUAE (cycle-exact, A500): play a race with the telemetry disk, then in
WinUAE's debugger (Shift+F12) save the results with `S telemetry.bin 3800 480` and read them:

```
python3 enhanced/tools/telemetry.py telemetry.bin [--list]
```

**The benchmark** (`tools/bench.py`) plays the same race the same way every time in the study
emulator (`original/tools/scremu`): Division 4's first race, a minute of it with the throttle held.
`--json FILE` keeps its figures and `--compare FILE` shows the change in each phase, so every
change to the game can be measured against `bench_baseline.json` (the game as it is now). The
workflow runs it and shows the report on the run's page. The emulator's times are close to an
A500's (it does not slow the CPU for the display's memory use) and exact from run to run.

**The relocation test** (`tools/reloc_test.py`) assembles the game with 16 bytes put in before its
code and checks that it plays the benchmark's race exactly as before - that nothing in the source
holds an address as a number. Run by the workflow: improvements will move code.

## Releases

Publishing a release on GitHub builds the disk from the release's tag (`.github/workflows/release.yml`)
and attaches it as `StuntCarRacer_Enhanced_<tag>.adf`, with the telemetry build as
`StuntCarRacer_Enhanced_<tag>_telemetry.adf`.

Status: boots to the game's entry in the harness; still to try in WinUAE. What is planned:
[`TODO.md`](TODO.md).
