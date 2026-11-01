# Stunt Car Racer - Amiga

Geoff Crammond's *Stunt Car Racer* (MicroStyle 1989; additional graphics John Cumming): the game's
files extracted from the "Turbo" release (AGA fix and Turbo by Galahad) and disassembled into
sources that reassemble byte-identical, the game rebuilt on an ordinary AmigaDOS-format disk, and,
to come, its improvements.

| | |
|---|---|
| [`enhanced/`](enhanced) | **The game on a standard AmigaDOS disk**: a new bootblock with the [4489_byteloader](https://github.com/MarkyTurtle/4489_byteloader) and a file table in place of the release's loader, and the game's own source (`enhanced/src/scr_game.s`) for the improvements. `python3 enhanced/tools/build_disk.py` makes `enhanced/build/scr.adf` |
| [`original/`](original) | **The source disk, disassembled**: the game, the bootblock and the loader as sources that reassemble byte-identical (`original/build.py` rebuilds the disk itself), every file its boot chain reads ([`original/disk/`](original/disk)), the boot worked out ([`original/docs/BOOT.md`](original/docs/BOOT.md)) and the tools |
| [`BUILDING.md`](BUILDING.md) | What to install, and how to build and check both |

## The source disk in brief

The disk has no filesystem. The bootblock reads a packed loader through trackdisk.device to
`$40000` and copies a small helper block to `$C0` (the release's AGA fixes and F1-F3 keys). The
loader unpacks itself to `$4000`, shows the loading picture, reads the game ($325 sectors) to
`$E700` and enters it there. The game loads nothing more from the boot disk: its only disk access
is saving and loading game positions on a separate disk.

## The AmigaDOS disk in brief

The bootblock does it all: it finds the drive booted from, takes over the machine, shows the same
loading picture, loads the helper block and the game through the file table, and enters the game
as the original loader did.

## Builds

GitHub Actions build both on Windows and Linux on every push: [`original`](.github/workflows/original.yml)
(the sources against the originals' SHA-1, the rebuilt release disk, the disassembly configs) and
[`enhanced`](.github/workflows/enhanced.yml) (the disk, its SHA-1, the boot test). Each run keeps
its disk as an artifact. Publishing a release attaches the enhanced disk to it
([`release`](.github/workflows/release.yml)).

Status: boots to the game's entry in the emulator harness (`enhanced/tools/test_boot.py`); still
to try in WinUAE.
