# To do

What is left for the enhanced game, roughly in order. The memory these plans work with is in
[`../original/docs/MEMORY.md`](../original/docs/MEMORY.md): the game is a single load of 412,160
bytes at `$E700`, and with its screens, work areas and stacks it takes about 430K of a 512K
Amiga's chip RAM. Half the load (about 210K) is pictures only shown between races.

## Groundwork

* Try the disk in WinUAE: A500 512K, expanded A500, A1200.
* Annotate the game's source (`original/scr_game.s`): name the routines, the variables, the data.
* Confirm which memory is free, by running the game in an emulator and recording every address it
  touches - `$3D80-$E6FF` (43K) has no references found so far.
* Put the 4489_byteloader in the game (as Ghosts'n Goblins and The New Zealand Story did), reading
  the boot drive through the file table, so the game can load files while it runs. The game's own
  `SectorLoader` (`$62E86`) only reads DF0 and is kept for the save disk.

## Feature: load each track when it is raced (level loading)

Load what a race needs when it is set up instead of keeping everything in memory.

* The track data is small (1,248 bytes for all 8), so the gain is not the tracks themselves but
  what can come with them: per-track scenery, colours, objects or sounds that would not all fit in
  memory together.
* Hook: the race set-up at `$5D2C8` calls the track builder (`$5AE46`) with the track number
  (`dat_1CA33`): load the track's file (or file set) just before it.
* First work out the track format (`docs/DATA.md`: the builder's tables `$1C4C0`, `$1C524`,
  `$1C588`, `$1C5EC`, `$1F0C2`) and which tables are per track.
* One file per track in the file table; on machines with more memory, keep loaded tracks in a cache
  so the next race on the same track does not touch the disk.

## Feature: load the pictures and sounds of the screens between races

Load the screens shown between races - and new ones - from the disk when they are shown, instead of
keeping them all in memory.

* The four pictures shown between races and at the end of a season (wreck, season_win,
  season_crowd, champion: 104,383 bytes) all go through one routine: `$59352` shows picture d0 of
  the table at `$56FF8`. Make it load the picture's file into a buffer, then unpack it to the screen
  as now. The menu pictures (title, stadium, divisions, Hall of Fame: 105,222 bytes) can follow the
  same way.
* New intermediate screens for each race's result - success or failure (race won, race lost,
  crashed, promoted, relegated, ...) - each with its own picture and its own sounds (a crowd cheer,
  a crash, a jingle), loaded from the disk only when the screen is shown.
* A loading buffer: the packed pictures are up to 28,581 bytes; the largest raw one is 32,034. The
  pictures removed from the load free far more than that.
* Sounds loaded with a screen go in chip RAM (Paula plays from chip RAM only), in the space freed
  by the pictures; the game's sound driver plays samples through its table (`SampleTable`), which
  can point at loaded ones.
* With more memory, keep the files once loaded (as Ghosts'n Goblins caches its files on 1MB
  machines), so each screen comes from the disk once.

## Performance

* Find where the time goes (the 3D track and car drawing, the blits) and improve the frame rate in
  `src/scr_game.s`.
