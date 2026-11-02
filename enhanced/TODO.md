# To do

What is left for the enhanced game, roughly in order. The memory these plans work with is in
[`../original/docs/MEMORY.md`](../original/docs/MEMORY.md): the game is a single load of 412,160
bytes at `$E700`; measured in the emulator, the game uses all but about 17K of a 512K Amiga's
chip RAM (the free part mostly `$015C-$3D79`, which the save routine borrows). The enhanced game
loads the five pictures read only while their own screen is up (124,485 bytes) from the disk when
they are shown: about 89K of chip memory is free now.

## Groundwork

* ~~Try the disk on an A500 and an A1200~~: done (November 2026, the disk of 6ea8ff7): the game,
  the pictures loaded from the disk after races and in the Hall of Fame, on both. (The disk before
  it crashed after a race on a 68000: an address error, fixed - the tests now catch them.)
* ~~A race measured on an A500~~ (`measurements/`): 7.3-7.55 vertical blanks a frame of work,
  6.6-6.8 frames a second (races played by hand, so not the benchmark's race).
* ~~Fit the emulator to the A500~~: done (`measurements/README.md`): the A500's calibration run
  (F7) matched within 1.2% - scremu's 68000 timing corrected (`add.l`/`adda.l` from a register: 8
  cycles, Musashi had 6), each line's overrun carried into the next, and 6 CPU cycles a line lost
  to the display's DMA (`cpulost`). The benchmark's figures are now an A500's: 6.65 vertical
  blanks of work for the released game, 7.5 frames a second.
* Record a race's inputs on a real Amiga (the controls each race frame, the random number's seed at
  the start: in the free memory under the telemetry) and replay them in the emulator: the same
  race, frame by frame, on both - the real machine's costs and the emulator's side by side, and
  the worst moments found in play (frames of 3,500 lines on the A500) made into benchmarks.
* Annotate the rest of the game's source: 196 routines and most of the race's variables are not
  named yet (`original/docs/CODE.md`): the physics, the opponent, the rows' sides and lines, the
  track format.
* ~~Make the source safe to change~~: done - every address in it is a label, checked by
  `tools/reloc_test.py` (in the workflow). The game cannot grow, though: its screens follow the
  code and the work areas (`$7A01A`) follow the screens 263 bytes later. New code replaces old code
  or goes in the unused `CopylockRoutine`'s 1,318 bytes (now `plotpixel.i` and, in the telemetry
  build, `telemetry.i`: about 100 bytes left) - or now that the pictures between races are loaded
  from the disk (below), anywhere: the screens move up with the code, into the 89K freed.
* ~~Remove the self-modifying code~~: done (`original/docs/RENDER.md`): `PlotPixel`'s colours,
  `ColourWordJump`, and the helper block's turbo (now assembled from `src/helper_c0.s`). Checked:
  the enhanced game writes none of its instructions. It cost 2.5% of a frame - won back overall
  by `ScanEdge`'s rewrite, and to be won back in `PlotPixel` and the fill when they are
  rewritten. Runs on an A1200.
* ~~Confirm which memory is free~~: done (`original/docs/MEMORY.md`). `$3D80-$E297` is not free:
  the race's work area and the cut-out graphics.
* ~~Put the 4489_byteloader in the game~~: done (`src/diskload.i`): `DiskRead` reads the boot
  drive (left by the bootblock in the file table), `LoadPicture` loads a file after checking the
  disk is the game's. The game's own `SectorLoader` is kept for the save disk.

## Feature: load each track when it is raced (level loading)

Load what a race needs when it is set up instead of keeping everything in memory.

* The track data is small (1,248 bytes for all 8), so the gain is not the tracks themselves but
  what can come with them: per-track scenery, colours, objects or sounds that would not all fit in
  memory together.
* Hook: the race set-up at `$5D2C8` calls the track builder (`$5AE46`) with the track number
  (`dat_1CA33`): load the track's file (or file set) just before it.
* First work out the track format (`docs/DATA.md`: the builder's tables `$1C4C0`, `$1C524`,
  `$1C588`, `$1C5EC`, `$1F0C2`) and which tables are per track.
* One file per track in the file table; on machines with more memory, keep loaded tracks in a cache
  so the next race on the same track does not touch the disk.

## Feature: load the pictures and sounds of the screens between races

Load the screens shown between races - and new ones - from the disk when they are shown, instead of
keeping them all in memory.

* ~~The pictures shown after a race, at the end of a season and in the Hall of Fame~~: done.
  wreck, season_win, season_crowd, champion and hall_of_fame are files 3-7 on the disk, loaded
  into `DiskPicture` (after the screens, outside what is loaded) by `ShowTablePicture` and
  `HallOfFame` - before the fade, while the screen before still shows. The game is 123,808 bytes
  smaller; free chip memory from `DiskPicture`'s end to the loading picture at `$78000`: 83K (and
  8K more, to the work areas at `$7A01A`, once the loading picture is not needed).
  If the game's disk is not in its drive, it asks for it ("Insert the Stunt Car Racer disc into
  drive n", in white on dark blue on the screen on show) and waits.
* The screens' bytes in the load (`gfx/screens_initial.bin`, 35,692 bytes: what was in that memory
  when the game was saved, drawn over by the game) could be left out of the load - a shorter load
  and disk read at the start.
* New intermediate screens for each race's result - success or failure (race won, race lost,
  crashed, promoted, relegated, ...) - each with its own picture and its own sounds (a crowd cheer,
  a crash, a jingle), loaded from the disk only when the screen is shown: `LoadPicture` and
  `DiskPicture` are ready for the pictures; sounds need a buffer of their own.
* Sounds loaded with a screen go in chip RAM (Paula plays from chip RAM only), in the space freed
  by the pictures; the game's sound driver plays samples through its table (`SampleTable`), which
  can point at loaded ones.
* With more memory, keep the files once loaded (as Ghosts'n Goblins caches its files on 1MB
  machines), so each screen comes from the disk once.

## Performance

Measured ([`../original/docs/RENDER.md`](../original/docs/RENDER.md)): a race frame's work takes
6.65 vertical blanks on an A500 for the released game (5.43 now - 108.7 ms; the limit is 6), 7.5 frames a second (now 8.0, most frames at the limit); geometry 32%, drawing 49%,
cockpit 12%. A word of the view is written 1.87 times a frame (overdraw: moderate - the time goes
on the work for each line and edge more than on pixels written twice). Measure each change with the benchmark (`tools/bench.py --compare
bench_baseline.json`, also run by the workflow) and, for real figures, the telemetry disk in WinUAE.

* ~~`ScanEdge`: step a line at a time, not a pixel~~: done (`ScanXMajor`) - the race 4.5% faster,
  the same edges exactly; 2.1% faster than the released game. `ScanEdge` is still 12.5% of the
  frame: about 120 calls a frame at about 400 cycles each before any stepping (the outcodes, the
  set-up). Measured since: about 100 calls a frame, 4 of them an edge stepped twice (not worth
  sharing); 4 in 5 with both points in the view - ~~those skip the outcodes and the clipping~~
  (done: a test of both points at once); ~~a leaner entry and tail for those~~ (done:
  `ScanEdgeInView` - the header written at once, no `dat_668A2`/`dat_668A6`: the race's work 1.1%
  less).
* ~~**The mountains as an option**~~: done (**F10**, `DrawMountains` returns at once): they cost
  about 79,000 cycles a frame (11% of the work: 23 `ScanEdge` calls, mostly clipped at the view's
  sides, at ~1,400 cycles each, and 6 `FillPolygon`s). Still to do, for when they are on: clip
  them to the view's sides once (they are flat, at the horizon) rather than edge by edge.
* ~~The blitter for the cockpit~~: done (`src/blitcutout.i`): `DrawCutout`'s cut-outs blitted
  (cookie-cut, from copies made at start-up in the blitter's form), the cockpit's time 54% less
  (15.6 ms to 7.2 ms a frame), the race's work 8.8% less than the released game's: 6.07 vertical
  blanks, so most frames now meet `FrameLimiter`'s 6. The CPU waits for each blit. To check on an
  A500: the emulator times the blitter at 2 CPU cycles a memory cycle but not the display's DMA
  taking some of its slots - the calibration run's `cutout` test (now the blitter, below the
  display) and a race's telemetry will show the real figure. Next: let the CPU go on while the
  last blits run (nothing after the cockpit until the instruments).
* ~~The blitter for the background (`DrawHorizon`)~~: done - the sky and ground filled by D-only
  blits (`HorizonFill`, the plane's word in A's data register) instead of 32 `move.l` a line; the
  same bytes; the race's work 2.9% less. ~~Start the fills earlier, so that the blitter runs
  beside the CPU~~: done (`src/blitqueue.i`) - the horizon's top line worked out before the
  geometry (`HorizonEarly`: DrawHorizon's first part into a buffer of its own, everything it
  changes put back), the fills queued and chained by the blitter's interrupt (BLIT), started by
  the copper's interrupt when it flips the screens if the screen was still shown; `DrawHorizon`
  skips its fills when they were for the same line. The race's work 3.5% less. Checked: every
  filled word in 8 races (the fill check, a test build), the game's variables unchanged by
  `HorizonEarly`, the screens frame for frame (aligned runs), and scremu's new `blitcheck` (each
  CPU access to what a running blit writes: none; in the workflow, `bench.py --blitcheck`).
  To check on an A500: the blitter's share of the bus while the CPU works (not modelled).
* The cockpit's blits beside the CPU: looked at, not done - the race loop draws on the screen
  right after the view (`sub_5E12A`'s text, `sub_5DB34`'s times, cut-outs drawn on both screens)
  and the blits are per plane (the screen's planes are not interleaved), so a queue would mean an
  interrupt for each of about 28 blits and waits before each of those writes: about 1% at best.
* `ArcTan`, `RollPointXY`: ~~the car level (no roll) without `RollPointXY`'s 4 `muls`~~ (done:
  its result worked out from the point, exactly - half its time when the car is level; the
  benchmark's telemetry race happens to be rolled nearly throughout, the normal build's level).
  `ArcTan`'s `divu` (half its time) has no exact cheaper form short of a large table.
* ~~`FillBetweenEdges`: its runs unrolled~~: done - the whole words of a run written two at a
  time (`move.l`) from an unrolled sequence jumped into (54 cycles for 16 pixels before, 30 now;
  runs average 11 words), drawing 1.7% less. Still to do: its variables in registers (the line's
  `dat_1BC5A`, `dat_69ACE` and the edge list's bounds are read from memory each line), the
  partial words without the `jsr`/`ColourWordJump` (about 80 cycles of calls for each).
* ~~`PlotPixel` / `DrawEdgeLine`~~: done - `DrawEdgeLine` notes each screen line's run of pixels
  (about 5 a line) and writes it a word at a time through `PlotWord<colour>` (`EdgeFlush`), the
  run's length found at once instead of stepped a pixel at a time: the same pixels (checked: the
  screens frame for frame, in the benchmark's race and two with random steering), the race's
  work 3.5% less.
* The cockpit (11.7%, now 5.7%): ~~F6 turns it off~~ (done); ~~the blitter's cookie-cut for its
  cut-outs~~ (done); the cut-outs split to skip their transparent parts; the
  view's drawing stopped above the engine's solid lines (3,478 pixels of the view are under it).
* ~~The ground under the track~~: no longer worth doing - the ground is filled by the blitter
  while the CPU works out the geometry (`src/blitqueue.i`), so the track's area written twice
  costs the CPU nothing. Filling less ground would only matter where the geometry takes less
  than the fills' 4.6 ms (a CPU about 8 times an A500's).
* ~~**Half the vertical resolution**~~: done (`src/halfres.i`, **F9**) - not with the copper
  (the cockpit's pillars run the whole height of the view, and would be doubled too) but the
  view drawn in its lower 64 lines (`ScanEdge` takes each point's y as 64 + y / 2; the clipping
  unchanged) and doubled by the blitter into the 128 before the sparks and the cockpit are drawn
  at full height. Drawing 19% less, the race's work 10% less (5.26 vertical blanks a frame against
  5.85). Still to do: the doubling's 4.6 ms (8 blits; the CPU waits) - overlapped with something,
  or drawn straight into every other line; at half height the edges' set-up and the projection
  are most of what is left; compare the look in play (the horizon band, the far rows).
* `ArcTan`, `RollPointXY` (7.3%): tables.
* The 6502's leftovers: byte variables at absolute addresses, instructions that do nothing.
* ~~Then the frame rate~~: done (`src/interp.i`, F8 for the release's timing) - the physics at a
  step every 6 vertical blanks to the clock (the game's speed constant, late steps caught up), and
  the view drawn between steps with the cars' places and angles blended: one step's latency,
  traded for smooth motion, when 2 or more pictures fit in a step; the latest step, as before,
  when not (the A500). Still to do: try it on an A1200 and an accelerated A500 (the emulator's
  cpumult is only the CPU); the instruments are still printed once a step; extrapolation instead
  of the step's latency (riskier: crashes); a shorter step for the physics (the game's tuning
  assumes 6 vertical blanks).