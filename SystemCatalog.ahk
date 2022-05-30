/*
full system list file size with format
NAME\tX\tY\tZ\r\n
would be around 4,8 GB

if systemName doesn't exist EDSM returns "{}"
*/

global catalogFilePath
global systemCatalog

; use with plain system names as strings
; returns -1 if one or both systems are unknown or otherwise invalid
; 
getSystemDistance(destination, origin := "Sol")
{
    if (destination = origin) ; compare ignoring case and take a shortcut if true
        return 0

    sysA := getSystem(destination)
    sysB := getSystem(origin)
    if (sysA && sysB) ; if both systems are known to either the local cache or EDSM
        return distance(sysA.x, sysA.y, sysA.z, sysB.x, sysB.y, sysB.z)

    return -1 ; if one of the systems is unknown or invalid
}

bootstrapSystemCatalog()
{
    static initialized := bootstrapSystemCatalog()

    if (not initialized)
    {
        catalogFilePath := A_AppData . "\EDNA\"
        if ( not FileExist(catalogFilePath))
            FileCreateDir, catalogFilePath
        catalogFilePath .= "systemCatalog.txt"
        loadSystemsFromFile()
        return true
    }
}

loadSystemsFromFile()
{
    systemCatalog := {"Sol" : {x: 0, y: 0, z: 0}}

    if (FileExist(catalogFilePath))
    {
        Loop, Read, %catalogFilePath%
        {
            system := StrSplit(A_LoopReadLine, A_Tab)
            systemCatalog[system[1]] := {x: system[2], y: system[3], z: system[4]}
        }
    }
}

getSystem(systemName)
{
    if (systemCatalog.HasKey(systemName) == false)
    {
        system := getSystemCoordinatesEDSM(systemName)
        ; EDSM returns "{}" for unknown systems which results in all fields of system to be empty
        ; returning nothing at this point allows for conditional use of the return value further upstream
        if (system.name == "")
            return
        systemCatalog[system.name] := {x: system.x, y: system.y, z: system.z}
        line := system.name . A_Tab . system.x . A_Tab . system.y . A_Tab . system.z . "`n"
        FileAppend, %line%, %catalogFilePath%
    }

    return systemCatalog[systemName]
}

distance(x1, y1, z1, x2, y2, z2)
{
    Return Sqrt((x1 - x2) ** 2 + (y1 - y2) ** 2 + (z1 - z2) ** 2)
}

getSystemCoordinatesEDSM(systemName)
{
    ; https://www.edsm.net/api-v1/system/?showCoordinates=1&systemName=sol
    ; {"name":"Sol","coords":{"x":0,"y":0,"z":0},"coordsLocked":true}
    response := httpRequest("https://www.edsm.net/api-v1/system/?showCoordinates=1&systemName=" . percentEncode(systemName))
    system := {}
    Loop, Parse, response, `,{}, {}
    {
        switch SubStr(A_LoopField, 2, 1)
        {
            case "n":   system.name := SubStr(A_LoopField, 9, -1)
            case "x":   system.x := SubStr(A_LoopField, 5)
            case "y":   system.y := SubStr(A_LoopField, 5)
            case "z":   system.z := SubStr(A_LoopField, 5)
        }
    }
    return system
}

getSystemsCubeEDSM(origin, size)
{
    response := httpRequest("https://www.edsm.net/api-v1/cube-systems?systemName=" . percentEncode(origin) . "&size=" . size . "&showCoordinates=1")

    systems := {}
    Loop, Parse, response, `,{}, []
    {
        switch SubStr(A_LoopField, 2, 1)
        {
            case "n":   currentSystem := SubStr(A_LoopField, 9, -1)
                        systems[currentSystem] := {}
            case "x":   systems[currentSystem].x := SubStr(A_LoopField, 5)
            case "y":   systems[currentSystem].y := SubStr(A_LoopField, 5)
            case "z":   systems[currentSystem].z := SubStr(A_LoopField, 5)
        }
    }
    return systems
}

httpRequest(url, method := "GET")
{
    static whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    ; TODO enclose in try/catch 
    ; whr can throw exception if e.g. server address can't be resolved
    whr.Open(method, url, true)
    whr.Send()
    Loop
    {
        ; Using 'true' above and the call below allows the script to remain responsive.
        if (whr.WaitForResponse(10))
        {
            if (whr.status == 200)
                Break
            else
            {
                msg := "Server request to`n`n" . url "`n`nfailed with`n`n"
                msg .= whr.status . " - " ; 200
                msg .= whr.statusText ; OK
                msg .= "`n`nTry again?"
                MsgBox, 52,, %msg%
                IfMsgBox, No
                    Break
            }
        }
        Else
        {
            MsgBox, 52, , Connection timeout. Try again?
            IfMsgBox, No
                Break
        }
    }
    Return whr.ResponseText
}

percentEncode(value)
{
    static percentMap := {"'": "%27", "<": "%3C", ">": "%3E", "#": "%23", "%": "%25", "+": "%2B", "{": "%7B", "}": "%7D", "|": "%7C", "\": "%5C", "^": "%5E", "~": "%7E", "[": "%5B", "]": "%5D", "‘": "%60", ";": "%3B", "/": "%2F", "?": "%3F", ":": "%3A", "@": "%40", "=": "%3D", "&": "%26", "$": "%24"}
    For k, v in percentMap
    {
        value := StrReplace(value, k, v)
    }
    value := StrReplace(value, " ", "%20")
    Return value
}



/*
GET https://www.edsm.net/api-v1/cube-systems

systemName*	NULL The system name which will be the center of the sphere.

x* / y* / z*	NULL If you don't want to use a system name, you can use coordinates as the center of the sphere.

size	100 Set to the desired size of the cube In ly. Maximum value is 200.

 
showId / showCoordinates / showPermit / showInformation / showPrimaryStar


https://www.edsm.net/api-v1/cube-systems?systemName=Sol&size=20&showCoordinates=1


[{"distance":11.73,"bodyCount":25,"name":"Groombridge 34","coords":{"x":-9.90625,"y":-3.6875,"z":-5.09375},"coordsLocked":true},{"distance":10.37,"bodyCount":20,"name":"Ross 248","coords":{"x":-9.3125,"y":-3.03125,"z":-3.40625},"coordsLocked":true},{"distance":10.52,"bodyCount":23,"name":"WISE 1506+7027","coords":{"x":-7.375,"y":7.09375,"z":-2.4375},"coordsLocked":true},{"distance":11.1,"bodyCount":3,"name":"EZ Aquarii","coords":{"x":-4.4375,"y":-9.3125,"z":4.09375},"coordsLocked":true},{"distance":12.43,"bodyCount":8,"name":"Teegarden's Star","coords":{"x":-3.375,"y":-7.46875,"z":-9.34375},"coordsLocked":true},{"distance":5.95,"bodyCount":16,"name":"Barnard's Star","coords":{"x":-3.03125,"y":1.375,"z":4.9375},"coordsLocked":true},{"distance":9.69,"bodyCount":9,"name":"Ross 154","coords":{"x":-1.9375,"y":-1.84375,"z":9.3125},"coordsLocked":true},{"distance":12.88,"bodyCount":39,"name":"Lacaille 8760","coords":{"x":-0.6875,"y":-9.09375,"z":9.09375},"coordsLocked":true},{"distance":10.69,"bodyCount":29,"name":"Lacaille 9352","coords":{"x":-0.40625,"y":-9.8125,"z":4.21875},"coordsLocked":true},{"distance":8.58,"bodyCount":2,"name":"UV Ceti","coords":{"x":-0.1875,"y":-8.3125,"z":-2.125},"coordsLocked":true},{"distance":0,"bodyCount":40,"name":"Sol","coords":{"x":0,"y":0,"z":0},"coordsLocked":true},{"distance":8.29,"bodyCount":3,"name":"Lalande 21185","coords":{"x":0.3125,"y":7.5625,"z":-3.375},"coordsLocked":true},{"distance":9.86,"bodyCount":2,"name":"Yin Sector CL-Y d127","coords":{"x":1.0625,"y":3.875,"z":-9},"coordsLocked":true},{"distance":10.52,"bodyCount":5,"name":"Epsilon Eridani","coords":{"x":1.9375,"y":-7.75,"z":-6.84375},"coordsLocked":true},{"distance":9.88,"bodyCount":12,"name":"Duamta","coords":{"x":2.1875,"y":6.625,"z":-7},"coordsLocked":true},{"distance":11.82,"bodyCount":9,"name":"SPF-LF 1","coords":{"x":2.90625,"y":6.3125,"z":-9.5625},"coordsLocked":true},{"distance":4.38,"bodyCount":9,"name":"Alpha Centauri","coords":{"x":3.03125,"y":-0.09375,"z":3.15625},"coordsLocked":true},{"distance":11.8,"bodyCount":14,"name":"Epsilon Indi","coords":{"x":3.125,"y":-8.875,"z":7.125},"coordsLocked":true},{"distance":7.78,"bodyCount":3,"name":"Wolf 359","coords":{"x":3.875,"y":6.46875,"z":-1.90625},"coordsLocked":true},{"distance":10.94,"bodyCount":2,"name":"Ross 128","coords":{"x":5.53125,"y":9.4375,"z":0.125},"coordsLocked":true},{"distance":11.41,"bodyCount":12,"name":"Procyon","coords":{"x":6.21875,"y":2.65625,"z":-9.1875},"coordsLocked":true},{"distance":8.59,"bodyCount":4,"name":"Sirius","coords":{"x":6.25,"y":-1.28125,"z":-5.75},"coordsLocked":true},{"distance":6.57,"bodyCount":15,"name":"Luhman 16","coords":{"x":6.3125,"y":0.59375,"z":1.71875},"coordsLocked":true},{"distance":7.17,"bodyCount":16,"name":"WISE 0855-0714","coords":{"x":6.53125,"y":-2.15625,"z":2.03125},"coordsLocked":true},{"distance":14.55,"bodyCount":4,"name":"G 41-14","coords":{"x":7.9375,"y":7.71875,"z":-9.4375},"coordsLocked":true},{"distance":12.09,"bodyCount":8,"name":"WISE 0350-5658","coords":{"x":8.28125,"y":-8.8125,"z":-0.15625},"coordsLocked":true},{"distance":12.76,"bodyCount":8,"name":"Kapteyn's Star","coords":{"x":9.75,"y":-7.46875,"z":-3.46875},"coordsLocked":true}]


