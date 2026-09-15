#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; Audio Output Switcher
; ============================================================
;
; NO EXTERNAL LIBRARIES
;
; Ctrl+Alt+A
;   Toggle between the current and LAST audio device.
;
; Ctrl+Alt+Left / Right
;   Browse through available playback devices.
;
; Ctrl+Alt+Up / Down
;   While browsing, change the selected device's volume.
;
;   The first Left/Right/Up/Down press only opens the browser.
;   Subsequent presses perform the requested action.
;
;   The audio device is NOT changed while browsing.
;   Volume changes are applied immediately.
;
;   When Ctrl+Alt is released:
;       The selected device becomes the default.
;
; ============================================================

; ============================================================
; Configuration
; ============================================================

global VOLUME_INCREMENT := 2


; ============================================================
; Global state
; ============================================================

global gCurrentDeviceId := ""
global gLastDeviceId := ""

global gDevices := []
global gSelectedIndex := 0

global gBrowsing := false
global gBrowseApplied := false

global gBrowseGui := 0
global gPrev2Text := 0
global gPrevText := 0
global gCurrentText := 0
global gNextText := 0
global gNext2Text := 0

global gNotificationGui := 0
global gNotificationText := 0

; Used to prevent the history monitor from interpreting
; our own device switch as an external/manual switch.
global gExpectedDeviceId := ""


; ============================================================
; Initialize
; ============================================================

Initialize()
{
    global gCurrentDeviceId

    gCurrentDeviceId := GetDefaultPlaybackDeviceId()

    if !gCurrentDeviceId
    {
        ShowNotification("Could not detect audio device.")
        return
    }

    ; Check the Windows default device periodically.
    ;
    ; This lets us detect manual changes made through:
    ; - Windows sound settings
    ; - volume flyout
    ; - another audio switching application
    ;
    SetTimer(MonitorDefaultDevice, 250)
}


Initialize()


; ============================================================
; Ctrl+Alt+A
;
; Toggle between CURRENT and LAST device.
; ============================================================

^!a::
{
    ToggleLastDevice()
}


ToggleLastDevice()
{
    global gCurrentDeviceId
    global gLastDeviceId
    global gBrowsing

    ; Don't allow the toggle shortcut to interfere with
    ; an active browsing operation.
    if gBrowsing
        return

    if !gCurrentDeviceId
        gCurrentDeviceId := GetDefaultPlaybackDeviceId()

    if !gCurrentDeviceId
    {
        ShowNotification("Could not determine current device.")
        return
    }

    if !gLastDeviceId
    {
        ShowNotification("No previous audio device.")
        return
    }

    ; Make sure the previous device still exists.
    if !DeviceExists(gLastDeviceId)
    {
        gLastDeviceId := ""
        ShowNotification("Previous device is unavailable.")
        return
    }

    targetId := gLastDeviceId
    targetName := GetDeviceNameById(targetId)

    if !targetName
        targetName := "Unknown Device"

    ; Get the volume of the device we are about to switch to.
    targetVolume := GetDeviceVolume(targetId)

    if SwitchToDevice(targetId)
    {
        ShowNotification(
            FormatDeviceDisplay(targetName, targetVolume)
        )
    }
    else
    {
        ShowNotification("Failed to switch audio device.")
    }
}


; ============================================================
; Monitor Windows' current default device
; ============================================================

MonitorDefaultDevice()
{
    global gCurrentDeviceId
    global gLastDeviceId
    global gExpectedDeviceId
    global gBrowsing

    currentId := GetDefaultPlaybackDeviceId()

    if !currentId
        return

    ; Nothing changed.
    if currentId = gCurrentDeviceId
        return

    ; The change was caused by our own script.
    if currentId = gExpectedDeviceId
    {
        gCurrentDeviceId := currentId
        gExpectedDeviceId := ""
        return
    }

    ; Windows changed the device externally.
    ;
    ; Example:
    ;
    ;   Current = A
    ;   User selects B
    ;
    ; becomes:
    ;
    ;   Last    = A
    ;   Current = B
    ;
    gLastDeviceId := gCurrentDeviceId
    gCurrentDeviceId := currentId

    ; If the user was browsing when Windows changed the
    ; device externally, cancel the pending selection.
    if gBrowsing
    {
        HideBrowseGui()
        ResetBrowsing()
    }
}


; ============================================================
; Actually switch to a device
; ============================================================

SwitchToDevice(deviceId)
{
    global gCurrentDeviceId
    global gLastDeviceId
    global gExpectedDeviceId

    if !deviceId
        return false

    if deviceId = gCurrentDeviceId
        return true

    oldDeviceId := gCurrentDeviceId

    if !SetDefaultAudioDevice(deviceId)
        return false

    ; Tell the monitor that this change came from us.
    gExpectedDeviceId := deviceId

    ; Maintain actual history.
    gLastDeviceId := oldDeviceId
    gCurrentDeviceId := deviceId

    return true
}


; ============================================================
; Ctrl+Alt+Left
; ============================================================

^!Left::
{
    BeginOrContinueBrowsing(-1)
}


; ============================================================
; Ctrl+Alt+Right
; ============================================================

^!Right::
{
    BeginOrContinueBrowsing(1)
}


; ============================================================
; Ctrl+Alt+Up
;
; Change volume of the currently selected device.
; ============================================================

^!Up::
{
    BeginOrContinueVolumeBrowsing(1)
}


; ============================================================
; Ctrl+Alt+Down
;
; Change volume of the currently selected device.
; ============================================================

^!Down::
{
    BeginOrContinueVolumeBrowsing(-1)
}


; ============================================================
; Begin / continue browsing
; ============================================================

BeginOrContinueBrowsing(direction)
{
    global gDevices
    global gSelectedIndex
    global gBrowsing
    global gBrowseApplied
    global gCurrentDeviceId

    ; ========================================================
    ; FIRST arrow press:
    ;
    ; Just open the selector at the CURRENT device.
    ; Do NOT cycle yet.
    ; ========================================================

    if !gBrowsing
    {
        gDevices := GetPlaybackDevices()

        if gDevices.Length < 2
        {
            ShowNotification("Need at least two playback devices.")
            return
        }

        ; Get the actual current Windows default device.
        gCurrentDeviceId := GetDefaultPlaybackDeviceId()

        if !gCurrentDeviceId
        {
            ShowNotification("Could not determine current device.")
            return
        }

        gSelectedIndex := FindDeviceIndex(
            gDevices,
            gCurrentDeviceId
        )

        if !gSelectedIndex
        {
            ShowNotification("Current device was not found.")
            return
        }

        gBrowsing := true
        gBrowseApplied := false

        ; The first Left/Right press only opens the selector
        ; and displays the current device in the middle.
        ShowBrowseGui()
        return
    }

    ; ========================================================
    ; SUBSEQUENT arrow presses:
    ;
    ; Now actually cycle in the requested direction.
    ; ========================================================

    gSelectedIndex := CycleIndex(
        gSelectedIndex,
        direction,
        gDevices.Length
    )

    UpdateBrowseGui()
}


; ============================================================
; Begin / continue volume browsing
;
; The first Up/Down press only opens the browser.
; Subsequent presses change the selected device volume
; immediately by VOLUME_INCREMENT percentage points.
; ============================================================

BeginOrContinueVolumeBrowsing(direction)
{
    global gDevices
    global gSelectedIndex
    global gBrowsing
    global gBrowseApplied
    global gCurrentDeviceId
    global VOLUME_INCREMENT

    ; First Up/Down press only opens the selector.
    if !gBrowsing
    {
        gDevices := GetPlaybackDevices()

        if gDevices.Length < 2
        {
            ShowNotification("Need at least two playback devices.")
            return
        }

        gCurrentDeviceId := GetDefaultPlaybackDeviceId()

        if !gCurrentDeviceId
        {
            ShowNotification("Could not determine current device.")
            return
        }

        gSelectedIndex := FindDeviceIndex(
            gDevices,
            gCurrentDeviceId
        )

        if !gSelectedIndex
        {
            ShowNotification("Current device was not found.")
            return
        }

        gBrowsing := true
        gBrowseApplied := false

        ShowBrowseGui()
        return
    }

    device := gDevices[gSelectedIndex]

    if ChangeDeviceVolume(
        device.id,
        direction * VOLUME_INCREMENT
    )
    {
        UpdateBrowseGui()
    }
}


; ============================================================
; Ctrl/Alt release
;
; Apply the selected device only once both modifiers
; have been released.
; ============================================================

~Ctrl Up::
{
    TryApplySelection()
}


~Alt Up::
{
    TryApplySelection()
}


TryApplySelection()
{
    global gBrowsing
    global gBrowseApplied
    global gDevices
    global gSelectedIndex

    if !gBrowsing
        return

    if gBrowseApplied
        return

    ; If the other modifier is still held, wait for its
    ; key-up event.
    if GetKeyState("Ctrl", "P")
        return

    if GetKeyState("Alt", "P")
        return

    gBrowseApplied := true

    if gDevices.Length = 0
    {
        ResetBrowsing()
        return
    }

    device := gDevices[gSelectedIndex]

    ; Refresh the volume one last time so the notification
    ; reflects any changes made immediately before release.
    device.volume := GetDeviceVolume(device.id)

    if SwitchToDevice(device.id)
    {
        HideBrowseGui()

        ShowNotification(
            FormatDeviceDisplay(
                device.name,
                device.volume
            )
        )
    }
    else
    {
        HideBrowseGui()
        ShowNotification("Failed to switch audio device.")
    }

    ResetBrowsing()
}


; ============================================================
; Reset browsing state
; ============================================================

ResetBrowsing()
{
    global gBrowsing
    global gBrowseApplied
    global gDevices
    global gSelectedIndex

    gBrowsing := false
    gBrowseApplied := false

    gDevices := []
    gSelectedIndex := 0
}


; ============================================================
; Enumerate active playback devices
; ============================================================

GetPlaybackDevices()
{
    devices := []

    ; CLSID_MMDeviceEnumerator
    ; {BCDE0395-E52F-467C-8E3D-C4579291692E}

    ; IID_IMMDeviceEnumerator
    ; {A95664D2-9614-4F35-A746-DE8DB63617E6}

    enumerator := ComObject(
        "{BCDE0395-E52F-467C-8E3D-C4579291692E}",
        "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
    )

    collectionPtr := 0

    ; IMMDeviceEnumerator::EnumAudioEndpoints
    ;
    ; eRender = 0
    ; DEVICE_STATE_ACTIVE = 1

    hr := ComCall(
        3,
        enumerator,
        "Int",
        0,
        "UInt",
        1,
        "Ptr*",
        &collectionPtr,
        "HRESULT"
    )

    if hr != 0 || !collectionPtr
        return devices

    collection := ComValue(13, collectionPtr)

    count := 0

    ; IMMDeviceCollection::GetCount
    hr := ComCall(
        3,
        collection,
        "UInt*",
        &count,
        "HRESULT"
    )

    if hr != 0
        return devices

    Loop count
    {
        devicePtr := 0

        ; IMMDeviceCollection::Item
        hr := ComCall(
            4,
            collection,
            "UInt",
            A_Index - 1,
            "Ptr*",
            &devicePtr,
            "HRESULT"
        )

        if hr != 0 || !devicePtr
            continue

        device := ComValue(13, devicePtr)

        deviceId := GetDeviceId(device)

        if !deviceId
            continue

        deviceName := GetDeviceFriendlyName(device)

        if !deviceName
            deviceName := "Unknown Device"

        deviceVolume := GetDeviceVolume(deviceId)

        devices.Push({
            id: deviceId,
            name: deviceName,
            volume: deviceVolume
        })
    }

    return devices
}


; ============================================================
; Get Windows current default playback device
; ============================================================

GetDefaultPlaybackDeviceId()
{
    enumerator := ComObject(
        "{BCDE0395-E52F-467C-8E3D-C4579291692E}",
        "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
    )

    devicePtr := 0

    ; IMMDeviceEnumerator::GetDefaultAudioEndpoint
    ;
    ; eRender = 0
    ; eConsole = 0

    hr := ComCall(
        4,
        enumerator,
        "Int",
        0,
        "Int",
        0,
        "Ptr*",
        &devicePtr,
        "HRESULT"
    )

    if hr != 0 || !devicePtr
        return ""

    device := ComValue(13, devicePtr)

    return GetDeviceId(device)
}


; ============================================================
; Get IMMDevice ID
; ============================================================

GetDeviceId(device)
{
    idPtr := 0

    ; IMMDevice::GetId
    hr := ComCall(
        5,
        device,
        "Ptr*",
        &idPtr,
        "HRESULT"
    )

    if hr != 0 || !idPtr
        return ""

    id := StrGet(
        idPtr,
        "UTF-16"
    )

    DllCall(
        "Ole32\CoTaskMemFree",
        "Ptr",
        idPtr
    )

    return id
}


; ============================================================
; Get friendly device name
; ============================================================

GetDeviceFriendlyName(device)
{
    ; PKEY_Device_FriendlyName
    ;
    ; GUID:
    ; A45C254E-DF1C-4EFD-8020-67D146A850E0
    ;
    ; Property ID:
    ; 14

    propertyKey := Buffer(20, 0)
    guid := Buffer(16, 0)

    DllCall(
        "Ole32\CLSIDFromString",
        "Str",
        "{A45C254E-DF1C-4EFD-8020-67D146A850E0}",
        "Ptr",
        guid,
        "HRESULT"
    )

    DllCall(
        "Kernel32\RtlMoveMemory",
        "Ptr",
        propertyKey.Ptr,
        "Ptr",
        guid.Ptr,
        "UPtr",
        16
    )

    NumPut(
        "UInt",
        14,
        propertyKey,
        16
    )

    propertyStorePtr := 0

    ; IMMDevice::OpenPropertyStore
    hr := ComCall(
        4,
        device,
        "UInt",
        0,
        "Ptr*",
        &propertyStorePtr,
        "HRESULT"
    )

    if hr != 0 || !propertyStorePtr
        return ""

    propertyStore := ComValue(
        13,
        propertyStorePtr
    )

    propVariant := Buffer(16, 0)

    ; IPropertyStore::GetValue
    hr := ComCall(
        5,
        propertyStore,
        "Ptr",
        propertyKey,
        "Ptr",
        propVariant,
        "HRESULT"
    )

    if hr != 0
        return ""

    ; VT_LPWSTR = 31
    variantType := NumGet(
        propVariant,
        0,
        "UShort"
    )

    name := ""

    if variantType = 31
    {
        namePtr := NumGet(
            propVariant,
            8,
            "Ptr"
        )

        if namePtr
            name := StrGet(
                namePtr,
                "UTF-16"
            )
    }

    DllCall(
        "Ole32\PropVariantClear",
        "Ptr",
        propVariant
    )

    return name
}


; ============================================================
; Get device name by ID
; ============================================================

GetDeviceNameById(deviceId)
{
    devices := GetPlaybackDevices()

    for device in devices
    {
        if device.id = deviceId
            return device.name
    }

    return ""
}


; ============================================================
; Check whether a device still exists
; ============================================================

DeviceExists(deviceId)
{
    if !deviceId
        return false

    devices := GetPlaybackDevices()

    for device in devices
    {
        if device.id = deviceId
            return true
    }

    return false
}


; ============================================================
; Find device index
; ============================================================

FindDeviceIndex(devices, deviceId)
{
    for index, device in devices
    {
        if device.id = deviceId
            return index
    }

    return 0
}


; ============================================================
; Circular index
; ============================================================

CycleIndex(index, direction, count)
{
    index += direction

    while index < 1
        index += count

    while index > count
        index -= count

    return index
}


; ============================================================
; Get IAudioEndpointVolume interface for a device
;
; IAudioEndpointVolume IID:
; {5CDF2C82-841E-4546-9722-0CF74078229A}
; ============================================================

GetEndpointVolume(deviceId)
{
    if !deviceId
        return 0

    try
    {
        enumerator := ComObject(
            "{BCDE0395-E52F-467C-8E3D-C4579291692E}",
            "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
        )

        devicePtr := 0

        ; IMMDeviceEnumerator::GetDevice
        hr := ComCall(
            5,
            enumerator,
            "Str",
            deviceId,
            "Ptr*",
            &devicePtr,
            "HRESULT"
        )

        if hr != 0 || !devicePtr
            return 0

        device := ComValue(13, devicePtr)

        iid := Buffer(16, 0)

        DllCall(
            "Ole32\CLSIDFromString",
            "Str",
            "{5CDF2C82-841E-4546-9722-0CF74078229A}",
            "Ptr",
            iid,
            "HRESULT"
        )

        endpointPtr := 0

        ; IMMDevice::Activate
        ;
        ; CLSCTX_ALL = 23
        hr := ComCall(
            3,
            device,
            "Ptr",
            iid,
            "UInt",
            23,
            "Ptr",
            0,
            "Ptr*",
            &endpointPtr,
            "HRESULT"
        )

        if hr != 0 || !endpointPtr
            return 0

        return ComValue(13, endpointPtr)
    }
    catch
    {
        return 0
    }
}


; ============================================================
; Get device master volume as an integer percentage
;
; IAudioEndpointVolume::GetMasterVolumeLevelScalar
; vtable index = 9
; ============================================================

GetDeviceVolume(deviceId)
{
    endpoint := GetEndpointVolume(deviceId)

    if !endpoint
        return -1

    volume := 0.0

    hr := ComCall(
        9,
        endpoint,
        "Float*",
        &volume,
        "HRESULT"
    )

    if hr != 0
        return -1

    return Round(volume * 100)
}


; ============================================================
; Change device master volume
;
; delta is in percentage points.
;
; Example:
;   +2 = increase from 40% to 42%
;   -2 = decrease from 40% to 38%
; ============================================================

ChangeDeviceVolume(deviceId, delta)
{
    endpoint := GetEndpointVolume(deviceId)

    if !endpoint
        return false

    volume := 0.0

    ; IAudioEndpointVolume::GetMasterVolumeLevelScalar
    hr := ComCall(
        9,
        endpoint,
        "Float*",
        &volume,
        "HRESULT"
    )

    if hr != 0
        return false

    volume += delta / 100.0

    ; Clamp to 0.0 - 1.0.
    if volume < 0
        volume := 0

    if volume > 1
        volume := 1

    ; IAudioEndpointVolume::SetMasterVolumeLevelScalar
    ; vtable index = 7
    hr := ComCall(
        7,
        endpoint,
        "Float",
        volume,
        "Ptr",
        0,
        "HRESULT"
    )

    return hr = 0
}


; ============================================================
; Format a device name and volume for display
;
; Result:
;   Headphones (42%)
; ============================================================

FormatDeviceDisplay(deviceName, volume)
{
    if volume < 0
        volumeText := "?"

    else
        volumeText := volume "%"

    return deviceName " (" volumeText ")"
}


; ============================================================
; Set Windows default audio endpoint
;
; Uses the undocumented IPolicyConfig COM interface.
;
; Roles:
;   0 = Console
;   1 = Multimedia
;   2 = Communications
;
; We set all three so the selected device becomes the default
; playback device consistently across Windows applications.
; ============================================================

SetDefaultAudioDevice(deviceId)
{
    if !deviceId
        return false

    try
    {
        policyConfig := ComObject(
            "{870AF99C-171D-4F9E-AF0D-E63DF40C2BC9}",
            "{F8679F50-850A-41CF-9C72-430F290290C8}"
        )

        for role in [0, 1, 2]
        {
            hr := ComCall(
                13,
                policyConfig,
                "Str",
                deviceId,
                "Int",
                role,
                "HRESULT"
            )

            if hr != 0
                return false
        }

        return true
    }
    catch
    {
        return false
    }
}


; ============================================================
; Browse GUI
; ============================================================

ShowBrowseGui()
{
    global gBrowseGui
    global gPrev2Text
    global gPrevText
    global gCurrentText
    global gNextText
    global gNext2Text

    if IsObject(gBrowseGui)
    {
        UpdateBrowseGui()
        return
    }

    gBrowseGui := Gui(
        "+AlwaysOnTop -Caption +ToolWindow"
    )

    gBrowseGui.BackColor := "202020"

    ; --------------------------------------------------------
    ; 2 away - previous
    ; --------------------------------------------------------

    gBrowseGui.SetFont(
        "s9",
        "Segoe UI"
    )

    gPrev2Text := gBrowseGui.AddText(
        "w1000 h28 Center c808080",
        ""
    )

    ; --------------------------------------------------------
    ; 1 away - previous
    ; --------------------------------------------------------

    gBrowseGui.SetFont(
        "s15",
        "Segoe UI"
    )

    gPrevText := gBrowseGui.AddText(
        "w1000 h34 Center cB0B0B0",
        ""
    )

    ; --------------------------------------------------------
    ; CURRENT
    ; --------------------------------------------------------

    gBrowseGui.SetFont(
        "s24 Bold",
        "Segoe UI"
    )

    gCurrentText := gBrowseGui.AddText(
        "w1000 h50 Center cFFFFFF",
        ""
    )

    ; --------------------------------------------------------
    ; 1 away - next
    ; --------------------------------------------------------

    gBrowseGui.SetFont(
        "s15",
        "Segoe UI"
    )

    gNextText := gBrowseGui.AddText(
        "w1000 h34 Center cB0B0B0",
        ""
    )

    ; --------------------------------------------------------
    ; 2 away - next
    ; --------------------------------------------------------

    gBrowseGui.SetFont(
        "s9",
        "Segoe UI"
    )

    gNext2Text := gBrowseGui.AddText(
        "w1000 h28 Center c808080",
        ""
    )

    WinSetTransparent(
        220,
        gBrowseGui
    )

    UpdateBrowseGui()

    ShowGuiBottomCenter(gBrowseGui)
}


; ============================================================
; Update browse GUI
;
; Refreshes volumes for all visible devices so that volume
; changes are immediately reflected on screen.
; ============================================================

UpdateBrowseGui()
{
    global gDevices
    global gSelectedIndex
    global gPrev2Text
    global gPrevText
    global gCurrentText
    global gNextText
    global gNext2Text
    global gBrowseGui

    if gDevices.Length = 0
        return

    count := gDevices.Length

    ; Refresh the volume of every enumerated device.
    for index, device in gDevices
        device.volume := GetDeviceVolume(device.id)

    ; --------------------------------------------------------
    ; Calculate surrounding indices.
    ;
    ; CycleIndex() handles wrapping around the list.
    ; --------------------------------------------------------

    prevIndex := CycleIndex(
        gSelectedIndex,
        -1,
        count
    )

    prev2Index := CycleIndex(
        gSelectedIndex,
        -2,
        count
    )

    nextIndex := CycleIndex(
        gSelectedIndex,
        1,
        count
    )

    next2Index := CycleIndex(
        gSelectedIndex,
        2,
        count
    )

    ; --------------------------------------------------------
    ; Update text
    ; --------------------------------------------------------

    gPrev2Text.Text :=
        "‹  " FormatDeviceDisplay(
            gDevices[prev2Index].name,
            gDevices[prev2Index].volume
        )

    gPrevText.Text :=
        "‹  " FormatDeviceDisplay(
            gDevices[prevIndex].name,
            gDevices[prevIndex].volume
        )

    gCurrentText.Text :=
        FormatDeviceDisplay(
            gDevices[gSelectedIndex].name,
            gDevices[gSelectedIndex].volume
        )

    gNextText.Text :=
        "›  " FormatDeviceDisplay(
            gDevices[nextIndex].name,
            gDevices[nextIndex].volume
        )

    gNext2Text.Text :=
        "›  " FormatDeviceDisplay(
            gDevices[next2Index].name,
            gDevices[next2Index].volume
        )

    ShowGuiBottomCenter(gBrowseGui)
}


; ============================================================
; Hide browse GUI
; ============================================================

HideBrowseGui()
{
    global gBrowseGui

    if IsObject(gBrowseGui)
    {
        try gBrowseGui.Hide()
    }
}


; ============================================================
; Notification
; ============================================================

ShowNotification(text)
{
    global gNotificationGui
    global gNotificationText

    if IsObject(gNotificationGui)
    {
        try gNotificationGui.Destroy()
    }

    gNotificationGui := Gui(
        "+AlwaysOnTop -Caption +ToolWindow"
    )

    gNotificationGui.BackColor := "202020"

    gNotificationGui.SetFont(
        "s18 Bold",
        "Segoe UI"
    )

    gNotificationText := gNotificationGui.AddText(
        "w1000 Center cFFFFFF",
        text
    )

    WinSetTransparent(
        220,
        gNotificationGui
    )

    ShowGuiBottomCenter(gNotificationGui)

    SetTimer(
        HideNotification,
        -1000
    )
}


HideNotification()
{
    global gNotificationGui

    if IsObject(gNotificationGui)
    {
        try gNotificationGui.Hide()
    }
}


; ============================================================
; Position GUI bottom-center
; ============================================================

ShowGuiBottomCenter(gui)
{
    MonitorGetWorkArea(
        ,
        &left,
        &top,
        &right,
        &bottom
    )

    gui.Show(
        "Hide AutoSize NoActivate"
    )

    gui.GetPos(
        ,
        ,
        &guiW,
        &guiH
    )

    x := left + ((right - left - guiW) / 2)

    ; 70 pixels above bottom of usable monitor area.
    y := bottom - guiH - 70

    gui.Show(
        "x" Round(x)
        " y" Round(y)
        " NoActivate"
    )
}
