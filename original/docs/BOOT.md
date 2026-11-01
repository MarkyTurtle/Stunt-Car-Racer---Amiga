# The boot, and what the game needs from it

The source disk is the "Turbo" release of Stunt Car Racer (MicroStyle 1989; AGA fix and Turbo by
Galahad): an 880K disk of standard AmigaDOS-format tracks (11 sectors, `$4489` sync) with no
filesystem. The disk map is in [`../disk/FILES.md`](../disk/FILES.md).

## Step by step

1. **The bootblock** (`t000_bootblock.bin`; Kickstart calls it with a6 = ExecBase, a1 = the boot
   IORequest): `Forbid`, `AllocMem($9800, CHIP|CLEAR)` (the result is not used: the read goes to
   `$40000`), trackdisk `CMD_READ` of `$9800` bytes from disk offset `$2C00` to `$40000`, motor off
   (`TD_MOTOR`), `Permit`. It then copies its helper block (`$9E` bytes from bootblock `$25E`) to
   `$C0` and jumps to `$40000`.
2. **`$40000`** (`t002-008_loader_packed.bin`): supervisor mode through `TRAP #0`, INTENA off,
   then a decruncher unpacks the `$31C6`-byte blob at `$40150` to `$A4CA` bytes at `$4000`
   (`../bin/loader_4000.bin`) and jumps to `$4000`.
3. **`$4000`**, the loader:
   * the loading picture: copies the word-interleaved picture at `$4D24` to 4 bitplanes at `$78000`
     (`$1F40` bytes apart), sets the 16 colours from `$4D04` through `$44B0` (3-bit values: each
     nibble doubled, plus one if not zero; colours 16-31 red), lores 4 planes (BPLCON0 `$4200`,
     DIWSTRT/STOP `$3C81`/`$04C1`, DDFSTRT/STOP `$38`/`$D0`, modulos 0), copper list at `$40EA`;
   * the game: its sector loader (`$44F8`: d0 = drive, d1 = first sector, d2 = sectors, d3 = 0 read
     / 1 write, a0 = destination, a1 = MFM buffer; d0 = 0 if it worked) reads sectors `$6E`, `$325`
     of them, to `$E700`; if that fails it tries once more, then turns COLOR00 magenta and stops;
   * on success: waits for the blitter, DF0 deselected (`$BFD100` bit 3), DMACON `$0450` off,
     USP = `$7FFFC`, SSP = `$3D80`, `JMP $E700` with a0 = `$E700`, d0 = 0.
4. **`$E700`**, the game: a word checksum of `$E730`-`$722D7` compared with `$5834`, its branch
   replaced with `NOP`s in this release (the patched game sums to `$9653`), then `TRAP #0`, stack
   `$EAD2`, `JSR $ED56`, `JMP $1BA08`.

## The helper block at `$C0` (`../bin/lowmem_c0.bin`)

Added by the release. The game calls it at `$C0` (from `$5DAC4`), `$D6` (`$6A06E`), `$E8`
(`$69FEC`) and `$FC` (`$F036`):

| Address | What |
|---|---|
| `$C0` | `tst.b (a2)` / `bne.b $C0` / `rts`: a wait. F3 toggles its branch to `NOP`: the "Turbo" option |
| `$C6` | the text `<Galahad> ` |
| `$D6`, `$E8` | AGA fixes: a0 masked to 24 bits (`$D6` also adds 2) |
| `$FC` | keyboard hook, d0 = raw key code: F1 (`$50`) toggles the audio filter, F2 (`$51`) BEAMCON0 between PAL (`$20`) and NTSC, F3 (`$52`) the turbo |

## The game's own disk access

The game has its own copy of the sector loader (entry `$62E86`), used only by *Load/Save game
position* ("Insert formatted game save disc into drive 0."): the slot directory in sector 5
(16 bytes a slot, up to 30, read to `$7A21A`), slot n in sector `$17 + n`, always in DF0. Saves
go to a separate formatted disk, so the boot disk needs no save area.
