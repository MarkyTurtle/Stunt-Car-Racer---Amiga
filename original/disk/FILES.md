# The files on the source disk

The disk has no filesystem: the bootblock reads the loader through trackdisk.device and the loader
reads the game by sector number (a sector = 512 bytes at offset sector x 512 in the ADF; a track =
11 sectors, 5,632 bytes). `files/` holds what the boot chain reads, named by track; `../bin/` what
is made from them; `SHA1SUMS` the checksums of both.
`python3 original/tools/disk/extract_files.py <Turbo.adf>` writes them all and checks them.

## The disk map

| Disk offset | Sectors | Tracks | What |
|---|---|---|---|
| `$00000-$003FF` | 0-1 | 0 | the bootblock |
| `$00400-$02BFF` | 2-21 | 0-1 | formatter fill (`DOS\0`, `DOS\1`, … repeated): unused |
| `$02C00-$0C3FF` | 22-97 | 2-8 | the loader ($9800 bytes read; `$331C` used, the rest zero) |
| `$0C400-$0DBFF` | 98-109 | 8-9 | formatter fill: unused |
| `$0DC00-$725FF` | 110-914 | 10-83 | the game (`$325` sectors) |
| `$72600-$DBFFF` | 915-1759 | 83-159 | empty |

## The files

| File | Bytes | Loaded to | Contents |
|---|---:|---|---|
| `files/t000_bootblock.bin` | 1,024 | boot buffer | the bootblock |
| `files/t002-008_loader_packed.bin` | 38,912 | `$40000` | the loader: its decruncher and the packed code |
| `files/t010-083_game.bin` | 412,160 | `$E700` | the game (its data ends at `$722D8`; the rest of the last sectors is zero) |
| `../bin/loader_4000.bin` | 42,186 | `$4000` | the loader unpacked (`tools/disk/unpack_loader.py`): the loading picture and the sector loader |
| `../bin/lowmem_c0.bin` | 158 | `$C0` | the helper block the bootblock copies from its `$25E` |
| `../bin/loadpic_78000.bin` | 32,000 | `$78000` | the loading picture as shown: 4 bitplanes of 320x200, `$1F40` bytes each, from the loader's interleaved copy at `$4D24`. `../render/out/loadpic.png` |
