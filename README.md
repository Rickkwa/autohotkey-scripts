# Installation

Set up a windows startup app to run `startup.ahk`.

1. Create a shortcut file of `startup.ahk`.
2. Move that shortcut file into `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`
3. Verify it shows up in Settings > Apps > Startup and is enabled

# Scripts

## Dim Any Monitor

`CTRL + ALT + <N>` will toggle the dim on screen N. The screen will temporarily undim if you hover the mouse cursor over the dimmed screen. If all screens are dimmed, then the mouse hover effect is disabled.

## Mouse Wheel Volume

Hover the mouse over the icon tray and use the scroll wheel to adjust the volume.

## Snap Window Top or Bottom Half

Windows provides snap to left/right half of the screen with `WIN + Left/Right`. But what about snapping to the top/bottom half of the screen?

This script aallows `CTRL + WIN + Up/Down Arrow` to snap the current focused window to the top half or bottom half of the screen.

## Swap Audio

Provides a few functionalities.

1. `CTRL + ALT + A` will toggle swap the current audio output device to the last used device.
2. `CTRL + ALT + Left/Right Arrow` will allow you to cycle between audio output devices while you continue to hold `CTRL + ALT`, switching to the new device when you let go.
3. `CTRL + ALT + Up/Down Arrow` will allow you to immediately increase/decrease the volume of the selected audio output device.
