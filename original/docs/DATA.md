# The game's data

The sound, the pictures, the screens and the tracks are out of `scr_game.s`: each block is an
include file (`sound/sound.s`, `gfx/pictures.s`, `gfx/screens.s`, `tracks/tracks.s`) holding the
binary files (`incbin`) and the tables written with symbols. A label of the old source inside a
binary file is an equate on the file's label (`dat_20184 equ Pic_Cockpit+$2`), so the code is
unchanged and the game assembles byte-identical. `tools/split_data.py` made the split (and can
move more blocks: add them to its `BLOCKS`). `render/assets.py` turns the files into PNGs and WAVs
in `render/out/`.

## Sound (`sound/`)

The sound driver (`$F2xx`-`$F470`) plays 8 samples from its table at `SampleTable` (`$1B6CA`), 16
bytes an entry: pointer, length (bytes), period, volume, channel, a spare word. The start-up code
(`$EE64`) flips the sign bit of every sample byte: as stored they are unsigned 8-bit (a WAV's
format). Some of the table's bytes are written while the game runs (the equates `dat_1B6E2` ...).

| File | Address | Bytes | Period | Rate (PAL) | Volume | Channel |
|---|---|---:|---:|---:|---:|---:|
| `sample0.bin` | `$0F4B8` | 2,436 | `$96` | 23,646 Hz | `$1E` | 1 |
| `sample1.bin` | `$0FE3C` | 9,032 | `$B4` | 19,705 Hz | `$40` | 1 |
| `sample2.bin` | `$12184` | 8,014 | `$EE` | 14,903 Hz | `$38` | 1 |
| `sample3.bin` | `$140D2` | 3,108 | `$190` | 8,867 Hz | `$32` | 1 |
| `sample4.bin` | `$14CF6` | 5,170 | `$EE` | 14,903 Hz | `$40` | 2 |
| `sample5.bin` | `$16128` | 8,430 | `$118` | 12,667 Hz | `$40` | 3 |
| `sample6.bin` | `$18216` | 7,120 | `$1F4` | 7,094 Hz | `$40` | 1 |
| `sample7_engine.bin` | `$19DE6` | 3,172 | `$12C` | 11,823 Hz | `$30` | 0 |

The engine sample is also played at other pitches: at start-up `$F402` makes 6 copies of it, each
at half the rate of the one before (every other byte), into `EngineBuffer` (`$1AA4A`, `$C80`
bytes, zero on the disk) and a table of them at `$F474`.

Which effect each of samples 0-6 is (crash, landing, scrape, ...) is still to be found: listen to
`render/out/sound/`.

## Pictures (`gfx/`)

A picture is a record: a flag word (bit 15: packed), 16 colours (`$0RGB`), then a 320x200 picture
in 4 planes:

* **packed** (flag `$8000`): ByteRun1 (as IFF), for each of the 200 lines each of the 4 planes in
  turn, 40 bytes each: a byte `n` below `$80` copies the next `n + 1` bytes, above `$80` repeats
  the next byte `257 - n` times, `$80` does nothing. Unpacked by `$593F8` (to planes `$1F40`
  apart) and `$59450`;
* **raw** (flag `$0000`): 32,000 bytes, the 4 planes interleaved by word (plane 0's word, plane
  1's, 2's, 3's, then the next 16 pixels). Copied to the screen by loops like `$588B4`.

Before each record are 32 bytes (33 before the last three, which are at odd addresses) left
from its picture file's header, always the same; nothing reads them. They are kept as `dc.b` in
`gfx/pictures.s`.

| File | Record | Kind | What | Used by |
|---|---|---|---|---|
| `cockpit.bin` | `$20182` | packed | the cockpit | `$1BACE`, `$69D24` |
| `title.bin` | `$23C30` | raw | the title and menu screen, with the font: the game takes its characters from this picture (`$591C6`: `dat_272C2`) | `$64570` |
| `stadium.bin` | `$2B972` | packed | the track preview frame | `$5D246` |
| `hall_of_fame.bin` | `$30BCE` | packed | the Hall of Fame | `$5FC4E` |
| `divisions.bin` | `$35A74` | raw | the divisions and their drivers | `$588A0` |
| `wreck.bin` | `$3D7B6` | packed | the wrecked car | the picture table (`$56FF8`), `$59352` |
| `season_win.bin` | `$4477C` | packed | the driver and the crowd | the picture table |
| `season_crowd.bin` | `$4AF3E` | packed | the car and the crowd | the picture table |
| `champion.bin` | `$50E4C` | packed | the champion with the cup | the picture table |

The picture table at `$56FF8` has 5 pointers, read by `$59352` (d0 = the picture's number):
`$78000` (the loading picture, still in memory from the loader), then wreck, season_win,
season_crowd, champion. The names of the last four are descriptions of the pictures; when each is
shown is still to be found.

## The screens (`gfx/screens_initial.bin`)

`$6A594` to the end of the file: the start-up code puts the two screens (4 planes, `$7D00` bytes
each) at `$6A594` and `$72294` (the pointers at `$6A584`/`$6A588`). The bytes are what was in that
memory when the game was written to the disk; the game draws over them.

## Tracks (`tracks/`)

The 8 tracks' data, read by the track builder (`$5AE46`, a byte at a time by `$5AE00`) when a race
is set up. The table at `$1F0A2` gives each track's start: a word, byte-swapped, minus `$B100`,
plus `$1EF82`. Each one's length is where the builder stops reading (found by running it in an
emulator for each track): each ends where the next begins.

| File | Address | Bytes |
|---|---|---:|
| `little_ramp.bin` | `$1F8E4` | 124 |
| `stepping_stones.bin` | `$1F960` | 145 |
| `hump_back.bin` | `$1F9F1` | 145 |
| `big_ramp.bin` | `$1FA82` | 142 |
| `ski_jump.bin` | `$1FB10` | 145 |
| `draw_bridge.bin` | `$1FBA1` | 213 |
| `high_jump.bin` | `$1FC76` | 142 |
| `roller_coaster.bin` | `$1FD04` | 192 |

Their format (the pieces, their heights and the tables the builder uses: `$1C4C0`, `$1C524`,
`$1C588`, `$1C5EC`, `$1F0C2`, ...) is still to be worked out. After the last track, up to `$1FE2C`,
are bytes left from another version of the game (6502 code).

## Still in the source

`$1BAF8`-`$20182` (the variables, the tables, text, the track tables), the maths tables at
`$1CC46` and `$1DC46` (`$1000` bytes each, read by `$64D66`), and the smaller tables among the code.
