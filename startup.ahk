#Requires AutoHotkey v2.0
#SingleInstance Force

startupDir := "C:\Users\ricky\Documents\AutoHotkey\startup"
thisScript := A_ScriptFullPath

Loop Files startupDir "\*.ahk" {
    ; Skip launching itself
    if (A_LoopFileFullPath = thisScript)
        continue

    Run '"' A_LoopFileFullPath '"'
}

Exit
