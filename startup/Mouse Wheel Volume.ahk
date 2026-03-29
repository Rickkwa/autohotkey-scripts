#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; CONFIGURATION
; ==============================================================================
osdTimeout := 1000  ; How long (ms) the volume number stays on screen
osdColor   := "222222" ; Background color (Dark Grey)
fontColor  := "White"  ; Text color

; ==============================================================================
; LOGIC
; ==============================================================================

; This variable holds our GUI object so we can update/destroy it
volGui := ""

; Only activate hotkeys if mouse is over the Tray or Clock areas
#HotIf MouseIsOverTray()
WheelUp::ChangeVolume("+2")
WheelDown::ChangeVolume("-2")
#HotIf

ChangeVolume(amount) {
    global volGui

    ; Change the volume
    SoundSetVolume amount

    ; Get the new volume level (rounded to whole number)
    currentVol := Round(SoundGetVolume())

    ; If the GUI doesn't exist, create it
    if !volGui {
        volGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        volGui.BackColor := osdColor
        volGui.SetFont("s16 w700 c" fontColor, "Segoe UI")
        volGui.Add("Text", "vVolText Center w60", currentVol)

        ; Calculate position: Bottom Right corner, slightly offset
        MonitorGetWorkArea(MonitorGetPrimary(), &L, &T, &R, &B)
        gW := 100
        gH := 60
        xPos := R - gW - 50
        yPos := B - gH - 70

        volGui.Show("NoActivate x" xPos " y" yPos " w" gW " h" gH)
    } else {
        ; Update existing text
        volGui["VolText"].Value := currentVol
    }

    ; Reset the timer so the GUI stays open while scrolling
    SetTimer DestroyVolGui, 0           ; Turn off existing timer
    SetTimer DestroyVolGui, -osdTimeout ; Set new one-shot timer
}

DestroyVolGui() {
    global volGui
    if volGui {
        volGui.Destroy()
        volGui := ""
    }
}

MouseIsOverTray() {
    MouseGetPos(,, &winId, &ctrlClass)

    ; "Shell_TrayWnd" is the main taskbar class.
    ; "TrayNotifyWnd" is the area with the icons.
    ; "TrayClockWClass" is the specific clock area (Windows 10/11 vary slightly).
    ; We check if the control under the mouse contains "Tray" or "Clock".

    return (WinGetClass(winId) == "Shell_TrayWnd") && (InStr(ctrlClass, "Tray") || InStr(ctrlClass, "Clock"))
}
