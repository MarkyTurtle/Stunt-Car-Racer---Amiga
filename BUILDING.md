# Building

* **`original/`**: the source disk's files, extracted and checked.
* **`enhanced/`**: the game on an ordinary AmigaDOS disk. Building it makes a playable disk
  image (ADF).

## What you need

| Tool | Needed for | Notes |
|---|---|---|
| [vasm](http://sun.hasenbraten.de/vasm/) (`vasmm68k_mot`), the 68000 assembler with Motorola syntax | the enhanced disk | Build it from its source (`make CPU=m68k SYNTAX=mot`; a mirror: `git clone https://github.com/StarWolf3000/vasm-mirror.git`). Tested with vasm 2.0f. Put it on the PATH, or set `VASM` to its full path |
| [Python](https://www.python.org/) 3 | the tools, the disk builder, the tests | Tested with Python 3.13 |
| Python packages `unicorn`, `pillow` | see below | `pip install -r original/requirements.txt -r enhanced/requirements.txt` |
| An Amiga emulator and a Kickstart ROM | playing the disk | [WinUAE](https://www.winuae.net/), [FS-UAE](https://fs-uae.net/) or [Amiberry](https://github.com/BlitterStudio/amiberry) |

| Package | Used by |
|---|---|
| `unicorn` | `original/tools/disk/unpack_loader.py` (runs the loader's own decruncher), `enhanced/tools/test_boot.py` (boots the disk) |
| `pillow` | `original/render/loadpic.py` |

## The original files

The files are in the repository. To make them again from the Turbo release's ADF (and check them
against `original/disk/SHA1SUMS`):

```
python3 original/tools/disk/extract_files.py <Stunt Car Racer Turbo.adf>
```

## The AmigaDOS disk

```
python3 enhanced/tools/build_disk.py       # -> enhanced/build/scr.adf
python3 enhanced/tools/test_boot.py        # boots it in the emulator harness: every check "ok"
```
