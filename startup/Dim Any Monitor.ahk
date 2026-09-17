#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; CONFIG
; ==============================================================================
dimPercent   := 99
fadeDuration := 200

CoordMode "Mouse", "Screen"

maxAlpha := Floor(dimPercent * 2.55)
animTick := 20
stepSize := maxAlpha / (fadeDuration / animTick)

overlays := Map()        ; monitorIndex → overlay object
monitorMap := []         ; sorted monitors [{idx, L, T, R, B}]
dimStates := Map()       ; monitorIndex → true/false

; ==============================================================================
; INIT MONITOR ORDER + HOTKEYS
; ==============================================================================

InitMonitors()
RegisterHotkeys()

InitMonitors() {
    global monitorMap

    temp := []

    count := MonitorGetCount()
    Loop count {
        MonitorGet(A_Index, &L, &T, &R, &B)
        temp.Push({idx: A_Index, L: L, T: T, R: R, B: B})
    }

    ; Sort by left coordinate (left → right)
    temp := SortArrayByLeft(temp)

    monitorMap := temp
}

RegisterHotkeys() {
    global monitorMap

    Loop monitorMap.Length {
        key := "RWin & " . A_Index
        Hotkey key, ToggleMonitor.Bind(A_Index)
    }
}

; ==============================================================================
; TOGGLE LOGIC
; ==============================================================================

ToggleMonitor(num, *) {
    global monitorMap, dimStates

    if (num > monitorMap.Length)
        return

    mon := monitorMap[num].idx

    dimStates[mon] := !dimStates.Has(mon) || !dimStates[mon]

    RefreshOverlays()
}

; ==============================================================================
; OVERLAY MANAGEMENT
; ==============================================================================

RefreshOverlays() {
    global overlays, dimStates, monitorMap

    ; Destroy old
    for _, obj in overlays
        obj.gui.Destroy()
    overlays.Clear()

    if !dimStates.Count {
        SetTimer CheckMouse, 0
        SetTimer UpdateFade, 0
        return
    }

    for _, monInfo in monitorMap {
        mon := monInfo.idx

        if !dimStates.Has(mon) || !dimStates[mon]
            continue

        L := monInfo.L
        T := monInfo.T
        R := monInfo.R
        B := monInfo.B

        g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        g.BackColor := "Black"

        WinSetTransparent(0, g.Hwnd)
        g.Show("x" L " y" T " w" (R-L) " h" (B-T) " NoActivate")

        overlays[mon] := {
            gui: g,
            currentAlpha: 0,
            targetAlpha: maxAlpha
        }
    }

    SetTimer CheckMouse, 100
    SetTimer UpdateFade, animTick
}

; ==============================================================================
; MOUSE LOGIC
; ==============================================================================

CheckMouse() {
    global overlays, maxAlpha

    if !overlays.Count
        return

    ; Disable hover if all monitors are dimmed
    if AllMonitorsDimmed() {
        for _, obj in overlays
            obj.targetAlpha := maxAlpha
        return
    }

    MouseGetPos(&mx, &my)

    for mon, obj in overlays {
        MonitorGet(mon, &L, &T, &R, &B)

        if (mx >= L && mx < R && my >= T && my < B)
            obj.targetAlpha := 0
        else
            obj.targetAlpha := maxAlpha
    }
}

; ==============================================================================
; FADE
; ==============================================================================

UpdateFade() {
    global overlays, stepSize

    for _, obj in overlays {
        if (obj.currentAlpha != obj.targetAlpha) {
            if (obj.currentAlpha < obj.targetAlpha)
                obj.currentAlpha := Min(obj.targetAlpha, obj.currentAlpha + stepSize)
            else
                obj.currentAlpha := Max(obj.targetAlpha, obj.currentAlpha - stepSize)

            try WinSetTransparent(Floor(obj.currentAlpha), obj.gui.Hwnd)
        }
    }
}

; ==============================================================================
; Helpers
; ==============================================================================

SortArrayByLeft(arr) {
    ; Simple stable sort (insertion sort — fine for small monitor counts)
    Loop arr.Length {
        i := A_Index
        while (i > 1 && arr[i].L < arr[i - 1].L) {
            temp := arr[i]
            arr[i] := arr[i - 1]
            arr[i - 1] := temp
            i--
        }
    }
    return arr
}

AllMonitorsDimmed() {
    global dimStates, monitorMap

    for _, monInfo in monitorMap {
        mon := monInfo.idx
        if !dimStates.Has(mon) || !dimStates[mon]
            return false
    }
    return true
}
