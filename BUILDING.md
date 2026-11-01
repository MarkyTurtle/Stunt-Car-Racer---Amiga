# Building

* **`original/`**: the original game. Its sources reassemble byte-identical to the source disk's
  files, and `build.py` rebuilds the disk itself.
* **`enhanced/`**: the game on an ordinary AmigaDOS disk. Building it makes a playable disk
  image (ADF).

The GitHub Actions run these steps on Windows and Linux (`.github/workflows/`; vasm is built by
`.github/actions/vasm`): if something here doesn't work for you, their runs are a working example.

## What you need

| Tool | Needed for | Notes |
|---|---|---|
| [vasm](http://sun.hasenbraten.de/vasm/) (`vasmm68k_mot`), the 68000 assembler with Motorola syntax | every build | Build it from its source: `git clone https://github.com/StarWolf3000/vasm-mirror.git vasm`, then `make CPU=m68k SYNTAX=mot` (Linux) or `nmake /f Makefile.Win32 CPU=m68k SYNTAX=mot` (Windows, in a Visual Studio x64 Native Tools prompt). Tested with vasm 2.0f. Put it on the PATH, or set `VASM` to its full path |
| [Python](https://www.python.org/) 3 | the builds, the tools, the tests | Tested with Python 3.11 and 3.13 |
| Python packages | the tools and tests (not the builds) | `pip install -r original/requirements.txt -r enhanced/requirements.txt` |
| An Amiga emulator and a Kickstart ROM | playing the disks | [WinUAE](https://www.winuae.net/), [FS-UAE](https://fs-uae.net/) or [Amiberry](https://github.com/BlitterStudio/amiberry) |

| Package | Used by |
|---|---|
| `capstone` | `original/tools/disasm/make.py` (the disassembler) |
| `unicorn` | `original/tools/disk/unpack_loader.py` (runs the loader's own decruncher), `enhanced/tools/test_boot.py` (boots the disk) |
| `pillow` | `original/render/loadpic.py`, `original/render/assets.py` |

## The original game

```
python3 original/build.py                  # assemble, check each against its SHA-1, rebuild the disk
                                           # -> original/build/scr_original.adf (the release's SHA-1)
python3 original/tools/disasm/make.py      # regenerate the sources from the configs (into
                                           # original/tools/disasm/regen/) and check they reassemble
```

`python3 original/render/assets.py` renders the pictures and the samples (`original/render/out/`).

The files in `original/disk/` and `original/bin/` are in the repository. To make them again from
the Turbo release's ADF (checked against `original/disk/SHA1SUMS`):

```
python3 original/tools/disk/extract_files.py <Stunt Car Racer Turbo.adf>
```

## The AmigaDOS disk

```
python3 enhanced/tools/build_disk.py       # -> enhanced/build/scr.adf (prints its SHA-1)
python3 enhanced/tools/test_boot.py        # boots it in the emulator harness: every check "ok"
```

`build_disk.py --check SHA1` fails unless the disk has that SHA-1 (the `enhanced` workflow checks
`ADF_SHA1`: update it there when a change to the game or the bootblock is intended).

## A release

Publish a release on GitHub (tag e.g. `v1.0`): the `release` workflow builds the enhanced disk from
the tag, boots it in the harness and attaches it as `StuntCarRacer_Enhanced_<tag>.adf`.
