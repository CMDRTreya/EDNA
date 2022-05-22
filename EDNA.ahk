#Requires AutoHotkey v1.1.31.00+
#Include, D:\Google Drive\code\Elite\EDstatus\EDstatus.ahk
; #Include, <autoReload>
#Persistent
SetKeyDelay, 50, 150

; fn := Func("test")
; if fn
;     fn.Call()

savedSystemListPath := A_AppData . "\EDNA"
if (not FileExist(savedSystemListPath))
    FileCreateDir, %savedSystemListPath%
savedSystemListPath .= "\systemList.txt"

FileGetSize, fileSize, %savedSystemListPath%
if (fileSize == 0)
    FileDelete, %savedSystemListPath%

if FileExist(savedSystemListPath)
    systemCount := loadSimpleSystemList(savedSystemListPath)
Else
    systemCount := readEDSMscannerSystemList()

if (systemCount > 0)
    nextInRoute := systemList.RemoveAt(systemList.MinIndex())

OnExit("saveSystemList")

SetTimer, updateCurrentSystemAndNextInRoute, 1000

; if FileExist(filePath)
;     switch source
;     {
;         case "EDSM Scanner":
;             systemCount := readEDSMscannerSystemList(filePath)
;         case "bar":
;             MsgBox, "bar"
;         ; Default:
;         ;     MsgBox, "default"
;     }

CustomColor := "EEAA99"  ; Can be any RGB color (it will be made transparent below).
Gui +LastFound +AlwaysOnTop -Caption +ToolWindow  ; +ToolWindow avoids a taskbar button and an alt-tab menu item.
Gui, Color, %CustomColor%
Gui, Margin,, -5

Gui, Font, q5 s32, Segoe UI Semibold
Gui, Add, Text, w200 Center Hidden vRefuel cYellow, FUEL

; Make all pixels of this color transparent and make the text itself translucent (150):
WinSet, TransColor, %CustomColor% 150
Gui, Show, xCenter y0 NoActivate  ; NoActivate avoids deactivating the currently active window.

; the taskbar (if visible) will overlap this one, removing the need to deactivate this HUD element manually \o/
Gui HUDnext:+LastFound +AlwaysOnTop -Caption +ToolWindow  ; +ToolWindow avoids a taskbar button and an alt-tab menu item.
Gui, HUDnext:Color, %CustomColor%
Gui, HUDnext:Margin,, 0
; Gui, Font, s32  ; Set a large font size (32-point).
; Gui, Add, Text, vMyText cYellow
Gui, HUDnext:Font, q2 s15, Segoe UI SemiLight
Gui, HUDnext:Add, Text, w400 Center vNext cEE7700, %nextInRoute%

WinSet, TransColor, %CustomColor%
Gui, HUDnext:Show, x300 y1045 NoActivate  ; NoActivate avoids deactivating the currently active window.

Return

F17::ListVars

loadSimpleSystemList(filePath)
{
    cnt := 0
    if FileExist(filePath)
    {
        global systemList := {}
        Loop, Read, %filePath%
        {
            StringUpper, system, A_LoopReadLine
            systemList.push(system)
            cnt++
        }
    }
    Return cnt
}

saveSystemList()
{
    global
    For k, v in systemList
        local output .= v . "`n"
    FileDelete, %savedSystemListPath%
    FileAppend, %output%, %savedSystemListPath%
}

; Returns 0 on failure, count of systems(lines, really) processed otherwise
readEDSMscannerSystemList(filePath := "")
{
    cnt := 0
    global systemList := {}
    if (filePath == "")
        FileSelectFile, filePath, 3, , Open a EDSM Scanner generated system list, EDSM Scanner (*.txt)
    systemsInput := FileOpen(filePath, "r")
    if systemsInput
    {
        systemsInput.ReadLine() ; skip header
        While, not systemsInput.AtEOF
        {
            line := systemsInput.ReadLine()
            endPos := InStr(line, "[") - 2
            system := SubStr(line, 1, endPos)
            StringUpper, system, system
            systemList.push(system)
            cnt++
        }
        systemsInput.Close()
    }
    Return cnt
}

; setWorkingDirToLogFolder()
; {
;     ; C:\Users\Maya\Saved Games\Frontier Developments\Elite Dangerous
;     EnvGet, path, USERPROFILE
;     path .= "\Saved Games\Frontier Developments\Elite Dangerous\"
;     SetWorkingDir, %path%
; }

/*
    EVENTS:

    4.12 Location
        When written: at startup, or when being resurrected at a station
        Parameters:
            StarSystem: name of destination starsystem
            SystemAddress
            StarPos: star position, as a Json array [x, y, z], in light years
            Body: star or planet’s body name
            BodyID
            BodyType
            DistFromStarLS: (unless close to main star)
            ...

    4.18 NavRoute
        When plotting a multi-star route, the file “NavRoute.json” is written in the same directory as the journal, with a list of stars along that route
        Parameters:
            Route
                StarSystem: (name)
                SystemAddress: (number)
                Starpos: [ x, y, z ]
                StarClass
        Example:
            (verbatim as written to file -> one header line, then one system per line, one line extra at the end)
            { "timestamp":"2022-05-13T20:19:05Z", "event":"NavRoute", "Route":[ 
            { "StarSystem":"Prai Hypoo CJ-B b4-1", "SystemAddress":2744617021985, "StarPos":[-9329.37500,-407.96875,7985.78125], "StarClass":"M" }, 
            { "StarSystem":"Prai Hypoo QC-C d32", "SystemAddress":1108042763395, "StarPos":[-9297.21875,-389.59375,7944.28125], "StarClass":"G" }
            ] }

    4.13 StartJump
        When written: at the start of a Hyperspace or Supercruise jump (start of countdown)
        Parameters:
            JumpType: "Hyperspace" or "Supercruise"
            StarSystem: name of destination system (for a hyperspace jump)
            SystemAddress
            StarClass: star type (only for a hyperspace jump)

    4.9 FSDTarget
        When written: when selecting a star system to jump to
        Note, when following a multi-jump route, this will typically appear for the next star, during a jump, ie
        after “StartJump” but before the “FSDJump”
        Parameters:
            Starsystem
            Name
            RemainingJumpsInRoute
            StarClass

    4.8 FSDJump
        When written: when jumping from one star system to another
        Parameters:
            StarSystem: name of destination starsystem
            SystemAddress
            StarPos: star position, as a Json array [x, y, z], in light years
            Body: star’s body name
            JumpDist: distance jumped
            FuelUsed
            FuelLevel
            BoostUsed: whether FSD boost was used
            ...

        Example:
            { "timestamp":"2018-10-29T10:05:21Z", "event":"FSDJump",
            "StarSystem":"Eranin",
            "SystemAddress":2832631632594,
            "StarPos":[-22.84375,36.53125,-1.18750],
            "JumpDist":13.334,
            "FuelUsed":0.000000,
            "FuelLevel":25.630281,
            ...

*/

updateCurrentSystemAndNextInRoute()
{
    static logfile
    static elite := "Elite - Dangerous (CLIENT) ahk_class FrontierDevelopmentsAppWinClass ahk_exe EliteDangerous64.exe"
    global currentSystem
    global systemList
    global nextInRoute
    static logFileNamePattern
    static logFolderPath

    if (logFileNamePattern == "")
    {
        ; C:\Users\Maya\Saved Games\Frontier Developments\Elite Dangerous
        EnvGet, logFolderPath, USERPROFILE
        logFolderPath .= "\Saved Games\Frontier Developments\Elite Dangerous\"
        ; logFileNamePattern := logFolderPath . "Journal." . A_YYYY . "-" . A_MM . "-" . A_DD . "*.log"
        logFileNamePattern := logFolderPath . "Journal.*-*-*.log"
    }

    if (not WinExist(elite) )
    {
        ; Wait until ED has been started and then give it time to start today's log file
        WinWait, %elite%
        While, not FileExist(logFileNamePattern)
            Sleep, 1000
    }
    if (not logfile) ; safeguard to ensure we have a valid log file open
    {
        Loop, %logFileNamePattern%
        {
            logs .= A_LoopFileName . "`n"
        }
        Sort, logs, R
        logfile := FileOpen(logFolderPath . SubStr(logs, 1, InStr(logs, "`n") - 1), "r")
        Return
    }
    ; assert ELite running and log file to exist
    While, not logfile.AtEOF
    {
        currentLine := logfile.ReadLine()
        Switch SubStr(currentLine, 48, InStr(currentLine, """",, 48) - 48)
        {
            Case "Location", "FSDJump":
                ; , "StarSystem":"Prai Hypoo QC-C d32",
                startPos := InStr(currentLine, """Starsystem"":""",, 48) + 14
                endPos := InStr(currentLine, """", , startPos)
                currentSystem := SubStr(currentLine, startPos, endPos - startPos)
        }
    }
    if (currentSystem == nextInRoute)
    {
        nextInRoute := systemList.RemoveAt(systemList.MinIndex())
        GuiControl, Text, next, %nextInRoute%
    }
    if ((systemList.Count() == 0) && (nextInRoute == ""))
    {
        MsgBox, Route exhausted, exiting.
        FileDelete, %savedSystemListPath%
        ExitApp
    }
}

EliteActive() {
    Return WinActive("Elite - Dangerous (CLIENT) ahk_class FrontierDevelopmentsAppWinClass ahk_exe EliteDangerous64.exe")
}

toggleGalMap()
{
    Send, {RAlt Down}m{RAlt Up}
}

; Space::
; MsgBox, % systemList[1]
; return

#If EliteActive()

F22::
systemList.push(nextInRoute)
nextInRoute := systemList.RemoveAt(systemList.MinIndex())
GuiControl, Text, next, %nextInRoute%
F21::
; plotRoute((Clipboard == "Sol") ? "Colonia" : "Sol")
plotRoute(nextInRoute)

Return

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
                MsgBox, Could not open GalMap. Retry plotting after manually entering map (also check assigned shortcut)
                Return
            }
        }
    }

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

}

test()
{
    logfile := FileOpen("C:\Users\Maya\Desktop\ED Journal\Journal.220304101212.01.log", "r")
    DllCall("QueryPerformanceFrequency", "Int64*", freq)
    DllCall("QueryPerformanceCounter", "Int64*", CounterBefore)
    
    While, not logfile.AtEOF
    {
        currentLine := logfile.ReadLine()
        Switch SubStr(currentLine, 48, InStr(currentLine, """",, 48) - 48)
        {
            Case "Location", "FSDJump":
                ; , "StarSystem":"Prai Hypoo QC-C d32",
                startPos := InStr(currentLine, """Starsystem"":""",, 48) + 14
                endPos := InStr(currentLine, """", , startPos)
                currentSystem := SubStr(currentLine, startPos, endPos - startPos)
        }
    }

    DllCall("QueryPerformanceCounter", "Int64*", CounterAfter)
    MsgBox, 4,,  % currentSystem . "`nElapsed QPC time is " . (CounterAfter - CounterBefore) / freq * 1000 " ms"
    IfMsgBox, Yes
        test()
    ExitApp

}