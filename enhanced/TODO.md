# To do

What is left for the enhanced game, roughly in order. The memory these plans work with is in
[`../original/docs/MEMORY.md`](../original/docs/MEMORY.md): the game is a single load of 412,160
bytes at `$E700`; measured in the emulator, the game uses all but about 17K of a 512K Amiga's
chip RAM (the free part mostly `$015C-$3D79`, which the save routine borrows). The enhanced game
loads the five pictures read only while their own screen is up (124,485 bytes) from the disk when
they are shown: about 89K of chip memory is free now.

## Groundwork

* Try the disk in WinUAE: A500 512K, expanded A500, A1200.
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
  the enhanced game writes none of its instructions. It costs 2.3% of a frame until `PlotPixel` and
  the fill are rewritten. Then: try the disk on a 68020/68030 with the caches on (WinUAE A1200).
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
6.47 vertical blanks on an A500 (the limit is 6), 7.7 frames a second; geometry 31%, drawing 49%,
cockpit 12%. A word of the view is written 1.87 times a frame (overdraw: moderate - the time goes
on the work for each line and edge more than on pixels written twice). Measure each change with the benchmark (`tools/bench.py --compare
bench_baseline.json`, also run by the workflow) and, for real figures, the telemetry disk in WinUAE.

* `ScanEdge`: step a line at a time, not a pixel (15.6% of the frame).
* The blitter: the background (`DrawHorizon`, 6.4%) and the cockpit (`DrawCutout`, 9.8%) - in
  parallel with the CPU.
* `FillBetweenEdges` (11.1%): its variables in registers, its runs unrolled; or the blitter's fill.
* `PlotPixel` / `DrawEdgeLine` (9.7%): inline, word masks (and so the cost of removing the
  self-modifying code won back).
* The cockpit (11.7%): ~~F6 turns it off~~ (done: a frame then fits in 6 vertical blanks); the
  blitter's cookie-cut for its cut-outs; the cut-outs split to skip their transparent parts; the
  view's drawing stopped above the engine's solid lines (3,478 pixels of the view are under it).
* The ground under the track: `DrawHorizon` fills the whole view and the track's surfaces are
  filled over it - the track's area written twice. Fill the ground only between the track's
  edges, or draw the track's surfaces first and the ground in the gaps.
* **Half the vertical resolution, stretched by the copper.** Draw the view in 64 lines instead of
  128 and show each line twice: the copper list sets the bitplane modulos (BPL1MOD, BPL2MOD) to
  -40 on the first line of each pair (the same line again) and back to 0 on the second, from the
  view's first line to its last (a WAIT and 2 MOVEs a line: about 1.5K of copper list). Everything
  that works a line at a time halves: `DrawHorizon`, `FillBetweenEdges`, the edges' stepping
  (`ScanEdge`, once it steps a line at a time), `DrawEdgeLine`; the projection stays the same.
  Measured shares: drawing 49% and much of geometry's 31% - perhaps a quarter to a third of the
  frame. The thought: the faster the game moves, the less the doubled lines are seen. To work out:
  - the cockpit overlaps the view's bottom 21 lines and its corners at full resolution: stop the
    stretch above it (full-resolution lines for the bottom of the view - the track drawn at full
    resolution there, or the doubled lines continued and the cockpit drawn on them), or draw the
    cockpit's overlapping parts at half resolution too;
  - the projection's y scaled by half (`ProjectPointY`), the edge buffers a word a pair of lines,
    the view's 64 lines packed (40 bytes a line, as now, so that the copper's modulo trick works);
  - the horizon band, where the far rows stack, gains the most and looks the worst: compare;
  - a key to switch it (as F6 does the cockpit), to compare in play and measure with the telemetry.
* `ArcTan`, `RollPointXY` (7.3%): tables.
* The 6502's leftovers: byte variables at absolute addresses, instructions that do nothing.
* Then the frame rate: the game is simulated a step a frame, so a limit under 6 vertical blanks
  speeds the game up. Keep the physics at a step every 6 vertical blanks and draw more often (the
  cars' positions interpolated), or shorten the physics' step. The release's turbo (F3) removes the
  limit: it should become a choice of the limit instead.
