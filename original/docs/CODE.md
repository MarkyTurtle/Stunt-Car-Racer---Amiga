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

Named: every routine (528, each with a header) and every label among the race's variables
(`$1BAF8-$1CA41`: 519, none `dat_` now), with what each does or holds. Since November 2026 none of
the descriptions is a guess ("probably"): each was checked against the code, a recording of the
variables in play (`record`), or a knock-out (the routine made a `rts` and the picture compared),
and where the purpose is not certain the description gives the mechanics only. What was found:

* the controls: up accelerates (`EnginePower`, held by `AccelHeld`), down brakes then reverses,
  left and right steer, fire is the boost (`BoostOn`, `BoostRate`); the super league's own values
  (`RaceSettings`: 11 bytes from `dat_1FE6C`, also `KnockMargin`);
* the physics: three points touch the track (the rear middle and the front corners: `RearHeight`,
  `FrontHeightA`, `FrontHeightB`); each one's compression (`CompressFrontB`...) is damped into a
  spring (`SpringFrontB`...), their mean (`SpringMean`) pushes along the slope of the ground under
  them (`SuspensionForces`: the pitch and roll slopes' sines and cosines, `SlopeCosine`), their
  differences turn the car (`SpringPitch`, `SpringRoll`); grip is twice the spring's force
  (`SideForce`), beyond it the car skids (`Skidding`); the drag goes with the speed squared
  (`DragForce`); `PitchRate`-`RollRate` are added to the angles (`MoveCar`); the points' places on
  the track come from the car's rotation against it (`CarTrackMatrix`, `PointOffsets`);
* the opponent: its lane (`OpponentTargetLane`, `OpponentLane`), its dodge, pass and follow, its
  four corners on springs (`OpponentSpring0`..., `OpponentPhysics`) - it follows the track and is
  not otherwise simulated;
* the race: the lamps (L - `SetLeadLamp`, B - `SetBestLapLamp`), the league's points (2 a win, 1 a
  best lap: `DriverWins`, `DriverBestLaps`, `DriverTotalPoints`), the dust (once called sparks),
  the crack across the screen (`CrackLength`; at $F0 the car is wrecked: `CarWrecked`), the
  knocks' marks (`DamageMarks`, `MarkCooldown`), leaving the track and being put back
  (`CheckOffTrack`, `RestartDelay`, `RestartPiece`), the start's drop (`UpdateDrop`, `RaceStarted`);
* the view: the camera (`CarToPieceCoords`: `ViewQuarter`, `ViewHeading`, `CameraHeight`), the
  sections in view (`ViewSections`), the opponent's car on the screen (`CarModelEdges`: its length
  and width as vectors, `CarAlongX`..., the parts' points `CarSideX0`...), the horizon
  (`HorizonLine`), the drawing routines confirmed by knock-outs.

The steering (`CarPhysicsPieces`): the heading's error against the track (`TrackHeading` less
`CarHeading`) sets how the car turns. Steering's strength is the piece's (`ShapeSteer`), helped
when steering back towards the track's line (`SteerBackHelp`); a bend steers the car round itself
and cannot be steered out of (`BendWay`); with no steering on a straight the heading is pulled
back to the track's line, and more than 42 degrees off it is put back at once. The game's
integrity check is in it: the turning force is 0 unless `CopylockResult` holds `$9CEDCD02`, the
value the Copylock leaves when passed - a copy that skips the Copylock races but cannot steer. In
this release the start-up puts that value there itself (`l_5C960`). The Copylock itself
(`CopylockRoutine`) is not studied.

A few variables nothing reads or nothing writes by name remain (their descriptions say so).
`RaceViewUnused` was misnamed: only its first 4 instructions are unreachable (now
`RaceViewNoTrack`), the rest is `RaceView`'s.

`sub_`/`dat_` names are renamed across both sources, the docs
and the tools at once (whole words), so the binaries stay the same.
