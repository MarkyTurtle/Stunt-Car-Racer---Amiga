# Memory

The game is a single load: the loader reads all of it ($325 sectors, 412,160 bytes) to `$E700` and
it never reads the boot disk again. On a 512K Amiga (chip RAM `$00000-$7FFFF`, 524,288 bytes) it
uses:

| Address | Bytes | What |
|---|---:|---|
| `$00000-$000FF` | 256 | exception vectors; the release's helper block at `$C0` |
| `$00400-` | | the save-disk routine's MFM buffer (`SectorLoader`, a1 = `$400`) |
| `-$03D7F` | | the supervisor stack (SSP = `$3D80`) |
| `$03D80-$0E6FF` | 43,392 | no use found yet (no absolute references; not yet checked by running the game) |
| `$0E700-$730FF` | 412,160 | **the game as loaded** (below) |
| `$73100-$79F93` | 28,308 | the rest of the second screen (it starts at `$72294`, inside the image) |
| `$7A01A-$7B6FF` | about 5,900 | work areas outside the image (`$7A21A` the save-slot names, `$7A61A`, `$7A91A`, ...) |
| `-$7FFFF` | | the user stack (USP = `$7FFFC`) |

So the game takes about 430K of the 512K, and nearly all of chip RAM is spoken for.

## The 412,160 bytes loaded

| | Bytes | Share | |
|---|---:|---:|---|
| code | 73,728 | 18% | traced instructions (`scr_game.s`) |
| pictures | 224,854 | 55% | 9 full-screen pictures (`gfx/`, [DATA.md](DATA.md)) |
| sound | 49,810 | 12% | 8 samples (46,482), the engine buffer (3,200, zero on disk), the table |
| screens | 35,692 | 9% | the first screen and the start of the second: memory the game draws over |
| tracks | 1,248 | 0.3% | the 8 tracks (`tracks/`) |
| the rest | 26,828 | 7% | variables, tables (maths, models, text), leftovers (the 6502 bytes, `CopylockRoutine`) |

The pictures, by when they are on screen:

| Pictures | Bytes | When |
|---|---:|---|
| cockpit | 14,990 | every race |
| title, stadium (track preview), divisions, Hall of Fame | 105,222 | the menus between races |
| wreck, season_win, season_crowd, champion | 104,383 | the screens shown between races and at the end of a season |

About 210K of the load - half of it - is pictures that are only on screen between races, and
every one of them is in memory all the time. The tracks themselves are small (1,248 bytes for
all 8).
