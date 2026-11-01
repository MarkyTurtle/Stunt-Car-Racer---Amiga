# Stunt Car Racer - the enhanced game

The game on an ordinary AmigaDOS-format disk with a file table, loaded through the
[4489_byteloader](https://github.com/MarkyTurtle/4489_byteloader), as the Ghosts'n Goblins and
New Zealand Story disks are. The game is assembled from its own source, `src/scr_game.s`,
forked from `original/scr_game.s`: for now unchanged (the disk's SHA-1 is checked by the
workflow), and where the improvements go. Its data (`sound/`, `gfx/`, `tracks/`) is the
original's: the build finds it with `-I original`.

```
python3 enhanced/tools/build_disk.py     # -> enhanced/build/scr.adf
python3 enhanced/tools/test_boot.py      # boots it in the emulator harness: every check "ok"
```

## The disk

| Disk offset | What |
|---|---|
| `$000-$3FF` | the bootblock, [`src/boot_4489.s`](src/boot_4489.s), with the 4489_byteloader ([`src/byteloader.i`](src/byteloader.i)) |
| `$400-$5FF` | the file table: `'SCRF'`, version.w, count.w, 8 bytes zero, then offset.l and length.l per file |
| `$600-` | file 0 the game (`src/scr_game.s`, to `$E700`), file 1 the loading picture (to `$78000`), file 2 the helper block (to `$C0`); the last two from `original/bin/` |

About half the disk is free.

## The boot

The bootblock does what the source disk's boot chain did ([`../original/docs/BOOT.md`](../original/docs/BOOT.md)),
without its decruncher and loader:

1. finds the drive booted from: trackdisk.device's units 3 to 0 opened until one is the boot
   IORequest's (DF0 if none is; Kickstart 1.3 boots only from DF0);
2. takes over: interrupts and DMA off, supervisor mode, stack at `$80000`;
3. copies its loader to `$1000` (file table read to `$1C00`, MFM buffer `$2000-$4EBF`);
4. reads the file table, loads the loading picture and shows it as the original loader did
   (same display registers, copper list and colours);
5. loads the helper block to `$C0` and the game to `$E700`;
6. enters the game as the original loader did: blitter idle, DF0 deselected, DMACON `$0450` off,
   USP `$7FFFC`, SSP `$3D80`, a0 = `$E700`, d0 = 0.

A load that fails is tried again; after 8 failures COLOR00 flashes red while it goes on trying.

## Tests

`tools/test_boot.py` boots the disk in Unicorn with `tools/floppy.py` (from the Ghosts'n Goblins
repository): booted from DF0, DF1, DF3 and from a unit of another device, each with the disk DMA
starting at sector 0 and at a random sector. It checks the game, the picture and the helper block
in memory against `original/`, the registers and stack at `$E700`, the display and the drive.

## Releases

Publishing a release on GitHub builds the disk from the release's tag (`.github/workflows/release.yml`)
and attaches it as `StuntCarRacer_Enhanced_<tag>.adf`.

Status: boots to the game's entry in the harness; still to try in WinUAE. What is planned:
[`TODO.md`](TODO.md).
