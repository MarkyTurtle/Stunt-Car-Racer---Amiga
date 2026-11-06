# The code

How the game is put together, as far as it is known, and how its names were found. The names are
in the source itself, `scr_game.s` (and its fork, `enhanced/src/scr_game.s`): each named routine
has a header saying what it does, each named variable or table a comment on its line. A name is
changed by editing the source - in both files while they are kept alike. The 3D view and the
drawing have their own page: [RENDER.md](RENDER.md).

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

The race loop (`$5D47E`) for each frame: the controls, `CarPhysics`, the engine's sound,
`RaceView` (the cars placed, the track's pieces in view projected and their edges stepped, the sky
and ground, the mountains, the track's rows filled far to near, the opponent's car, the cockpit's
parts), the drawbridge, the instruments, then `FrameLimiter`. [RENDER.md](RENDER.md) has the
pipeline and what each part costs.

`FrameLimiter` (`$5DAC0`) waits until `Countdown1` reaches 0 and sets it to 6 again: a race frame
at most every 6 vertical blanks (8.33 a second). Measured, a frame's work on an A500 takes 6.5
vertical blanks on average, so the limit rarely waits and the release's turbo (F3: the wait made a
`NOP`, `Helper_Wait`) changes nothing there. The game is simulated a step a frame.

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
(`MenuTexts`, `ResultTexts`, `MessageTexts`, ...). `PrintCharNow` draws a character a row at a
time, into both screens: its glyph's 8 columns, over a background of 7 (the masks `$1FC00`, or
`$1F800` for the proportional font - numbers, though they look like addresses: the disassembly had
them as `dat_1FC00` and `dat_1F800`, which moved with the code in the enhanced game and put two
stray pixels beside every character). About 11,400 cycles a character; the enhanced game draws
the rows in about 5,500 (`enhanced/src/textfast.i`).

## How the names were found

* reading the code (`tools/disasm` traced it);
* `tools/scremu`, the game run on a minimal Amiga: how often each routine is called in play
  (`calls`), which memory each part touches (`usage`, `watch`), how variables change with the
  controls (`record`: speed, the pieces the cars are on, the laps, the rotation matrix);
* where the time goes: scremu's `profile` (cycles by instruction) and `callprof` (by routine,
  with all it calls), the telemetry build (`enhanced/src/telemetry.i`, by phase of a frame), and
  `writelog` (every write to a variable, with the instruction that wrote it);
* the screens: `tools/screen.py` draws scremu's snapshots by following the copper list.

## Status

Named: the start-up, the interrupts and the hardware, the sound, the input, the text, the pictures,
the menus and the league, the save disk, the computer link, the maths, the projection, and the 3D
view's pipeline ([RENDER.md](RENDER.md): `RaceView`, `ProjectNearPiece`, `ProjectFarPieces`, the
`Edges...` routines, `ScanEdge`, `DrawFarRows`, `DrawNearRows`, `FillRowSurface`,
`FillBetweenEdges`, `DrawEdgeLine`, `DrawOpponentCar`, the row table and the edge buffers). Named by
what they work on, not yet understood in detail (their descriptions say "probably"): the car's
physics, the opponent's driving, the track's format, the opponent's car's model.

Since November 2026 every routine has a name and a header (528; none is `sub_` now). The last 196
were named from what they do and what calls them, many of them "probably": the race's input,
clock, lamps (L the lead, B probably the best lap), messages and damage (`CarKnocks`,
`GrowCrack`, `DrawDamageMark`); the physics (`VelocityToCarAxes`, `DriveForce`, `WheelForces`,
`SuspensionForces`, `AddForce`, `AddTorque`, `MoveCar`, the drop: `UpdateDrop`); the opponent
(`OpponentDrive`, its pace, `OpponentCollide`, `OpponentPhysics`); the sparks; the track's grid
(`TrackGrid`, `BuildTrackGrid`), the pieces' sections and the rows' sides and lines
(`DrawRowsLeftLines`, `FillRowsLeftSide`, `FillFarRowLeftSide`, ...); the save disk's scrambling
(`ScrambleLeague`), the menus and the season's end (`SeasonEnd`). `CarPhysicsPieces` is named from
where it is called only. Of the race's variables (`$1BAF8-$1CA35`), 163 are named - the car's
place, angles, velocity, forces and turning in the world's and the car's axes, the springs, the
knocks, the messages, the text cursor, the league's tables - and six shared work bytes
(`WorkByte1-6`); about 330 labels there are still `dat_`: mostly parts of tables (the car model's
corners, the horizon's and the cars' edge buffers, the pieces' data) and variables used by one
routine whose role is not yet clear. `sub_`/`dat_` names are renamed across both sources, the docs
and the tools at once (whole words), so the binaries stay the same.
