# The 3D view and the drawing

How the game draws the race, what each part costs, and where the time could be won. Everything
here was measured with the telemetry build and the study emulator: the race benchmark
(`enhanced/tools/bench.py`: Division 4's first race, Little Ramp, against Jumpin' Jack, a minute
of it with the throttle held) timed by phase (`enhanced/src/telemetry.i`), and the same race
profiled by routine (scremu's `profile` and `callprof`). The emulator counts each instruction's
68000 cycles at 7.09 MHz; it does not slow the CPU for the chip memory it shares with the display,
which with 4 low-resolution bitplanes costs the 68000 little - so these are close to an A500's
figures, and exact for comparing one version of the game with another.

## What limits the frame rate

`FrameLimiter` lets a race frame start at most every 6 vertical blanks (8.33 a second). On an A500
the work of a frame takes longer than that: **6.47 vertical blanks on average (129.6 ms)**, so the
race runs at **7.7 frames a second** and `FrameLimiter` almost never waits (0.1 ms a frame). Of 568
frames, 405 took 6 vertical blanks, 104 took 7, 58 took 8 and 1 took 9 - the longer ones when the
opponent's car is in view (its drawing adds up to 300 lines) and every 4th frame, when the
instruments' digits are printed (130 lines).

So the release's turbo (F3, which removes the wait) does nothing on an A500: the drawing is the
limit. Faster drawing gives the frames back up to the limit of 6; beyond that, the limit must
change - and the game is simulated **a step a frame**: `CarPhysics` and the opponent run once a
frame and nothing in the race measures the time a frame took. A frame rate above 8.33 needs either
a smaller limit with the physics stepped as before every 6 vertical blanks (and the view drawn more
often than the physics, the cars' positions in between interpolated), or the physics changed for
a shorter step.

## A frame, by phase

| Phase | ms | Share | What |
|---|---:|---:|---|
| input | 4.7 | 3.4% | the controls, `CarPhysics`, the engine's sound |
| cars | 3.1 | 2.2% | the cars placed on their pieces, the opponent |
| geometry | 40.3 | 29.4% | the pieces in view: points rotated and projected, the edges clipped and stepped |
| drawing | 63.9 | 46.6% | the sky and ground, the mountains, the track's surfaces and lines, the opponent's car |
| cockpit | 22.6 | 16.5% | the cockpit's parts drawn over the view (`DrawCutout`), the chains |
| rest | 2.4 | 1.8% | the drawbridge, the instruments |
| wait | 0.1 | 0.1% | `FrameLimiter` |

## The pipeline

`RaceView` (called by the race loop once a frame) does it all; the CPU draws every pixel (the
blitter is not used in the race).

1. **The cars.** Each car placed on its piece of track (`PlaceCarOnTrack`, `MoveOpponent`).
2. **The near pieces.** The piece the car is on and the next two: their points read
   (`ReadPiecePoints`: heights from the piece's shape, `PiecePointHeight`, `InterpolatePiece`),
   turned by the view's matrix (`RollPoint`, `RollPointXY`) and projected (`ProjectPointX`: an
   `ArcTan` of the point's x and z less the car's heading; `ProjectPointY`) into `PointScreenX` and
   `PointScreenY` - `ProjectNearPiece`, 3 times a frame.
3. **The far pieces.** Each piece has a list of the pieces seen from it (`$7AA1A`: a pointer a
   piece); those are projected the same way with less precision (`ProjectFarPieces`,
   `ProjectPointXFar`, `ProjectPointYFar`).
4. **The edges.** Each edge between two projected points is clipped to the view (256 x 128 pixels:
   outcodes) and stepped a line at a time (`ScanEdge`); its x on each line goes into an **edge
   buffer** (a word a line, from `EdgeBufferNext`: in the race work area, `$3D80` up to `$60A8`).
   The track is a strip, cut into cross-sections: each cross-section is a **row** of the row table
   at `$7B08A` (32 bytes a row: 7 edge pointers, flags at `+$1C` and `+$1E`; `RowOffset` the
   current one; up to `$5E0`, the opponent's car's rows after). `EdgesFirstPiece`,
   `EdgesNextPiece` and `EdgesFarPieces` build the rows. An edge wholly off one side becomes the
   view's side (`EdgeOffSide`), so that the fill still closes.
5. **The background.** `DrawHorizon` fills the whole view with sky above and ground below the
   horizon (the horizon is an edge too: it tilts with the car's roll); `DrawMountains` draws the
   mountains as polygons (`ScanEdge`, `FillPolygon`).
6. **The track, far to near** (the painter's order). `DrawFarRows`, then `DrawNearRows`: for each
   row, the surfaces between it and the next (`FillRowSurface` gathers their edges,
   `FillBetweenEdges` fills them a line at a time), the lines along the track (`DrawEdgeLine`: an
   edge buffer drawn as single pixels with `PlotPixel`), and the opponent's car when the row is its
   row (`DrawCarAtRow`, `DrawOpponentCar`: its model's edges in rows from `$5E0`, filled with
   `FillPolygon`; only when its distance, `OpponentDistance`, is 10-3199).
7. **The cockpit.** The parts of the car in front of the driver drawn over the view
   (`DrawCutout`: the 52 cut-outs `MakeCutouts` masked from the pictures at start-up, 7 drawn a
   frame), the chains (`MoveChains`).
8. **The instruments, then `FrameLimiter`**: the screens swapped (`ScreenDraw`, `ScreenBack`;
   the copper interrupt shows the new one at line `$FA`).

### The screen

Two screens of 32,000 bytes (`$7D00` apart), each 4 bitplanes of 320 x 200 one after the other
(8,000 bytes, `$1F40`, a plane; 40 bytes a line). The view is 256 x 128 pixels at `ScreenDrawTop`.
A pixel's colour is written to the 4 planes separately, so every fill writes 4 words for each 16
pixels.

### Colours by changing the code

The drawing routines are given a colour by rewriting themselves: `SetPolygonColour` turns each of
`PlotPixel`'s `bset` instructions (`PlotPixelP0Hi` ... `PlotPixelP3Lo`) into `bclr` or back, one per
plane; the fills patch the displacement of `ColourWordJump`'s branch so that it goes to
`PlotWord<colour>` (15 routines, one per colour, each or-ing the planes of its colour and clearing
the others).

## The cost, by routine

The routines that take the most of a race frame (average CPU cycles a frame; a vertical blank is
142,102):

| Routine | Cycles | Share | |
|---|---:|---:|---|
| `ScanEdge` | 137,900 | 15.6% | steps every pixel of an edge's length when it is wider than tall - the track's cross-section edges run across the view |
| `FillBetweenEdges` | 97,800 | 11.1% | each line of a surface; the variables it keeps are in memory (`move.w (abs).l` each line) |
| `DrawCutout` | 86,100 | 9.8% | the cockpit: a read, mask, or and write for each word of 4 planes |
| `DrawHorizon` | 56,200 | 6.4% | 16K of the screen written each frame by the CPU |
| `PlotPixel`, `DrawEdgeLine` | 85,500 | 9.7% | 365 pixels a frame, each a `jsr` and 4 `bset`s |
| `RollPointXY`, `ArcTan` | 64,300 | 7.3% | the projection's maths |
| `FillPolygon` | 30,100 | 3.4% | the mountains, the opponent's car |
| `PrintCharNow` | 18,300 | 2.1% | the instruments' digits |

By what they are part of (the routine and all it calls): `DrawNearRows` 23.0%, `DrawMountains`
10.4%, `ProjectNearPiece` 9.5%, `DrawCutout` 9.3%, `DrawHorizon` 7.9%, `DrawFarRows` 7.6%,
`EdgesFarPieces` 7.1%, `ProjectFarPieces` 6.7%, `EdgesNextPiece` 4.2%, `CarPhysics` 3.3%.

## A 6502 game, translated

The game was written for 6502 machines first, and the Amiga's code is that program translated to
the 68000 almost instruction for instruction: its data is still laid out as the 6502 had it
(`Data6502`: 6502 address `$B100` is there, and the tracks' pointers are 6502 addresses, byte-swapped)
and the 6502's leftovers are everywhere in the code:

* variables are bytes in memory, each reached with a 32-bit absolute address (`move.b
  (dat_1BB0E).l,d0`: 16 cycles where a register would take 4, or `(d16,An)` 12);
* values are moved through memory between routines instead of registers (the 6502 had 3);
* instructions that do nothing are kept from the 6502's carry handling (`move.b d2,d2` then
  `addi.b #$0,d2`: a `CLC`, `ADC #0`);
* 16-bit maths is done in bytes in places.

## Where the time could be won

Rough estimates, in cycles a frame (of about 880,000); each to be confirmed with the benchmark.

1. **`ScanEdge` stepping a line, not a pixel** - an edge wider than tall needs one x a line; a
   fixed-point step (x += dx/dy each line, one `divs` per edge) costs about 20 cycles a line
   instead of about 20 a pixel. Perhaps 80,000-100,000.
2. **The blitter for the background** - `DrawHorizon`'s 16K is 2 fills (sky, ground) and the
   horizon's lines: the blitter fills while the CPU projects the next points. Perhaps 50,000.
3. **The blitter for the cockpit** - `DrawCutout`'s masked copies are the blitter's cookie-cut
   (A the mask, B the cut-out, C the screen, D the screen), again in parallel with the CPU.
   Perhaps 60,000-80,000.
4. **`FillBetweenEdges`** - its variables in registers, the whole-word run unrolled (4
   `move.w` a word now, with the loop's `dbra`). Perhaps 30,000-40,000. (Or: the blitter's fill
   mode, with the edges drawn in a buffer by its line mode.)
5. **`PlotPixel`** - the 365 calls a frame made inline, a word mask instead of 4 `bset`s.
   Perhaps 30,000.
6. **The maths** - `ArcTan` and `RollPointXY` from tables, in words. Perhaps 20,000-30,000.
7. **Everywhere** - the variables most used in registers or `(d16,An)` from one base register,
   the 6502's leftovers removed.

Together, perhaps a third of the frame: from about 6.5 vertical blanks to about 4.5 - every frame
inside the limit of 6 on an A500, and with the physics decoupled (above), 10-11 frames a second.

## Changing the code safely

The source can now be changed and its code moved: everything that held an address as a number
was given a label - the patched instructions above (`PlotPixelP0Hi`..., `ColourWordJump`), the
tables of pointers (`PictureTable`, `KeysPlainPtr`, `KeysShiftedPtr`, `dat_699B8`, `dat_69A80`),
the 6502 data's base (`Data6502`), and an address the game worked out from two constants
(`dat_64AEC+dat_14874`). `enhanced/tools/reloc_test.py` checks it: the game assembled with 16
bytes put in before its code plays the benchmark's race exactly as before (every routine called
the same number of times). The game's load ends with its screens, and the work areas start 135
bytes after them: code can grow by that much before the screens are moved.
