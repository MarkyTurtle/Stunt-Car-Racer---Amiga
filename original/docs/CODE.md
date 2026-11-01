# The code

How the game is put together, as far as it is known, and how its names were found. The names and
their descriptions are in [`../tools/names.py`](../tools/names.py); `tools/annotate.py` applies them
to the sources (each routine gets a header with its description; each variable a comment).

## Start-up

`GameEntry` (`$E700`: the release's disabled checksum) -> `TRAP #0` -> `Trap0Handler` ->
`InitHardware` (interrupts, the two screens at `$6A594` and `$72294`, the display, the CIAs, the
samples, the engine's pitches) -> `Main` (the key table and the work area cleared, `MakeCutouts`)
-> `GameLoop`.

## The game

`GameLoop` (`$5CEB4`): `NewGame`, the title's menu (`TitleMenu`: single player league, multiplayer,
computer link), the driver's name (`AskDriverName`), then the division's menu (`MainMenu`: Hall of
Fame, Practise, the season, Load/Save/Replay). A race is `TrackPreview` (the stadium picture, the
track built from its data by `BuildTrack` and drawn from above) then `Race` (the cockpit, the cars
placed, the drop start, the race loop). After a race: the results, the league
(`UpdateLeague`, `ShowLeagueTable`), `SimulateOtherRaces` for the drivers not racing the player,
and a picture (`ShowRaceResultPicture`, `ShowChampionPicture`).

## A race frame

`RaceFrame` (`$64EDE`) for each frame: the car's physics (`CarPhysics`: `BuildViewMatrix`, the forces,
`WheelsOnTrack`), the opponent (`MoveOpponent`), the cars placed on their pieces
(`PlaceCarOnTrack`), the track's pieces in view projected (`ProjectPointX`, `ProjectPointY`,
`RollPoint`) and turned into polygons (`DrawPiece`, `AddPolygon`), the horizon (`DrawHorizon`,
`DrawMountains`), the polygons filled (`DrawView`, `FillPolygon`: the CPU, a line at a time), the
cockpit's moving parts (`DrawCutout`, the chains: `MoveChains`), the instruments, then
`FrameLimiter`.

`FrameLimiter` (`$5DAC0`) waits until `Countdown1` reaches 0 and sets it to 6 again: a race frame
at most every 6 vertical blanks (8.3 a second). The release's turbo (F3) makes the wait a `NOP`
(`Helper_Wait`). How long a frame really takes - and so how much the limit matters on an A500 -
is the first thing to measure for the performance work (scremu's `profile`).

## The hardware

* **Interrupts**: level 1 the serial port sending, 2 the keyboard (`KeyboardInterrupt` ->
  `KeyTable`), 3 the copper at line `$FA` (`CopperInterrupt`: the screen flip,
  `SetCopperPlanes`) and the vertical blank (`VBlankTick`: the countdowns, the engine sound's
  pitch), 4 the audio channels, 5 the serial port receiving, 6 the keyboard's handshake.
* **Display**: one copper list (`CopperList`): 4 planes lores, 16 colours, the sprites unused but
  set (`ClearSprites`). Two screens, flipped by the copper interrupt.
* **Sound**: `PlaySample` (channel, period and volume from `SampleTable`); the engine on channel 0,
  its period changed by its own interrupt (`EnginePeriod`).
* **Input**: `ReadControls` (the joystick or 5 redefinable keys, `ControlKeys`), `KeyDown`.
* **The blitter** is not used for drawing: only to MFM-encode the save disk (`BlitMFMEncode`).
* **The computer link**: two machines over the serial port (`Link...` routines): checksummed
  frames and blocks, each machine's car sent every frame (`LinkSendCarState`,
  `LinkReceiveCarState`).

## Text

`PrintChar` (control code `$1F x y` moves the cursor), its glyphs taken from the title picture
(`FindGlyph`: 6 pixels wide); `SetTextColour`, `SetTextBackground`; tables of texts ending `$FF`
(`MenuTexts`, `ResultTexts`, `MessageTexts`, ...).

## How the names were found

* reading the code (`tools/disasm` traced it);
* `tools/scremu`, the game run on a minimal Amiga: how often each routine is called in play
  (`calls`), which memory each part touches (`usage`, `watch`), how variables change with the
  controls (`record`: speed, the pieces the cars are on, the laps, the rotation matrix);
* the screens: `tools/screen.py` draws scremu's snapshots by following the copper list.

## Status

Named: 301 of the 511 routines and 120 or so variables and tables (`tools/names.py`). Named fully:
the start-up, the interrupts and the hardware, the sound, the input, the text, the pictures, the
menus and the league, the save disk, the computer link, the maths, the projection. Named by what
they work on, not yet understood in detail (their descriptions say "probably"): the car's physics,
the opponent's driving, the track's format, the parts of the 3D view. Not named yet: the remaining
210 routines - mostly the 3D view's internals (the polygon list's drawing, `$688FC-$69270`), the
physics (`$61950-$62424`), the opponent (`$636C0-$63EE2`) - and most of the race's variables
(`$1BAF8-$1CA35`).
