# Stunt Car Racer - the original game

The game as it is on the source disk, the "Turbo" release (MicroStyle 1989; AGA fix and Turbo by
Galahad).

| | |
|---|---|
| [`disk/`](disk) | the files the boot chain reads, named by track, and the disk map ([`disk/FILES.md`](disk/FILES.md)); `disk/SHA1SUMS` |
| [`bin/`](bin) | what is made from them: the loader unpacked, the helper block, the loading picture as bitplanes |
| [`docs/BOOT.md`](docs/BOOT.md) | the boot chain step by step, the helper block at `$C0`, the game's own disk access |
| [`tools/disk/`](tools/disk) | `extract_files.py` (the ADF -> `disk/files/`, `bin/`, checked against `SHA1SUMS`), `unpack_loader.py` |
| [`render/`](render) | `loadpic.py`: the loading picture as a PNG (`render/out/`) |

Next: the disassembly of the game (`t010-083_game.bin` at `$E700`), as sources that reassemble
byte-identical.

```
python3 original/tools/disk/extract_files.py <Stunt Car Racer Turbo.adf>
python3 original/render/loadpic.py
```
