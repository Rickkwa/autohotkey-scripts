#Requires AutoHotkey v2.0
#SingleInstance Force

; Ctrl + Win + Up Arrow
^#Up::SnapCurrentWindow("Top")

; Ctrl + Win + Down Arrow
^#Down::SnapCurrentWindow("Bottom")

SnapCurrentWindow(position) {
    ; Check if a window is active
    if !WinExist("A")
        return

    hwnd := WinExist("A")

    ; Restore the window if it is maximized, otherwise resizing often fails
    WinRestore(hwnd)

    ; 1. Find which monitor contains the center of the active window
    WinGetPos(&wx, &wy, &ww, &wh, hwnd)
    centerX := wx + (ww / 2)
    centerY := wy + (wh / 2)

    targetMonitor := MonitorGetPrimary() ; Default fallback

    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &mL, &mT, &mR, &mB)
        ; Check if window center is within this monitor's bounds
        if (centerX >= mL && centerX <= mR && centerY >= mT && centerY <= mB) {
            targetMonitor := A_Index
            break
        }
    }

    ; 2. Get the dimensions of that monitor's Work Area (excludes taskbar)
    MonitorGetWorkArea(targetMonitor, &WL, &WT, &WR, &WB)
    workWidth := WR - WL
    workHeight := WB - WT

    ; 3. Move the window
    if (position = "Top") {
        WinMove(WL, WT, workWidth, workHeight / 2, hwnd)
    }
    else if (position = "Bottom") {
        WinMove(WL, WT + (workHeight / 2), workWidth, workHeight / 2, hwnd)
    }
}
