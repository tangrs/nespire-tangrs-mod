NESpire v0.21 - With Tangrs' Keymap Mod

[ About ]

NESpire is an emulator that allows you to play Nintendo Entertainment
System (NES) games on the TI-Nspire or TI-Nspire CAS.

This version was modded to have different controls on the Touchpad.
It was modded so the controls are similar to gbc4nspire which, arguably, 
is more ergonomical than using a touchpad.

Original source: http://www.ticalc.org/archives/files/fileinfo/432/43217.html
Original author: Korath_3 (korath3@gmail.com)

[ Using NESpire ]

First, you must have Ndless installed to use NESpire. Ndless can be found
at http://www.ticalc.org/archives/files/fileinfo/426/42626.html.

There is no file selection screen yet; NESpire currently looks for a ROM
following itself in its own .tns file, so you must concatenate NESpire
and the ROM you wish to use together. To do this, open a command prompt,
and type (replacing "somegame" with the actual name of the ROM):

    (Windows)
    copy /B nes.bin+somegame.nes somegame.tns
or
    (*nix)
    cat nes.bin somegame.nes > somegame.tns

Now you can send the .tns file to your calculator and run it. Have fun!

[ Controls ]

Game controls (Clickpad):
    Tab   = B
    Esc   = A
    Clear = Select
    Shift = Start
    Up    = Up
    Down  = Down
    Left  = Left
    Right = Right

Game controls (Touchpad):
    Menu  = B
    Doc   = A
    Del   = Select
    Var   = Start
    8     = Up
    5     = Down
    4     = Left
    6     = Right

Emulator controls:
    (frameskip controls removed in this build since it conflicts with
     touchpad controls)
    *   = Fast-forward
    B   = Reverse border color
    P   = Pause (Many NES games have their own pause feature, but it will
            still consume just as much power as when playing the game.
            Using P to pause is preferred, so as not to waste battery life.)
    Q   = Quit
    R   = Reverse colors

[ Known Issues ]

* Saved games (e.g. in Zelda, Final Fantasy) are not yet implemented.
* Marble Madness: Display of text window at beginning of level is glitchy.
* Super Mario Bros. 3: Ground in title screen shakes up a down by 1 pixel.
