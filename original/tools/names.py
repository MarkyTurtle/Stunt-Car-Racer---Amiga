"""The names of the game's routines, variables and data: address -> (name, description).

Applied to the sources by tools/annotate.py (which renames the labels and writes the headers and
comments) and used by the disassembler's config (tools/disasm/game_cfg.py), so a regenerated
source has them too. How each was worked out: reading the code, and running the game in
tools/scremu (call counts, memory use, watched writes) - docs/CODE.md.

A routine's description says what it does and what it takes and gives (registers), as far as is
known; a name that is a best reading rather than certain says so ("probably").
"""

NAMES = {
    # ---- start-up --------------------------------------------------------------------------------
    0x0E700: ('GameEntry', 'entered by the loader at $4000 with a0 = $E700, USP $7FFFC, SSP $3D80. '
                           'A word checksum of $E730-$722D7; the release replaced the branch on it with '
                           'NOPs.'),
    0x0E72A: ('StartFlags', 'start-up flags: StartFlags+0 = 0 (cleared after the checksum) - when not 0 '
                            'Main waits with the colours yellow'),
    0x0E73C: ('Trap0Handler', 'the game continues here in supervisor mode (trap #0 at $E73A): stack '
                              '$EAD2, InitHardware, then Main.'),
    0x0E74E: ('CopperList', 'the copper list: the 4 bitplane pointers (written by SetCopperPlanes), the '
                            '32 colours, the 8 sprite pointers (all to an empty sprite), a wait for line '
                            '$FA and a copper interrupt (it flips the screens)'),
    0x0E770: ('CopperColours', 'the copper list\'s colour moves: CopperColours+2 + 4n is colour n'),
    0x0E83A: ('Palette', 'the palette in use (16 colours, the 3-bit values the game keeps: SetColours '
                         'doubles them); Palette+$20: the palette being faded to'),
    0x0E85A: ('PictureColours', 'the 16 colours of the last picture shown (SetPictureColours)'),
    0x0EAD2: ('SuperStackTop', 'the supervisor stack while the game runs (it grows down from here)'),
    0x0EAD6: ('KeyTable', '128 bytes, one per raw key code: $B3 while the key is down, 0 when up '
                          '(KeyboardInterrupt)'),
    0x0EB56: ('SerialInBuffer', '256-byte ring buffer of the bytes received from the serial port (the '
                                'computer link): written by SerialReceive, read by SerialGetByte'),
    0x0EC56: ('SerialOutBuffer', '256-byte ring buffer of the bytes to send (SerialPutByte, SerialSend)'),
    0x0ED56: ('InitHardware', 'takes over the machine: interrupts and DMA off, the 7 interrupt vectors, '
                              'the two screens at $6A594 and $72294, the display (4 planes lores, '
                              'CopperList), the CIAs, the samples\' sign bits flipped, the engine '
                              'pitches.'),
    0x0EE8A: ('InitCIAs', 'the CIAs\' timers stopped and their interrupts: CIA-A serial (the keyboard) '
                          'and timer B; CIA-B timer A and B'),
    # ---- interrupts ------------------------------------------------------------------------------
    0x0EEC8: ('Level1Handler', 'level 1: the serial port\'s transmit buffer empty (SerialSend); the '
                               'disk block (nothing); software'),
    0x0EF0A: ('Level2Handler', 'level 2: CIA-A - the keyboard (KeyboardInterrupt)'),
    0x0EF1A: ('Level3Handler', 'level 3: the copper (CopperInterrupt: the screen flip) and the vertical '
                               'blank (VBlankInterrupt)'),
    0x0EF5A: ('Level4Handler', 'level 4: the audio channels - channel 0 (the engine): its period; '
                               'channels 1-3: AudioChannelDone'),
    0x0EFC4: ('Level5Handler', 'level 5: the serial port\'s receive buffer full (SerialReceive); disk '
                               'sync (nothing)'),
    0x0EFF0: ('Level6Handler', 'level 6: CIA-B (KeyboardHandshakeDone)'),
    0x0F000: ('Level7Handler', 'level 7: nothing (rte)'),
    0x0F002: ('KeyboardInterrupt', 'CIA-A\'s interrupt: a key code from the keyboard (CIA-A serial), '
                                   'decoded and passed to the release\'s Helper_Keys (F1-F3), then '
                                   'KeyTable updated (code < $F0); starts the handshake '
                                   '(KeyboardHandshake). CIA-A timer B clears LinkTimerRunning.'),
    0x0F06A: ('KeyboardHandshake', 'the keyboard\'s handshake: CIA-A\'s serial line low (output) and '
                                   'CIA-B timer B started (one-shot, $B0 ticks) to end it'),
    0x0F0A8: ('KeyHandshakeOn', 'not 0 while a keyboard handshake is going on'),
    0x0F0AA: ('KeyboardHandshakeDone', 'CIA-B\'s interrupt: timer B has run out - the keyboard\'s serial '
                                       'line back to input'),
    0x0F0DC: ('VBlankInterrupt', 'the vertical blank: VBlankTick (the game\'s timers, the engine sound), '
                                 'and the serial port sent on if a byte is waiting'),
    0x0F112: ('CopperInterrupt', 'the copper\'s interrupt at line $FA: when a screen flip is asked for '
                                 '(FlipPending), SetCopperPlanes; and the chains moved if asked for '
                                 '(ChainsPending: MoveChains)'),
    # ---- the serial port: the computer link ------------------------------------------------------
    0x0F148: ('SerialSend', 'sends the next byte of SerialOutBuffer (8 data bits, 1 parity bit - odd '
                            'parity - and a stop bit) if the port is ready; called by the transmit '
                            'interrupt and SerialPutByte'),
    0x0F1E0: ('SerialReceive', 'the receive interrupt: the byte read with its parity checked, into '
                               'SerialInBuffer (if not full)'),
    0x0F232: ('SerialInit', 'the serial port for the link: 9600 baud ($174) with 9 bits, the buffers '
                            'emptied, CIA-B\'s DTR line set'),
    0x0F254: ('SerialInHead', 'SerialInBuffer: the next byte to write (SerialInHead), to read '
                              '(SerialInTail)'),
    0x0F255: ('SerialInTail', ''),
    0x0F256: ('SerialOutHead', 'SerialOutBuffer: the next byte to write (SerialOutHead), to send '
                               '(SerialOutTail)'),
    0x0F257: ('SerialOutTail', ''),
    0x0F258: ('SerialSending', '$80 while SerialSend is sending'),
    0x0F25A: ('SerialSendAgain', 'how many times SerialSend was asked for while it was busy'),
    0x0F25C: ('SerialInWaiting', 'Z clear if a byte has been received (SerialInHead <> SerialInTail)'),
    0x0F26A: ('SerialGetByte', 'd0 = the next byte received (waits for one)'),
    0x0F28E: ('SerialPutByte', 'd0: a byte to send (waits for room in SerialOutBuffer)'),
    # ---- the sound driver -------------------------------------------------------------------------
    0x0F2CC: ('EnginePeriod', 'audio channel 0\'s interrupt: its period from EnginePeriodValue (the '
                              'engine\'s pitch follows the revs)'),
    0x0F2D8: ('AudioChannel1Done', 'audio channel 1\'s interrupt: AudioChannelDone for channel 1'),
    0x0F2E4: ('AudioChannel2Done', 'audio channel 2\'s interrupt: AudioChannelDone for channel 2'),
    0x0F2F0: ('AudioChannel3Done', 'audio channel 3\'s interrupt: AudioChannelDone for channel 3'),
    0x0F350: ('AudioChannels', '4 entries of 4 bytes: a flag word, the channel\'s DMACON bit'),
    0x0F362: ('PlaySample', 'd0 = a sample\'s offset in SampleTable (16 x its number): played on its '
                            'channel at its period and volume (the channel\'s DMA and interrupt '
                            'restarted)'),
    0x0F3EE: ('SampleStarting', 'the DMACON bit of the channel PlaySample is starting'),
    0x0F3F0: ('StopSound', 'all 4 audio channels off, their interrupts off'),
    0x0F402: ('MakeEnginePitches', 'the engine sample at 6 rates, each half the one before, into '
                                   'EngineBuffer, and their pointers and lengths at EngineSamples'),
    0x0F472: ('EnginePeriodValue', 'the engine sound\'s period (written by the game as the revs change)'),
    0x0F474: ('EngineSamples', 'the engine sample at 7 rates: pointer, length in words (MakeEnginePitches)'),
    # ---- the screen, joystick, colours ------------------------------------------------------------
    0x1B74A: ('ReadJoystick', 'the joystick in port 2 into JoystickBits (bits low when on: 0 up, 1 '
                              'down, 2 left, 3 right, 4 fire)'),
    0x1B7B6: ('FlipScreens', 'asks for the screens to be flipped at the next copper interrupt: the '
                             'screen drawn (ScreenBack) shown'),
    0x1B7DC: ('SetCopperPlanes', 'the copper list\'s 4 bitplane pointers to the screen in ScreenToShow '
                                 '(planes $1F40 apart)'),
    0x1B812: ('ScreenToShow', 'the screen the next flip shows'),
    0x1B816: ('FlipPending', '$80: a flip asked for (FlipScreens), done by CopperInterrupt'),
    0x1B818: ('Delay', 'a delay loop ($1800 times) - nothing calls it'),
    0x1B82A: ('PrintOnBothScreens', 'prints message d1 (of MessageTexts) and message $D0 on the shown '
                                    'screen'),
    0x1B88E: ('JoystickBits', 'the joystick as ReadJoystick left it (a bit low for each direction and '
                              'fire)'),
    0x1B894: ('KeyMap', 'raw key codes to characters: the shifted table, then the unshifted one'),
    0x1BA08: ('Main', 'after InitHardware: the key table and the work area at $7A01A-$7B6F9 cleared, '
                      'the cut-out graphics made (MakeCutouts), then the title (TitleStart)'),
    0x1BA70: ('SetPictureColours', 'a1: 16 colours (a picture\'s) copied to PictureColours'),
    0x1BA82: ('SetColoursNow', 'the copper list\'s 16 colours from Palette (3-bit values doubled, plus '
                               'one where not 0)'),
    0x1BACE: ('UnpackCockpit', 'the cockpit picture unpacked to the first screen and copied to the '
                               'second'),
    # ---- pictures and the screens ------------------------------------------------------------------
    0x56FF8: ('PictureTable', 'the pictures ShowTablePicture shows: 0 the loading picture (in memory at '
                              '$78000), 1 season_win, 2 season_crowd, 3 wreck, 4 champion'),
    0x5930C: ('ShowRaceResultPicture', 'after a race in the season: picture 1, or 2 if RaceResultA is '
                                       'negative, or 3 if RaceResultB is not 0 as well'),
    0x5933A: ('ShowChampionPicture', 'at the end of a season: picture 4 (champion), unless '
                                     'NoChampionPicture is negative'),
    0x59352: ('ShowTablePicture', 'd0: a picture of PictureTable - its colours, then the picture to the '
                                  'screen drawn (unpacked if its flag is negative, else copied), faded '
                                  'in, and waits for fire'),
    0x593F8: ('UnpackPicture', 'a0: a packed picture\'s data, a1: a screen - ByteRun1 for each line of '
                               'each of the 4 planes ($1F40 apart)'),
    0x59450: ('UnpackPictureInterleaved', 'a0: a packed picture\'s data, a1: a buffer - as '
                                          'UnpackPicture, but the planes interleaved by word (each '
                                          'line\'s 4 planes 2 bytes apart)'),
    0x6444E: ('FadeOutTo', 'd0: a colour - the palette faded to it (Palette+$20 set to it, then '
                           'FadeStep until done)'),
    0x64470: ('FadeStep', 'one step of a fade: each colour of Palette a step towards Palette+$20; d7 = '
                          'how many changed'),
    0x6488A: ('WaitFire', 'waits for fire to be released, then pressed, then a short wait (Wait with '
                          'd2 = 5)'),
    0x6A584: ('ScreenFront', 'the screen at $6A594'),
    0x6A588: ('ScreenBack', 'the screen at $72294 (the one drawn on while the other is shown)'),
    0x6A58C: ('ScreenDraw', 'the screen the drawing routines draw on'),
    0x6A590: ('ScreenDrawTop', 'ScreenDraw + $284: where the 3D view starts on it'),
    0x6A594: ('ScreenMemory', 'the two screens: $6A594 and $72294 ($7D00 bytes each: 4 planes of $1F40)'),
    # ---- text ---------------------------------------------------------------------------------------
    0x594C6: ('PrintChar', 'd0: a character (or a control code below $20) printed at the text cursor'),
    0x59806: ('SetTextColour', 'd0: the text\'s colour (0-15)'),
    0x5981A: ('SetTextBackground', 'd0: the text\'s background colour (0-15)'),
    0x5DEB6: ('SetTextPosition', 'd1, d2: the text cursor\'s column and row (control code $1F, then '
                                 'the two)'),
    0x625A8: ('PrintMessage', 'd1: the offset in MessageTexts of a message ($FF-terminated) to print'),
    0x625CE: ('MessageTexts', 'messages: "LOAD game position", "SAVE game position", "Drive not '
                              'ready", ... each ending $FF (PrintMessage)'),
    0x64340: ('PrintMenuText', 'd1: the offset in MenuTexts of a text ($FF-terminated) to print'),
    0x64354: ('MenuTexts', 'menu texts ("DIVISION ", "RACE ", ...) each ending $FF (PrintMenuText)'),
    0x5A67C: ('PrintResultText', 'd1: the offset in ResultTexts of a text ($FF-terminated) to print'),
    0x5EB7F: ('ResultTexts', 'texts of the results and the league ($FF-terminated: PrintResultText)'),
    0x64C2E: ('PrintDriverName', 'd1: a driver - his name (13 characters of DriverNames) printed'),
    0x64C3E: ('PrintTrackName', 'd1: a track - its name (15 characters of TrackNames) printed'),
    0x1ECAA: ('DriverNames', 'the 12 opponents\' names and the player\'s, 16 bytes each'),
    0x1EDAA: ('TrackNames', 'the 8 tracks\' names, 16 bytes each'),
    0x6770A: ('ColourToMasks', 'd0: a colour (0-15) -> d6, d7: its 4 planes as long masks (all ones or '
                               'all zeros), for drawing in that colour'),
    0x616DC: ('VBlankTick', 'each frame: the countdowns (Countdown1, Countdown2) down by one, the engine '
                            'sound\'s period from the revs ($493E00 / (revs + $17A)), ...'),
    0x616D8: ('Countdown1', 'counted down to 0 by VBlankTick each frame'),
    0x616DA: ('Countdown2', 'counted down to 0 by VBlankTick each frame (fades: FadeOutTo sets it)'),
    0x69F04: ('MoveChains', 'the cut-outs of the chains ($25-$30) moved to their rows plus ChainsDrop: '
                            'the car lowered onto the track at the drop start'),
    0x69EC4: ('ChainsDrop', 'how far the chains have let the car down (MoveChains)'),
    0x69F41: ('ChainsPending', '$80: MoveChains at the next copper interrupt'),
    0x571A8: ('LinkTimerRunning', '$80 while CIA-A timer B runs for the link; cleared by its interrupt '
                                  '(KeyboardInterrupt)'),

    # ---- the computer link (two machines over the serial port) -----------------------------------
    0x5700C: ('LinkSendByte', 'd0: a byte sent to the other machine, added to LinkSendSum'),
    0x57028: ('LinkSendWord', 'd0: a word sent (high byte first)'),
    0x5703A: ('LinkByteWaiting', 'Z clear if a byte has come from the other machine'),
    0x57040: ('LinkGetByte', 'd0 = the next byte from the other machine (0 if F5 is pressed while '
                             'waiting: LinkCancelKey)'),
    0x5705A: ('LinkReadByte', 'd0 = a byte received, added to LinkReceiveSum, counted'),
    0x5707C: ('LinkGetWord', 'd0 = a word from the other machine (high byte first)'),
    0x570A0: ('LinkGetByteTimed', 'd0 = a byte from the other machine, waiting at most 3 short delays; '
                                  'C set if none came'),
    0x570D8: ('LinkFlushInput', 'every byte received so far read and dropped'),
    0x570EE: ('LinkStart', 'the serial port set up for the link (SerialInit), the input emptied'),
    0x57100: ('LinkKeyDown', 'd1: a key - KeyDown, or with the link on, d0 (the other machine\'s '
                             'key state) given back as the answer'),
    0x57122: ('LinkDelay6', 'six of LinkDelayLong'),
    0x57128: ('LinkDelay5', ''),
    0x57134: ('LinkDelay3', ''),
    0x57140: ('LinkDelay2', ''),
    0x57146: ('LinkDelay1', ''),
    0x5714C: ('LinkDelayLong', 'a delay of CIA-A timer B counting $1B9E (LinkWait)'),
    0x57156: ('LinkDelayShort2', ''),
    0x57162: ('LinkDelayMedium', 'a delay of $586 timer ticks (LinkWait)'),
    0x5716C: ('LinkDelayShort', 'a delay of $2C3 timer ticks: CIA-A timer B started (one-shot), waits '
                                'for its interrupt to clear LinkTimerRunning'),
    0x571AA: ('LinkMergeFlag', 'd0, d3: two machines\' flags ($40, $80) combined'),
    0x571CE: ('LinkSendCarState', 'the player\'s car sent to the other machine (its position, speed, '
                                  'angles, ...), framed and checksummed'),
    0x57440: ('LinkReceiveCarState', 'the other machine\'s car read (a frame starting $8765): its '
                                     'position, speed, angles, ... into the opponent\'s variables'),
    0x5773A: ('LinkReceiveRaceState', 'a status frame from the other machine (LinkReceiveFrame): who has '
                                      'crashed, finished, ...'),
    0x577FA: ('LinkSendFrame', 'a status frame sent: $1256, $34, then LinkFrameFlags, LinkFrameType, '
                               'LinkFrameData, LinkFrameCommand, LinkFrameValue, its checksum'),
    0x5786C: ('LinkReceiveFrame', 'a status frame read ($12 $56 $34 ...) into LinkInFlags ...; C set '
                                  'if none came or it was wrong'),
    0x57964: ('LinkMakeRaceFlags', 'LinkFrameFlags from the player\'s state (crashed, finished, ...)'),
    0x579B0: ('LinkExchange', 'LinkFrameCommand sent and the other machine\'s answer read, again until '
                              'they agree (or F5); C set if it failed'),
    0x57AC0: ('LinkExchangeControls', 'the controls exchanged with the other machine (d0)'),
    0x57B5C: ('LinkCheckChoice', 'd0 = the other machine\'s choice if it is a valid one, else $80'),
    0x57B86: ('LinkWaitBoth', 'waits until both machines are ready ($F1 / $F2 exchanged), or a key'),
    0x57C1C: ('LinkCancelKey', 'Z set if F5 ($54) is down: the key that abandons the link'),
    0x57C38: ('LinkSavedD1', ''),
    0x57C3A: ('LinkBusy', ''),
    0x57C3C: ('LinkMode', '0: no link; $80: this machine started the link; $40: the other one did'),
    0x57C3E: ('LinkSendSum', 'the checksum of the bytes sent'),
    0x57C40: ('LinkReceiveSum', 'the checksum of the bytes received'),
    0x57C44: ('LinkReceiveCount', ''),
    0x57C5C: ('LinkInFlags', 'from the last frame received'),
    0x57C62: ('LinkFrameType', 'the frame to send (LinkSendFrame)'),
    0x57C63: ('LinkFrameFlags', ''),
    0x57C64: ('LinkFrameCommand', 'the command of the frame to send ($88 resend, $AA, $B2, $C1, $E3, $F1, '
                                  '$F2, $F4, ...)'),
    0x57C65: ('LinkFrameValue', ''),
    0x57C66: ('LinkFrameData', ''),
    0x57C78: ('LinkConnect', 'Computer Link from the menu: the link started, the two machines find which '
                             'started first ($80 / $40), "Linking", "Please wait", then the driver names '
                             'and the league exchanged'),
    0x57DC2: ('LinkPrintStatus', 'd3: a message of LinkMessages printed on the screen shown'),
    0x57DE6: ('PrintText', 'a0, d3: the text at a0+d3 ($FF-terminated) printed'),
    0x57E00: ('LinkMessages', '"Link abandoned", "Link complete", "Linking", "Please wait"'),
    0x57E3E: ('LinkExchangeLeague', 'the league (the driver names, ...) sent to or read from the other '
                                    'machine, at $7A41A'),
    0x57F4C: ('LinkSendBlock', 'a6, d7: a block of d7+1 bytes sent ($16D9, $A8, the bytes, a checksum), '
                               'then confirmed ($C1)'),
    0x57F9E: ('LinkReceiveBlock', 'a6, d7: a block read (as LinkSendBlock sends it); negative if it '
                                  'failed'),
    0x58074: ('LinkSwapOpponent', 'with the link on: the race\'s opponent the other machine\'s player'),
    0x58200: ('LinkShowAbandoned', 'the screen cleared and "Link abandoned" shown'),
    0x5823C: ('LinkExchangeMenu', 'the menu choice exchanged with the other machine'),
    0x58292: ('LinkSendPosition', 'the game position sent (to $7A41A)'),
    0x5837E: ('LinkReceivePosition', 'the game position read (from $7A41A)'),
    0x58472: ('KeyEntryPosition', 'd0: a control key\'s entry in the redefine-keys screen'),
    0x5848A: ('CopyBytesDown', 'a1, d1 -> a2, d2: bytes copied, both counting down to 0'),
    0x584A0: ('ControlKeysToCodes', 'the 5 control keys (ControlKeys) to their places in KeyCodeOrder'),
    0x584DE: ('CodesToControlKeys', 'the 5 control keys back from KeyCodeOrder places'),
    0x58500: ('KeyCodeOrder', 'the raw key codes in the order the game lists them'),
    0x58580: ('CheckF1Key', 'F1 ($50) down: F1Flag ($57C68) = $80 - agreed with the other machine with '
                            'the link on (what it does: still to find)'),
    0x58600: ('LinkCheckCollision', 'with the link on: whether the cars have hit (LinkCollision)'),
    0x5865A: ('SaveRaceOrder', 'three bytes of the league ($1C908, $1C920, $1C938) kept'),
    0x5867A: ('LinkExchangeResults', 'the race\'s results exchanged with the other machine'),
    0x58758: ('LinkCheckOvertake', 'with the link on: who is ahead'),
    0x612BE: ('KeyDown', 'd1: a raw key code - Z set if the key is down (KeyTable)'),
    0x60BAE: ('ReadControls', 'd0 = the controls: the 5 control keys (ControlKeys) or the joystick, as '
                              'bits 0 up (accelerate) 1 down (brake) 2 left 3 right 4 fire (boost); '
                              'Return is fire. With the link on, the other machine is told'),
    0x60C88: ('ControlKeys', 'the 5 control keys\' raw codes (redefinable)'),

    # ---- the divisions screen, the league -----------------------------------------------------------
    0x5879E: ('LinkSwapDivisionPlaces', 'with the link on: the two players\' places in the league '
                                         'swapped in and out (SwapLeagueEntry)'),
    0x58812: ('SwapLeagueEntry', 'a league entry kept in LeagueEntrySave or put back'),
    0x58858: ('PutLeagueEntry', 'a3+d1 -> the league\'s three tables at d2'),
    0x5886C: ('GetLeagueEntry', 'the league\'s three tables at d1 -> a3+d2'),
    0x58880: ('LeagueEntrySave', ''),
    0x58888: ('ShowDivisions', 'the divisions picture (Pic_Divisions) faded in on the screen drawn'),
    0x58914: ('DrawRaceDrivers', 'the two drivers of the next race drawn (DrawDriverFace for each)'),
    0x5893C: ('DrawDriverFace', 'd0: a driver, d3: a place - his face (from the divisions picture) drawn '
                                'at that place, his name under it'),
    0x58B2C: ('DrawFaceFrame', 'the frame around a face drawn (DrawCutoutMasked)'),
    0x58DFC: ('FaceMaskNext', 'the next mask word of the face being drawn'),
    0x58E20: ('FaceMask', ''),
    0x58E30: ('ShowRaceScreen', 'the screen before and after a race: "RACE n of m", the drivers, the '
                                'league table, the results'),
    0x5914A: ('PrintLeagueText', 'd3: a text of LeagueTexts printed'),
    0x5915E: ('LeagueTexts', '"Winner 2pts Best Lap 1pt", "Raced", "Wins", "Laps", "Points", "First Second '
                             'Third"'),
    0x591C6: ('FindGlyph', 'd0: a character - a0 = its glyph in the font (in the title picture: '
                           'Pic_Title rows, 32 characters a row, 6 pixels wide), GlyphShift its bit'),
    0x5920A: ('GlyphRow', 'one row of a glyph (6 pixels) -> d7, a0 to the next row'),
    0x59250: ('PrintDriverLabel', 'a driver\'s name centred under his face'),
    0x593BA: ('CopyScreenBand', 'lines 8 to 144 of the shown screen copied to the other one'),
    0x594D6: ('PrintCharNow', 'd0: a character printed at the cursor in the text colours (the control '
                              'codes: $1F x y moves the cursor, ...); the glyphs from the title picture'),
    0x59836: ('TextColourMasks', 'the text\'s colour as plane masks (SetTextColour)'),
    0x5982E: ('TextBackgroundMasks', 'the background\'s colour as plane masks (SetTextBackground)'),
    0x5983E: ('TextCursorX', 'the text cursor: column (TextCursorX), row (TextCursorY)'),
    0x5983F: ('TextCursorY', ''),
    0x59843: ('TextControl', 'not 0 after the control code $1F: the next two bytes are a position'),
    0x59846: ('WaitKeyRelease', 'waits until no key is down and the joystick is still'),
    0x59850: ('WaitKeyPress', 'waits for a key or the joystick; d0 = it (GetKeyOrStick)'),
    0x5985C: ('GetKeyOrStick', 'd0 = the key down (its character from KeyMap, the code in the high '
                               'byte) or the joystick as cursor keys ($4C00 up, $4D00 down, ...); C '
                               'clear if none'),
    0x59928: ('KeyToMenuMove', 'd0: a key - MenuMove: $80 Esc, $20 up, $40 down, $10 right, ...'),
    0x5B83D: ('MenuMove', 'the last menu key (KeyToMenuMove): $80 Esc, $20 up, $40 down, $10 right, '
                          '$08 left'),

    # ---- maths --------------------------------------------------------------------------------------
    0x62574: ('Random', 'd0 = a random byte (a 32-bit shift register at RandomSeed)'),
    0x625A2: ('RandomSeed', ''),
    0x64D66: ('ArcTan', 'd0, d3: a vector (x, y) - d0 = its angle ($4000 = 90 degrees), from ArcTanTable '
                        'by the ratio of the smaller to the larger; d7 the ratio'),
    0x64DE8: ('VectorLength', 'd4, d5: a vector, d7 the ratio from ArcTan - d0 = its length (the longer '
                              'side times LengthTable[ratio])'),
    0x1CC46: ('ArcTanTable', '$800 words: the angle of each ratio (ArcTan)'),
    0x1DC46: ('LengthTable', '$800 words: 1 / cos of the angle of each ratio (VectorLength)'),
    # ---- the 3D view: points, polygons, pixels ---------------------------------------------------
    0x62454: ('ProjectPointX', 'd1: a point - its angle across the view from the camera (ArcTan of its '
                               'x, z less the camera\'s heading) into PointScreenX'),
    0x6249C: ('ProjectPointXFar', 'as ProjectPointX for a point far off, and its distance (VectorLength)'),
    0x624C2: ('ProjectPointY', 'd1: a point - its angle up the view (its height less the camera\'s, '
                               'over its distance) into PointScreenY'),
    0x624F0: ('ProjectPointYFar', ''),
    0x6250A: ('RollPoint', 'd1: a projected point turned by the car\'s roll (RollPointNow), unless it is '
                           'behind'),
    0x62518: ('RollPointNow', 'a3 the view\'s matrix, a5 PointScreenX, a4 PointScreenY'),
    0x6252A: ('RollPointXY', 'd1: a point\'s screen x, y turned by the roll (the matrix\'s $20, $22) and '
                             'centred ($80)'),
    0x1BFB0: ('PointScreenX', 'the projected points\' x on the screen, a word each'),
    0x1C0F0: ('PointScreenY', 'the projected points\' y on the screen, a word each'),
    0x1BE70: ('PointHeights', 'the points\' heights, a word each'),
    0x1C230: ('ViewMatrix', 'the view\'s rotation (words, $7FFF = 1): the car\'s heading, pitch and roll'),
    0x66348: ('SetPolygonColour', 'd0: a colour - the plotting code changed to set or clear each plane '
                                  '(bset / bclr written into PlotPixel and the fill)'),
    0x663F2: ('PlotPixel', 'a0, d4: a pixel set in the 4 planes (changed by SetPolygonColour)'),
    0x6646E: ('ClearWordPlanes', 'd4: a mask - those bits cleared in the 4 planes at a4'),
    0x66618: ('FillPolygon', 'a0-a3: a polygon\'s edges (lists of x for each line, from the top) - put '
                             'in order, then each line filled between the left and right edges in the '
                             'colour set by SetPolygonColour'),
    0x668A8: ('AddPolygon', 'a polygon of the view added to the list at $7B08A (unless the list is full)'),
    # ---- the track pieces --------------------------------------------------------------------------
    0x1BB85: ('PieceIndex', 'the track piece being worked on'),
    0x1CA1A: ('TrackPieceCount', 'how many pieces the track has'),
    0x5C51A: ('NextPiece', 'PieceIndex to the next piece (round to 0)'),
    0x5C538: ('PreviousPiece', 'PieceIndex to the one before (round to the last)'),
    0x5C554: ('InterpolatePiece', 'a point between the ends of a piece (by PieceFraction)'),
    0x5C6C4: ('ReadPiecePoints', 'd2: a piece - its points\' positions from the track\'s data '
                                 '(TrackOffsets), into PointX, PointZ ...'),
    0x5C0AA: ('PiecePointHeight', 'd1: a point - its height, from the piece\'s tables'),
    0x5FE56: ('LoadPiece', 'd1: a piece - its kind (TrackPieceKinds) and its parameters (PieceShapes) '
                           'made current'),
    0x5FF94: ('PieceGridOffset', 'd0: a piece - its place on the track\'s grid (TrackPieceGrid: x, y '
                                 'nibbles) less the player\'s (PlayerGridX, PlayerGridY)'),
    0x1C4C0: ('TrackPieceKinds', 'each piece\'s kind (BuildTrack)'),
    0x1C524: ('TrackPieceHeights', 'each piece\'s height (BuildTrack)'),
    0x1C588: ('TrackPieceGrid', 'each piece\'s place on the grid: x and y nibbles (BuildTrack)'),
    0x1C5EC: ('TrackPieceFlags', 'each piece\'s flags and its kind (BuildTrack)'),
    0x1EFA2: ('PieceShapes', 'the pieces\' shapes: a word for each kind'),
    0x1BB04: ('PlayerGridX', 'the grid square the player is on: x'),
    0x1BB06: ('PlayerGridY', 'y'),
    # ---- the 3D view of the track (probably: named by what they draw) ------------------------------
    0x59994: ('ProjectPiecePoint', 'd2: a point of the piece - projected (ProjectPointX, ProjectPointY, '
                                   'RollPoint) with its pair'),
    0x599E2: ('DrawPiece', 'a track piece drawn: its points projected and its polygons added '
                           '(DrawPieceRoad, DrawPieceSideA, DrawPieceSideB, DrawPieceEdges)'),
    0x59B1A: ('DrawPieceRoad', 'the road surface of a piece (probably): its polygons (AddPolygon)'),
    0x59C7C: ('DrawPieceSideA', 'one side of a piece (probably)'),
    0x59DF6: ('DrawPieceSideB', 'the other side of a piece (probably)'),
    0x59F78: ('PieceSideEnds', ''),
    0x59F98: ('DrawPieceSide', ''),
    0x5A0CE: ('DrawPieceEdges', 'the edges of a piece (probably: the kerbs)'),

    # ---- the game: seasons, menus, the league --------------------------------------------------------
    0x5CEB4: ('GameLoop', 'the game from the title on: a new game (NewGame), the menus, the season\'s '
                          'races (TrackPreview, Race, the results), the end of a season'),
    0x5D20C: ('TrackPreview', 'the track before a race: the stadium picture, the track built '
                              '(BuildTrack) and drawn from above, its name; "steer to rotate view or '
                              'fire to continue"'),
    0x5D326: ('Race', 'a race (or practice): the cockpit, the cars placed, the drop start, then the race '
                      'loop until it is over'),
    0x64EDE: ('RaceFrame', 'one frame of the race: the cars moved, the track\'s pieces in view drawn, '
                           'the cockpit and the instruments'),
    0x67AA6: ('DrawView', 'the view drawn: the pieces of track in view (DrawPiece), then the polygons '
                          'filled (FillPolygon)'),
    0x5A9B6: ('NewGame', 'the game\'s variables ($1BAF8-$1CA35) cleared, the drivers put in the '
                         'divisions in a random order, a new season (NewSeason)'),
    0x5AA38: ('NewSeason', 'the season\'s races, points and wins cleared'),
    0x5AA84: ('SimulateOtherRaces', 'the results of the season\'s other races (the drivers not racing '
                                    'the player): random, weighted by each driver\'s skill (DriverSkill)'),
    0x5AAF4: ('DriverSkill', 'the 12 opponents\' skill, a byte each'),
    0x5AB00: ('SetDivisionDrivers', 'the first and last driver of the division being raced'),
    0x5AB46: ('PickOpponent', 'the next race\'s two drivers (the player and his opponent)'),
    0x5ABD4: ('RandomRaceResult', 'a race between two other drivers decided at random'),
    0x5ACFE: ('UpdateLeague', 'the league table updated: each driver\'s points (2 a win, 1 the best lap)'),
    0x5B648: ('AskDriverName', 'the "NAME?" screen'),
    0x5B6DE: ('NamePrompt', 'the cursor (">") and the name typed'),
    0x5B71C: ('EditText', 'a line of text typed at the cursor (Return ends it, Backspace deletes)'),
    0x5B840: ('RunMenu', 'd0 the first option, d2 how many: a menu - the options listed, the highlight '
                         'moved with the joystick or the keys, chosen with fire or Return; d0 = the '
                         'choice'),
    0x5BA42: ('Wait', 'd2: a wait of d2 x 20 x 20 loops'),
    0x5BAEA: ('MainMenu', 'the menu of a division: 1. Hall of Fame, 2. Practise, 3. Start the Racing '
                          'Season, 4. Load/Save/Replay'),
    0x5BCF0: ('SetTrackChoice', 'd0: a menu choice - CurrentTrack from the division\'s tracks '
                                '(DivisionTracks)'),
    0x648C2: ('DivisionTracks', 'the tracks of each division, two each'),
    0x5A656: ('PrintOptionText', 'd1: a text of OptionTexts printed (or of ResultTexts)'),
    0x5A794: ('UpdateDrawBridge', 'on the Draw Bridge (track 5): the bridge\'s pieces ($33-$38) raised '
                                  'and lowered, and the car on them'),
    0x5B56C: ('UpdateEngineRevs', 'the engine\'s revs from the throttle and the speed, for the sound '
                                  '(EngineSoundRevs)'),
    0x5B646: ('EngineSoundRevs', ''),
    0x5AE0C: ('StepGrid', 'd0: a grid square - the next one in the direction of TrackDirection'),
    0x5A186: ('PlaceCarOnTrack', 'the car\'s place on its piece: the piece made current, its points, the '
                                 'height under the car (probably)'),
    0x5A40C: ('OpponentPieceDistance', 'd0: how far along its piece the opponent\'s car is (OpponentPiece, '
                                       'OpponentPiecePos)'),
    0x1BB1C: ('PlayerPiece', 'the piece the player\'s car is on (followed while driving in scremu)'),
    0x1BB1D: ('OpponentPiece', 'the piece the opponent\'s car is on'),
    0x1BB0A: ('PlayerPiecePos', 'how far along its piece the player\'s car is (the high byte: 0-7)'),
    0x1BB0C: ('OpponentPiecePos', 'how far along its piece the opponent\'s car is'),
    0x1BB20: ('PlayerLaps', 'the laps the player has started (0 before the start line)'),
    0x1BB21: ('OpponentLaps', 'the laps the opponent has started'),
    0x5A44E: ('PiecePointBetween', 'a point between the ends of the piece into PiecePoints'),
    0x1BD86: ('PiecePoints', ''),
    0x1BD8E: ('PiecePointsX', 'the current piece\'s points: x (and z $20 on)'),
    0x5A58E: ('ProjectStoredPoint', 'd2: a point of PiecePointsX projected'),
    0x5A62A: ('StorePiecePoint', 'd1: the point ReadPiecePoints read, stored'),
    0x1BC62: ('Speed', 'the car\'s speed (rises with the throttle, falls with the brakes)'),

    0x5D726: ('ClearRaceVariables', 'the race\'s variables ($1BAF8-$1BDCF) cleared, then the start\'s '
                                    'settings copied in for the division'),
    0x5D85A: ('ClearPointHeights', 'the points\' heights marked unknown ($8000)'),
    0x5D980: ('PreviewInput', 'in TrackPreview: steering turns the view, fire ends it (C clear)'),
    0x5D9DC: ('CheckPauseKey', 'P ($19) toggles the pause (Paused)'),
    0x1BBA4: ('Paused', '$80 while the race is paused'),
    0x5DAAC: ('StartEngineSound', 'the engine sample (7) started, its pitch from the revs'),
    0x5DAC0: ('FrameLimiter', 'waits until Countdown1 is 0 - the release\'s Helper_Wait, whose turbo (F3) '
                              'skips the wait - then sets it to 6 for the next frame: a race frame at most '
                              'every 6 vertical blanks (8.3 a second); then the screens flipped'),
    0x5DC38: ('CompareTimes', 'd1, d2: two entries of the times (TimeMinutes, TimeSeconds, TimeHundredths: '
                              'BCD) - C set if d1\'s is less'),
    0x1C908: ('TimeHundredths', 'the times (lap and race, of each driver): BCD hundredths, seconds '
                                '(TimeSeconds), minutes (TimeMinutes), a byte each'),
    0x1C920: ('TimeSeconds', ''),
    0x1C938: ('TimeMinutes', ''),
    0x5DF0A: ('ClearTime', 'd1: a time set to 0:00.00'),
    0x5DF2E: ('AddFrameTime', 'a frame\'s time ($13 hundredths) added to time d1 (AddTime)'),
    0x5DF32: ('AddTime', 'd0: hundredths (BCD) added to time d1'),
    0x5DEF6: ('PrintDigitNext', ''),
    0x5DF00: ('PrintDigit', 'd0: a digit (0-9) printed'),
    0x69F42: ('DrawCutout', 'd0: a cut-out graphic (CutoutPointers) drawn on ScreenDraw at its place '
                            '(CutoutRects)'),
    0x5C96E: ('CopylockCall', 'what called the Copylock check: nothing calls this in the release'),

    0x5E8AC: ('TitleMenu', 'the title\'s menu: 1. Single Player League, 2. Multiplayer, 3. Computer Link'),
    0x5E93E: ('ShowLeagueTable', 'the league updated (UpdateLeague) and its table shown'),
    0x5EC7E: ('PrintBonusText', 'd1: a text of BonusTexts printed ("TRACK BONUS POINTS", "FINAL SEASON")'),
    0x5ED40: ('PrintTime', 'd1: a time printed (minutes, seconds, hundredths)'),
    0x5EDCA: ('PrintNumber', 'd0: a number printed (one or two digits)'),
    0x5EDEE: ('PrintBCD', 'd0: a BCD byte printed as two digits'),
    0x5EE04: ('AddTimes', 'time d1 added to time d2'),
    0x5EF24: ('PrintSpaces3', 'three spaces printed'),
    0x5EF2E: ('PrintSpaces2', 'two spaces printed'),
    0x5EF38: ('PrintSpace', 'a space printed'),
    0x5F028: ('ToBCD', 'd0: a number (0-99) -> d0 in BCD'),
    0x5F16C: ('CheckRecordTimes', 'd1: a time compared with the track\'s records (CompareTimes): a new '
                                  'best lap or race'),
    0x5FAF2: ('DefineControlKeys', 'the control keys redefined (ControlKeys), probably'),
    0x5FB62: ('LoadSaveMenu', 'the Load/Save/Replay menu (RunMenu, its options at MenuTexts+$18), '
                              'probably'),
    0x5FBC6: ('HallOfFame', 'the Hall of Fame: its picture (Pic_HallOfFame) and the record times'),
    0x5FDF0: ('FillScreenColour', 'd0: a colour, a0: a screen - all 32000 bytes filled with it'),
    0x604B4: ('SetPreviewCamera', 'the camera for the track preview, from a table by the view\'s turn'),
    0x605B6: ('PlaceCarOnPiece', 'd1: a piece - the player\'s car placed on it (PlayerPiece), its '
                                 'heading from the piece, then settled on the track'),

    # ---- the car, the physics (named by what they work on; the physics is still to be worked out) ---
    0x6185C: ('CarPhysics', 'one step of the player\'s car: its matrix (BuildViewMatrix), the track '
                            'under it, the forces, its speed, the wheels on the track (WheelsOnTrack)'),
    0x61368: ('BuildViewMatrix', 'ViewMatrix from the car\'s angles (Sin, Cos)'),
    0x61BCC: ('WheelsOnTrack', 'each wheel\'s height against the track under it: on, above or below '
                               '(probably: the landings and the crashes)'),
    0x64D08: ('Sin', 'd0: an angle ($10000 = 360 degrees) - d0 = its sine ($7FFF = 1)'),
    0x64D10: ('Cos', 'd0: an angle - d0 = its cosine'),
    0x612A2: ('MulFraction', 'd0 x MulFactor / 256'),
    0x61338: ('MatrixTimesNeg', 'd1: an element of ViewMatrix - d0 = it x -$13D'),
    0x61340: ('MatrixTimesPos', 'd1: an element of ViewMatrix - d0 = it x $13D'),
    0x61344: ('MatrixTimes', 'd1: an element of ViewMatrix, d0: a value - d0 = their product'),
    0x6135A: ('Square', 'd0: a word - d0 = its square (long)'),
    0x63996: ('MoveOpponent', 'the opponent\'s car for a frame: on its piece (OpponentPiece), its '
                              'steering and speed'),
    0x60B9A: ('ShortWait', 'waits 3 frames (Countdown2)'),
    0x61260: ('PrintTrackTitle', 'the track\'s division and name printed'),
    0x6368C: ('SaveRandomSeed', 'RandomSeed kept (for a replay: the same race again)'),
    0x636A2: ('RestoreRandomSeed', 'RandomSeed put back'),
    # ---- the save disk: its screens --------------------------------------------------------------
    0x627CA: ('SaveSlotsScreen', 'the game positions on the save disk: its directory read and the 30 '
                                 'slots listed, one chosen'),
    0x62AB6: ('SlotUp', 'the slot cursor up one (round to 29)'),
    0x62ACA: ('SlotDown', 'the slot cursor down one (round to 0)'),
    0x62AFE: ('SlotDown10', 'the slot cursor down ten'),
    0x62B12: ('SlotUp10', 'the slot cursor up ten'),
    0x62BBE: ('StoreSlotName', 'the driver\'s name into the chosen slot\'s entry of the directory'),
    0x62C28: ('ReadSaveSlots', 'the save disk\'s directory (sector 5... $16) read to $7A21A'),
    0x62D34: ('ListSaveSlots', 'the 30 slots\' names printed'),
    0x62D8C: ('PrintSaveSlot', 'a slot\'s number and name printed'),
    # ---- the save disk: the sector loader\'s parts (as the loader at $4000\'s) -----------------------
    0x62F7A: ('SectorLoaderRead', 'the sector loader: a track read and its sectors decoded'),
    0x6305C: ('SectorLoaderWrite', 'the sector loader: a track encoded and written (DSKLEN $4000 ...)'),
    0x630DA: ('FindSectors', 'the sectors of the track read found in the MFM buffer'),
    0x63132: ('DecodeSector', 'a sector decoded from the MFM buffer'),
    0x6325E: ('SectorByteOffset', 'd1 = the sector\'s offset in the buffer ($200 a sector)'),
    0x6326E: ('MarkSectorRead', 'the sector marked as read'),
    0x6327E: ('ClearSectorHeaders', 'the 11 sectors\' headers in the MFM buffer cleared'),
    0x63290: ('DecodeHeader', 'a sector\'s header decoded: its track and sector'),
    0x632B2: ('DecodeMFMLong', 'a0: a long encoded as MFM (odd bits, even bits) -> d0'),
    0x632C8: ('CheckHeaderSum', 'Z set if the header\'s checksum is right'),
    0x632DA: ('HeaderChecksum', ''),
    0x632E0: ('MFMChecksum', 'd1 bytes at a0: their checksum (eor of the longs, the data bits)'),
    0x632FA: ('FillMFMGap', 'the MFM buffer filled with $AAAAAAAA (the gap before the sectors)'),
    0x63320: ('BlitMFMOdd', 'the blitter encodes the odd bits of a sector\'s data (descending)'),
    0x63356: ('BlitMFMEncode', 'the blitter encodes a sector\'s data as MFM: its clock bits (the only '
                               'use of the blitter in the game: writing the save disk)'),
    0x6340A: ('WaitBlitter', 'waits until the blitter is not busy'),
    0x63416: ('SetupBlitter', 'the blitter on and set up for the MFM encoding: masks, $5555, no modulos'),
    0x63442: ('EncodeMFMLong', 'd0: a long - encoded (odd bits, then even bits) to a0'),
    0x63450: ('FixClockBit', 'the clock bit at a0 made right for the bit before it'),
    0x6346E: ('MFMEncode', 'd0: data bits - with their clock bits'),
    0x6349A: ('StartDiskDMA', 'a0, d0: the disk DMA started to read or write d0 words ($4489 sync)'),
    0x634D8: ('WaitDiskBlock', 'waits for the disk block to be done (DSKBLK) or a timeout'),
    0x634FC: ('StopDiskDMA', 'the disk DMA off'),
    0x63510: ('DeselectDrives', ''),
    0x6351A: ('StepPulse', 'the drive\'s step line pulsed'),
    0x63538: ('MotorOff', 'the drive\'s motor off'),
    0x63552: ('SeekTrack', 'the head to the track d2'),
    0x635A8: ('SeekTrack0', 'the head stepped out until track 0'),
    0x635DE: ('StepHead', 'one step of the head'),
    0x63608: ('SelectDrive', 'the drive selected (its motor on)'),
    0x63614: ('DriveLines', 'd0 = CIA-B PRB for the drive selected'),
    0x63648: ('DiskDelay', 'd0: a wait of d0 x CIA-A timer A'),
    0x6365C: ('DiskTimeoutTick', ''),
    0x6366A: ('StartDiskTimer', 'CIA-A timer A started (one-shot, $2CC)'),

    # ---- screens, panels, sprites ---------------------------------------------------------------------
    0x64532: ('ShowTitleBackground', 'the title picture (Pic_Title) copied to both screens and faded in: '
                                     'the background of the menus'),
    0x64C6E: ('ClearPanel', 'the menu panel (on the title picture) cleared in colour 3'),
    0x6483E: ('CopyPanel', 'the menu panel copied from the shown screen to the other'),
    0x6642A: ('FillRect', 'd0 a colour, d4, d5, d6: a rectangle filled (probably)'),
    0x66FB8: ('ClearPolygonList', 'the list of the view\'s polygons ($7B08A) emptied'),
    0x69E9A: ('SetSpriteColours', 'colours 16-23 (the sprites\') set in the copper list'),
    0x69EC6: ('ClearSprites', 'the 8 sprites pointed at an empty sprite'),
    0x69EE0: ('SpriteFromCutout', 'd0: a cut-out - sprite d1 pointed at it'),
    0x69EF0: ('SetSpritePointer', 'd0: an address, d1: a sprite - its pointer in the copper list'),
    0x6953E: ('DrawMountains', 'the mountains on the horizon drawn, moved by the car\'s heading and pitch '
                               '(probably)'),
    0x696FC: ('LoadMountains', 'the horizon\'s outline (the same for every track: d1 is set to 0)'),
    0x67888: ('DrawHorizon', 'the sky and the ground split at the horizon, by the car\'s pitch (probably)'),
    0x65BEC: ('BuildPieceModels', 'at the start of a race: each piece\'s model made (pointers at $7AA1A)'),
    0x662B4: ('DropCar', 'the drop start: the car let down on its chains (DropCountdown, ChainsDrop)'),
    0x1BBDF: ('DropCountdown', 'counts the drop start down ($F0 at the start)'),
    0x66486: ('PlotWord1', 'the 15 routines PlotWord1-PlotWord15: d4 a mask, a4 a word of a screen - '
                           'those bits set to colour n (or-ed into the planes of n, cleared in the others)'),
    0x66496: ('PlotWord2', ''), 0x664A6: ('PlotWord3', ''), 0x664B6: ('PlotWord4', ''),
    0x664C6: ('PlotWord5', ''), 0x664D6: ('PlotWord6', ''), 0x664E6: ('PlotWord7', ''),
    0x664F6: ('PlotWord8', ''), 0x66506: ('PlotWord9', ''), 0x66516: ('PlotWord10', ''),
    0x66526: ('PlotWord11', ''), 0x66536: ('PlotWord12', ''), 0x66546: ('PlotWord13', ''),
    0x66556: ('PlotWord14', ''), 0x66566: ('PlotWord15', ''),

    # ---- tracks, races --------------------------------------------------------------------------------
    0x1CA33: ('CurrentTrack', 'the track being raced or practised (0-7)'),
    0x1F0A2: ('TrackOffsets', 'the 8 tracks\' data: a word each, byte-swapped, minus $B100, plus '
                              '$1EF82 (BuildTrack)'),
    0x5AE00: ('TrackReadByte', 'd0 = the byte d5 of the track\'s data (a5), d5 + 1'),
    0x5AE46: ('BuildTrack', 'd1: a track - its data (TrackOffsets) read into the track\'s tables (the '
                            'pieces, their heights and kinds: $1C4C0, $1C524, $1C588, $1C5EC, ...)'),
    # ---- the save disk ----------------------------------------------------------------------------
    0x5F4B6: ('CheckDriverName', 'compares the driver name with the two strings at DriverNameStrings'),
    0x5F586: ('DriverNameStrings', 'two strings the driver name is checked against'),
    0x62B74: ('ReadSaveSector', 'reads one sector of a game position (slot n: sector $17+n) through '
                                'SaveDiskIO, always in DF0 (a separate, formatted save disk)'),
    0x62B7C: ('WriteSaveSector', 'writes one sector of a game position (as ReadSaveSector)'),
    0x62D0A: ('ReadSaveDirectory', 'sector 5: the save slot names, 16 bytes each, to $7A21A'),
    0x62E78: ('SaveDiskIO', 'SectorLoader, then the drives off'),
    0x62E86: ('SectorLoader', 'the same sector loader as the loader at $4000 ($44F8), with writing: '
                              'd0 = drive, d1 = first sector, d2 = sectors, d3 = 0 read / 1 write, a0 = '
                              'buffer, a1 = MFM buffer; d0 = 0 if it worked'),
    # ---- the cut-out graphics -------------------------------------------------------------------------
    0x69CFC: ('MakeCutouts', 'at start-up: the 52 graphics the game draws over the screen (the '
                             'cockpit\'s parts, ...) cut out of the pictures - rectangles from '
                             'CutoutRects - and kept masked from $6490 up (to about $E298), each one\'s '
                             'address in CutoutPointers'),
    0x69D4E: ('MakeCutout', 'd4: a cut-out - its rectangle (CutoutRects) taken from the picture '
                            'unpacked at PictureBuffer, as masks and planes, to a1 (moved on)'),
    0x6A16C: ('CutoutRects', '52 rectangles (x, y, width, height: words) of the cut-out graphics'),
    0x6A4AC: ('CutoutPointers', 'the 52 cut-out graphics\' addresses (MakeCutouts)'),
    0x6A5B6: ('PictureBuffer', 'where MakeCutouts unpacks the cockpit (inside the first screen)'),
    # ---- the release -------------------------------------------------------------------------------
    0x5C984: ('CopylockRoutine', "Rob Northen's Copylock, as the game was protected. Nothing in this "
                                 'release calls it: the release removed the protection. Kept as data.'),
}
