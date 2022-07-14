
#Include, D:\Google Drive\code\Elite\EDstatus\EDstatus.ahk

EliteActive() {
    Return WinActive("Elite - Dangerous (CLIENT) ahk_class FrontierDevelopmentsAppWinClass ahk_exe EliteDangerous64.exe")
}

toggleGalMap()
{
    Send, {RAlt Down}m{RAlt Up}
}

plotRoute(destination)
{
    global EDStatus
    ; open galmap if necessary
    if (EDStatus.GuiFocus != 6)
    {
        toggleGalMap()
        timeWaited := 0
        While, edstatus.GUIFocus != 6
        {
            Sleep, 200
            if (timeWaited++ == 10)
            {
                ; TODO play some error sound instead
                MsgBox, Could not open GalMap. Retry plotting after manually entering map (also check assigned shortcut)
                Return
            }
        }
    }

    ; TODO check if route is already plotted to avoid canceling it when accidentally pressing the hotkey a second time

    tmp := Clipboard
    Clipboard := destination

    ; activate search bar at 1300, 125
    Click 1300 125

    ; paste system name
    Send, ^v
    
    ; click search button at 1540, 125
    Sleep, 500
    Click 1540 125

    ; move mouse to activate route button, then to the right to avoid mouse pointer or tooltip getting in the way
    BlockInput, MouseMove
    MouseMove, 2120, 550
    MouseMove, 2180, 550
    Loop, 200
    {
        ; pixel color is around 0xFF??00 with green fluctuating too much
        PixelGetColor, top, 2150, 530, RGB
        PixelGetColor, mid, 2150, 545, RGB
        PixelGetColor, bot, 2150, 560, RGB
        if ((InStr(top, "0xFF", True) == 1) && (SubStr(top, -1) == "00")
         && (InStr(mid, "0xFF", True) == 1) && (SubStr(mid, -1) == "00")
         && (InStr(bot, "0xFF", True) == 1) && (SubStr(bot, -1) == "00"))
        {
            ; click plot route button
            MouseMove, 2140, 550
            Click
            ; exit GalMap
            Sleep, 500
            toggleGalMap()
            Break
        }
    }
    BlockInput, MouseMoveOff
    Clipboard := tmp
}
