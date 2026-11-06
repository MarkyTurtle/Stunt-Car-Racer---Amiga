# The tracks' format

The 8 tracks are in `tracks/*.bin`. `BuildTrack` (`$5AE46`) reads one each time a track is shown or
raced (from `TrackPreview`), and turns it into the track's tables. This page describes those bytes
as `BuildTrack` reads them.

[`tools/tracks.py`](../tools/tracks.py) reads them the same way and prints each track.
`enhanced/tools/test_tracks.py` checks that reading against the game: in scremu it has the original
game build each of the 8 tracks, then compares every table `BuildTrack` writes with `tracks.py`'s.
All 8 tracks are the same, byte for byte. `tracks.py --map` draws the tracks on their grids:

![The 8 tracks on their 16 x 16 grids](tracks.png)

Each square is a piece. Its colour is the piece's height, from blue (low) to orange (high), and
darker squares are bends and joins. The red outline marks the start and finish piece.

## The grid and the pieces

A track is a closed loop of pieces (40-78 of them) on a 16 x 16 grid, one piece per square. A
square is a byte: y x 16 + x (`TrackPieceGrid`; `BuildTrackGrid` fills `TrackGrid`, the piece in
each square). Each piece has:

* a **shape**, the piece's form in plan view (straight, diagonal, a half of a bend). Each shape has its
  own geometry in the 6502 data (`Data6502`, by shape): its cross-sections' points and how many
  sections it has;
* a **direction**: which way it runs on the grid;
* two **height profiles**, one for each side of the track. Side A is the cross-sections' even
  points and side B their odd points (`PiecePointHeight`). A profile is a height for each section's
  end. When the two profiles are the same the track is level across; when they differ it is banked.

The pieces join up: each side's heights carry on from the previous piece. A piece's base height
(`PieceHeightBaseA`, `PieceHeightBaseB`) is the height where the previous piece ended, less its
profile's first entry. From there the height so far is the base plus the profile's last entry.
The track starts at the height in its header.

## The bytes

| Bytes | What | Into |
|---|---|---|
| 1 | the number of pieces | `TrackPieceCount` |
| 1 | the piece the cars start on | `StartingPiece` (the opponent is put there: `Race`) |
| 1 | the piece before the one the laps count from | `LapCountPiece` (`LapStartPiece` = it + 1, or 0 past the last piece) |
| 1 | the start and finish piece | `StartPiece` (`CheckLapPiece`) |
| 2 | the height the track starts at: the low byte first | both sides' heights so far |
| ... | the pieces (below) | |
| 1, 1 | the opponent's setting, in the leagues and in the super league | `OpponentSetting`, `OpponentSettingSuper` (`SetOpponentSkill`: into `dat_63CE2`, which the physics compares against) |
| 1, 1 | the boost at the start, in the leagues and in the super league | `BoostAtStart`, `BoostAtStartSuper` (`Race`: a count, made decimal) |
| 1 | n: the lines for the opponent the track sets | `OpponentLineCount` |
| 1 | m: the pieces the car is not put back on | `NoRestartCount` |
| 2 n | n pairs: a piece and its line | `OpponentLinePieces`, `OpponentLineValues` |
| m | m pieces | `NoRestartPieces` (`PlaceCarOnPiece` skips them when the car is put back after leaving the track: probably the jumps' gaps) |

### A piece

| Bytes | What |
|---|---|
| 1 | its flags (below) |
| 1 | its grid square |
| 1 | its profile A |
| 1 | its profile B (left out when flags bit 5 is set: B is A) |

The flags byte:

| Bits | |
|---|---|
| 0-3 | the shape (0-14) |
| 4 | reversed: the shape is driven the other way (`PieceReversed`) |
| 5 | one profile byte: both sides the same |
| 6-7 | the direction on the grid: `$00` y + 1, `$40` x + 1, `$80` y - 1, `$C0` x - 1 |

**Repeats.** A flags byte whose low 4 bits are `$F` is not a piece. Its high 4 bits n say that
the next n pieces repeat the previous piece's flags. Those pieces have no flags or square bytes of
their own: each square is the previous one stepped in the flags' direction (`StepGrid`). A reversed
piece steps the other way, because bits 6-7 are flipped first. Their profile bytes still follow, one
or two each. For example, a straight run of 10 pieces takes a piece (4 bytes or 3), the repeat byte
`$9F` and 9 profile bytes.

**Profiles.** A profile byte's bits 0-6 index `HeightProfiles`, a table of 6502 pointers into the
6502 data. The entries of the profile it points to come in one of two forms, chosen by bit 7 of
profile **A** (it decides the form for both of the piece's profiles):

* bit 7 clear: a byte each, height = (b & `$0F`) x 256 + (b x 2 & `$E0`);
* bit 7 set: two bytes each, height = (b0 & `$7F`) x 256 + b1.

Bit 7 of profile B in the file is not used. `BuildTrack` replaces it with a running parity, which
`LoadPiece` passes on (`dat_1BBDC`). It flips with each piece by the number of the piece's points,
probably so that the track's stripes carry on from piece to piece.

**Shapes 12-14** take their profiles not from the file but from the bytes at `l_5B2B8` + 12 on: 3,
4, 4, 3, then the first bytes of the next routine. This is a table the 6502 version kept there. No
track uses these shapes.

### The shapes

What each shape does is read from the tracks, where they are used and how the grid steps around
them.

| Shape | Sections | Pieces using it | What (from the tracks) | Its turn (`ShapeTurns`) |
|---:|---:|---:|---|---|
| 0 | 8 | 316 | straight, along x or y | `$00` |
| 10 | 11 | 33 | straight, diagonal (the squares step in x and y) | `$40` |
| 6 | 9 | 36 | a half of a bend (a 90-degree corner is a 6 and a 7 on diagonal squares) | `$80` |
| 7 | 9 | 36 | the other half of a bend | `$C0` |
| 4 | 13 | 12 | from straight to diagonal (probably) | `$40` |
| 3 | 8 | 4 | from diagonal to straight (probably) | `$C0` |
| 1 | 8 | 8 | another join between straight and diagonal (probably) | `$80` |

Shapes 2, 5, 8, 9 and 11 are not used: their pointers in `Data6502` lead to code and other data.

## What `BuildTrack` works out

* `PieceDistances`: each piece's distance from the first, at 32 for each section. `TrackLength` is
  the whole track's.
* `PieceHeightBaseA` and `PieceHeightBaseB`: the base heights (above).
* `PieceOpponentLines`: each piece's line for the opponent. This is worked out from the last piece
  back to the first:
  * a piece the track sets takes the track's line. Its bit 7 marks the 3 pieces before it too, with
    bit 7 of their lines;
  * a bend (bit 7 of `ShapeTurns`) takes `dat_63CE1`, which `SetOpponentSkill` picks at random for
    the track within limits from `dat_1FE2C`. The line carried on is set 10 below it;
  * any other piece takes the line carried on plus 10, up to `$7F`.

## The 8 tracks

| Track | Pieces | Sections | The cars start on | Laps from | Start/finish | Starting height | Highest | Boost |
|---|---:|---:|---:|---:|---:|---|---|---|
| Little Ramp | 44 | 398 | 15 | 16 | 37 | `$0500` | `$1D40` | 34 (47) |
| Stepping Stones | 56 | 456 | 42 | 43 | 14 | `$0F00` | `$2DA0` | 48 (52) |
| Hump Back | 53 | 442 | 46 | 47 | 19 | `$0540` | `$1F80` | 41 (49) |
| Big Ramp | 44 | 398 | 1 | 2 | 24 | `$0780` | `$21A0` | 43 (41) |
| Ski Jump | 40 | 379 | 15 | 16 | 35 | `$6A40` | `$6CA0` | 43 (40) |
| Draw Bridge | 78 | 640 | 42 | 43 | 4 | `$11A0` | `$4BE0` | 72 (72) |
| High Jump | 52 | 438 | 29 | 30 | 4 | `$0640` | `$15C0` | 44 (42) |
| Roller Coaster | 78 | 640 | 0 | 1 | 37 | `$0500` | `$73A0` | 80 (89) |

The boost is the leagues' figure, with the super league's in brackets.

Still to work out: the shapes' geometry in the 6502 data (their points across and along), what
the opponent's setting does in the physics, and the draw bridge's moving part (`UpdateDrawBridge`,
`dat_1C6B8`, `dat_1C986`).
