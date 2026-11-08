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
* ~~A number written as a label~~: found and fixed (November 2026) - `PrintCharNow`'s glyph
  masks were `#dat_1F800` and `#dat_1FC00`, labels that equal the numbers $1F800 and $1FC00 only
  in the release. In the enhanced game they had moved to $1F828 and $1FC28, and every character
  painted two background pixels 11 and 13 pixels to its right (seen after the last character of
  any text). Both sources now have the numbers; `tools/reloc_test.py` now compares the screens
  too (it caught this one: 60 bytes), not only the routines' calls. Others like it may remain
  where a value is used only as data.
* ~~Annotate the rest of the game's source~~: done (November 2026) - every routine and every race
  variable named and described, none of it a guess ("probably"); checked against the code,
  recordings and knock-outs (`original/docs/CODE.md`). Left: the shapes' geometry in the 6502 data beyond what `original/docs/TRACKS.md` reads.
* **The benchmark's car does not drive**: its race holds fire only, and fire is the boost - up is
  the accelerator (`RaceInput`) - so the player's car stays on the start (the opponent drives, the
  view and the drawing are what is measured). A race with up held (and some steering) would
  measure the physics and the track ahead as in play; its figures would need a new baseline.
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
* ~~First work out the track format~~: done (`original/docs/TRACKS.md`, `original/tools/tracks.py`,
  checked against the game by `tools/test_tracks.py`). Per track: the track's bytes only - the
  shapes' geometry and the height profiles are shared by all 8 (`Data6502`, `HeightProfiles`); the
  draw bridge's moving part (`UpdateDrawBridge`) and the opponent's limits (`OpponentSpeedLimits`) are kept
  per track in the game's tables.
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

## The view drawn another way (for later)

Options for replacing the race view's renderer, looked at in November 2026 (the time then: about
36% of the work rasterising - edges 12%, spans 13%, lines 7%, polygons 4% - and 15% projecting).
None keeps the picture pixel for pixel as the release's except the second.

* **The blitter's polygons** (the demos' filled vectors): each polygon's outline drawn by the
  blitter's line mode into a buffer, filled by its fill mode, and put on the 4 planes in its
  colour; the CPU only sets up each edge (about 150-200 cycles, against about 1,000 now with the
  clipping) and projects the next rows while the blitter fills. The blitter's time about the
  drawing's now (25-30 ms a frame), but beside the CPU. Costs: the blitter shares the bus on an
  A500; a polygon costs its bounding box (slanted quads waste a lot); the painter's order keeps
  the blits in sequence; the fill rules differ from `ScanEdge`'s. Perhaps 15-25%. The biggest
  change - to try first on the mountains (6 flat polygons a frame) to measure it.
* **Front to back with a span buffer**: the near rows first, each screen line keeping the spans
  already covered; further rows fill only the gaps, the sky and ground what is left. No overdraw
  (a word is written 1.87 times now), and far rows behind a crest skipped. Perhaps 5-10%, most on
  hills (the worst frames). The CPU's renderer kept; the picture can stay the same. A cheaper
  form: a "floating horizon" (the highest line drawn so far in each column).
* **The whole view filled at once by the blitter**: the edges between colours drawn as XOR lines
  and each plane filled in one pass (about 4.6 ms for the view). Only for polygons that do not
  overlap: it needs the visible regions first (as the span buffer finds them).
* **A chunky buffer and chunky-to-planar**: not on a 68000 (the conversion alone about a frame,
  and flat polygons gain nothing); perhaps on an A1200.

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
  about 75,000 cycles a frame (10% of the work). Measured since (the benchmark against F10, by
  routine): about 6 small mountains in view, each the same 4-point shape (a quadrilateral 3-7
  lines high on the horizon, 2 triangles' worth of edges): 24 `ScanEdge` calls and 6
  `FillPolygon`s a frame. The edges about 29,000 cycles: half in the view (`ScanEdgeInView`,
  about 500 each with the stepping), a third crossing a side and a sixth wholly off one (the
  clipping path: about 2,200 each - 26,000 of the 29,000); the fill about 25,000 (about 40 lines
  at 525 cycles: the partial words at both ends, 4 planes); `DrawMountains`' own loops 13,000; the
  roll 5,000. No mountain is wholly outside the view (so nothing to cull: the angle window is only
  a little wider than the view), and the cost is spread rather than in one place. Exact savings
  ~~done~~ (`src/scanside.i`, `DrawMountains`): edges clipped only at the view's sides (about 15 a
  frame, the track's included) skip the bit-by-bit outcodes and the four y tests, and join the
  release's clipping where it deals with the sides - about 140 cycles an edge (the estimate of 500
  counted `ScanEdge`'s entry, which every edge needs); the level case of the roll done inline for
  the mountains' 24 points. Together 0.5% of the work (101.2 to 100.75 ms), not the 1.2% estimated.
  Checked edge by edge by `tools/test_scanside.py`, and frame by frame against the build before.
  A larger cut would not be exact:
  the mountains' spans kept per shape and phase (their x is the shape's x + the heading, rounded
  by the projection's `asr #2`, so 4 phases a direction) and redrawn shifted, or drawn every other
  frame.
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
  right after the view (`PrintOpponentDistance`'s text, `UpdateRaceTime`'s times, cut-outs drawn on both screens)
  and the blits are per plane (the screen's planes are not interleaved), so a queue would mean an
  interrupt for each of about 28 blits and waits before each of those writes: about 1% at best.
* `ArcTan`, `RollPointXY`: ~~the car level (no roll) without `RollPointXY`'s 4 `muls`~~ (done:
  its result worked out from the point, exactly - half its time when the car is level; the
  benchmark's telemetry race happens to be rolled nearly throughout, the normal build's level).
  `ArcTan`'s `divu` (half its time) has no exact cheaper form short of a large table.
* ~~`FillBetweenEdges`: its runs unrolled~~: done - the whole words of a run written two at a
  time (`move.l`) from an unrolled sequence jumped into (54 cycles for 16 pixels before, 30 now;
  runs average 11 words), drawing 1.7% less. ~~The partial words without the
  `jsr`/`ColourWordJump`~~: done - `PlotWord<colour>` called at once (`jsr (a5)`, a5 its
  address), the edge masks worked out (`$FFFF >> (x & 15)`) instead of read through a5 from
  `dat_667E0`; the line's end tested from the line count (`subq`/`bgt`) instead of comparing a6
  with `ScreenDrawTop`; the same in `FillPolygon` (the mountains, the cars), whose whole words are
  now written as `FillBetweenEdges`' (two a plane at once, unrolled). The race's work 1.3% less,
  the screens the same frame for frame. Still to do: its variables in registers (`FillLines`,
  `dat_69ACE` and the edge list's bounds read from memory each line: no register is free in the
  loop as it is).
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
* `ArcTan`, `RollPointXY`: tables - looked at: the projection does not divide (the 6502's tables
  already), so reciprocal tables would save nothing; the only divide that counts is `ArcTan`'s
  `divu` (about 3% of the work), whose exact result (11 bits of the ratio) has no cheaper form.
* ~~**A shorter draw distance**~~: done (**F4**: `ProjectFarPieces` stops after `FAR_SHORT_ROWS`
  (6) of the far pieces' cross-sections, 12 on a straight) - the race's work 15% less (107 ms to
  91 ms a frame; 76 ms with F9 and F10 too). The cut is near the horizon, a few lines high; the
  opponent's car beyond it is not drawn. The race itself is unchanged (checked: the same state
  at the same frame).
* The 6502's leftovers: byte variables at absolute addresses, instructions that do nothing.
* **The physics and the race loop** (measured November 2026, a call profile of the benchmark's
  race; the work then 107 ms a frame, about 760,000 cycles). The physics is about 6% of it:
  `CarPhysics` 29,900 cycles a step (`BuildViewMatrix` 5,800, the track under the wheels
  `TrackUnderWheels` 8,600, `WheelsOnTrack` 3,800, the forces through `MatrixTimes` about 20 calls),
  `PlaceOpponentOnTrack` 10,800 (in the view), `MoveOpponent` 6,100 (the opponent follows the track,
  it is not simulated). Each step the car is a rigid body on four wheels: its matrix from its
  angles (`Sin`/`Cos`: a 512-entry table, interpolated), the track's height under each wheel from
  its piece's points, the wheels on, above or below the track, the forces turned between the
  car's frame and the world's, then an Euler step (velocity x 238/256 added to the place, the
  turn rates to the angles). All exact, so the cars drive as before:
  * the pieces' loads cached: `LoadPiece` about 7 times a step (about 930 cycles each; it copies
    some 20 values of the piece into variables that other code changes between the calls, so an
    exact cache must check them all - perhaps 0.4%),
    `ReadPiecePoints` 8 times in `PlaceOpponentOnTrack` - mostly the piece of the step before: ~0.5%;
  * the physics' variables from a base register (`d16(An)`) instead of absolute longs (4 cycles
    an access, hundreds of accesses a step): ~0.7%;
  * `Sin`/`Cos` tighter (about 270 cycles a call, ~10 a step; an exact full table would take
    32K): ~0.2%;
  * `MatrixTimes` inlined (20 calls a step): ~0.2%.
  Together about 1.5%. A cheaper integrator or fewer samples of the track would change the
  handling: not recommended.
* ~~**The opponent's distance on the instruments**~~ (`PrintOpponentDistance`): done (`src/readout.i`) -
  printed every 4th step a row of pixels at a time into both screens, about 11,400 cycles a
  character, 63,000 on those steps. Now a character the cells already show is not drawn again
  (the cursor moved on as printing it would): on average 2.1 of the 5 change, so 15,800 cycles a
  frame became 8,100 (the steps that print: about 32,000). Kept only while nothing else has drawn
  there (the race's start, other text on those lines, a cut-out over them) and the text's colours
  and way of drawing are the same. Checked by `tools/test_readout.py` (in the workflow): each
  character left as it is printed anyway in four kinds of race - no byte of the screens changes.
  ~~The rest of the hitch: `PrintCharNow` itself~~: done (`src/textfast.i`) - its 8 rows drawn
  by `TextRows`: the cell's mask shifted once, each row's glyph once, then each plane's 8 rows
  as longs (both words), unrolled, each `(old and not U) or V` with V chosen by the plane's
  colours. About 5,500 cycles a character instead of 11,400: all the game's text twice as fast
  (the readout 5,200 cycles a frame, its steps about 20,000). The same bytes and the same
  registers left as the release's loop, checked character by character by
  `tools/test_text.py` (in the workflow: the menus and races, every way of drawing text).
* ~~The benchmark's race moved with the menus' speed~~: done (`tools/bench.py`) - the keys were
  pressed at set times, and Random's state for the race (`SaveRandomSeed` keeps it after the title,
  `RestoreRandomSeed` puts it back as the race is set up) depends on how long the menus took: the
  menus call `Random` as they wait (`ReadControls`). So faster text started another race (the
  opponent placed elsewhere). Now the script waits for the race's start (`Race`, scremu's `until`,
  the next frame from its start: the line's overrun cleared), sets that saved state to a fixed value
  (`RACE_SEED`) and presses the track's keys a set time after it; the slow-text and fast-text builds
  then run the same race (the geometry within 0.01 ms; the cockpit 0.53 ms and the instruments 0.33 ms
  less: the text). Left as it is: the race still depends on the race's own speed - the engine's revs
  (`EngineRevs`) move each vertical blank, and whether `UpdateEngineRevs` calls `Random` depends on
  them, so a frame taking 7 vertical blanks instead of 6 moves the opponent a little (the game's own
  behaviour). The baselines regenerated: the released game (the telemetry build of 21b21ba with the
  release's helper, `original/bin/lowmem_c0.bin`) 6.61 vertical blanks of work, 7.55 frames a second.
* ~~**The vertical blank's work**~~ (`VBlankTick`): looked at, little to win - about 1,800 cycles
  a vertical blank (10,700 a frame): saving and restoring all the registers, the engine sound's
  period (a `divu`), the timers. The wheels' sprites are not rebuilt there, only pointed at their
  cut-outs (`SpriteFromCutout`: about 120 cycles each, 2 a blank).
* ~~Then the frame rate~~: done (`src/interp.i`, F8 for the release's timing) - the physics at a
  step every 6 vertical blanks to the clock (the game's speed constant, late steps caught up), and
  the view drawn between steps with the cars' places and angles blended: one step's latency,
  traded for smooth motion, when 2 or more pictures fit in a step; the latest step, as before,
  when not (the A500). Still to do: try it on an A1200 and an accelerated A500 (the emulator's
  cpumult is only the CPU); the instruments are still printed once a step; extrapolation instead
  of the step's latency (riskier: crashes); a shorter step for the physics (the game's tuning
  assumes 6 vertical blanks).