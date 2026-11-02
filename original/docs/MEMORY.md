# Memory

The game is a single load: the loader reads all of it ($325 sectors, 412,160 bytes) to `$E700` and
it never reads the boot disk again. This page is measured: the game run in `tools/scremu` with
every byte it touches recorded (the CPU's reads, writes and instructions, and DMA: the bitplanes,
the copper, the audio, the blitter) - `tools/scremu/run_usage.py`: the title, the name, a racing
season scripted, then 300,000 frames (about 1 h 40 min of play) of random joystick, which race,
crash, finish races and wander the menus. The screens shown only between races were measured by
calling their routines (`calli` in scremu). The start-up checksum, which reads the whole game once,
is left out.

## The 512K

| Address | Bytes | Used for | Measured |
|---|---:|---|---|
| `$00000-$000FF` | 256 | exception vectors; the release's helper block at `$C0` | |
| `$00100-$0015B` | 92 | | a few bytes read |
| `$0015C-$03D79` | 15,390 | **free** (the enhanced game's helper block reaches `$175`: its flags at `$170`): nothing touched in play. The supervisor stack ends at `$3D80` (it uses only a few bytes); the save routine's MFM buffer starts at `$400` (`SectorLoader`, a1 = `$400`: about `$400-$3700` while a game position is loaded or saved) | untouched |
| `$03D80-$0648F` | 10,000 | the race's work area: cleared at the start of each race (`$5D83A`); the 3D view's edge buffers (`$3D80-$60A8`, [RENDER.md](RENDER.md)) | read and written |
| `$06490-$0E297` | 32,264 | the cut-out graphics: 52 pieces of the pictures (the cockpit's parts, the chains, ...) masked by `MakeCutouts` at start-up; their addresses at `CutoutPointers` | written once, read |
| `$0E298-$0E729` | 1,170 | free (no use found) | untouched |
| `$0E700-$730FF` | 412,160 | **the game as loaded** (below) | |
| `$73100-$79F93` | 28,308 | the rest of the second screen (`$72294-$79F93`) | DMA, written |
| `$7A01A-$7B6F9` | 5,856 | work areas: cleared at start-up (`Main`); the save-slot names (`$7A21A`), the league sent over the link (`$7A41A`), the piece models (`$7AA1A`), the polygon list (`$7B08A`) | read and written |
| `$7B6FA-$7FFFF` | 18,694 | the user stack (from `$7FFFC`, grows down) and, until the game's first screen flip, the loading picture still on show at `$78000` | DMA at the start only |

The telemetry build (`enhanced/src/telemetry.i`) keeps its results at `$3800-$3C7F`, in the free
15K: above the save routine's MFM buffer, below the supervisor stack.

So of the 512K, about 17K is free while the game runs (most of it the 15K at `$015C-$3D79`, which
the save routine borrows for a moment), and the game itself is the rest.

## The 412,160 bytes loaded

| | Bytes | Share | |
|---|---:|---:|---|
| code | 73,728 | 18% | traced instructions (`scr_game.s`) |
| pictures | 224,854 | 55% | 9 full-screen pictures (`gfx/`, [DATA.md](DATA.md)) |
| sound | 49,810 | 12% | 8 samples (46,482), the engine buffer (3,200, zero on disk), the table |
| screens | 35,692 | 9% | the first screen and the start of the second: memory the game draws over |
| tracks | 1,248 | 0.3% | the 8 tracks (`tracks/`) |
| the rest | 26,828 | 7% | variables, tables (maths, models, text), leftovers (the 6502 bytes, `CopylockRoutine`) |

## When each picture is used

| Picture | Bytes | Read | Measured |
|---|---:|---|---|
| cockpit | 14,990 | at start-up (`UnpackCockpit`, `MakeCutouts`) and before each race | read in play |
| title | 32,034 | the menus' background and the font | read in play |
| stadium | 21,052 | the track preview before each race | read in play |
| divisions | 32,034 | between races in a season | read in play |
| hall_of_fame | 20,102 | the Hall of Fame only (`HallOfFame`) | read only by it |
| wreck, season_win, season_crowd, champion | 104,383 | the screens after a race and at the end of a season (`ShowTablePicture` 3, 1, 2, 4) | each read only by its screen |

Each of the last five is read only while its screen is put up: it is unpacked into the second
screen and not needed again. That is 124,485 bytes - 30% of the load - that could stay on the disk
until wanted. The menus' pictures (title, stadium, divisions: 85,120 bytes) are used often, and the
cockpit is needed for every race.

## Not used

* The blitter: the game draws everything with the CPU (the enhanced game blits the cockpit). Its only blits are the save routine's MFM
  encoding (`BlitMFMEncode`) when a game position is written.
* `CopylockRoutine` (`$5C984`, 1,318 bytes; the telemetry build's code goes there) and the 6502
  bytes after the tracks (`$1FDC4-$1FE2B`).

## The enhanced game

The enhanced game (`enhanced/`) loads the five pictures read only while their own screen is up
from its disk when they are shown (`enhanced/src/diskload.i`): its load is 123,808 bytes smaller,
and its screens - which follow the code - start at `$4E6E4` instead of `$6A594` (the addresses
below move as the code grows; these are the enhanced game's of November 2026).

| Address | Bytes | Used for |
|---|---:|---|
| `$00400-$032BF` | 11,968 | the byteloader's MFM buffer while a picture is loaded (and, as before, the save routine's) |
| `$0E700-$4E6E3` | 262,116 | the game: code, data, the pictures it keeps (cockpit, title, stadium, divisions) |
| `$4E6E4-$5E0E3` | 64,000 | the two screens |
| `$5E0E4-$65E05` | 32,034 | `DiskPicture`: the picture loaded from the disk |
| `$65E06-$6D9ED` | 31,720 | `BlitCutouts`: the 40 cut-outs `DrawCutout` blits, in the blitter's form (made at start-up: `enhanced/src/blitcutout.i`) |
| `$6D9EE-$77FFF` | 42,514 | **free** |
| `$78000-$7A019` | 8,218 | free once the loading picture is not needed |
