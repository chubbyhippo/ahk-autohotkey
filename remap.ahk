SetCapsLockState "AlwaysOff"

spaceIsCtrl := false

CapsLock::
{
    Send "{LCtrl Down}"
    KeyWait "CapsLock"
    Send "{LCtrl Up}"

    if A_PriorKey = "CapsLock"
    {
        Send "{Esc}"
    }
}

LCtrl::
{
    Send "#{Space}"
}

+LCtrl::CapsLock

*$Space::
{
    global spaceIsCtrl

    if !spaceIsCtrl
    {
        spaceIsCtrl := true
        Send "{LCtrl Down}"
    }
}

*$Space Up::
{
    global spaceIsCtrl

    if spaceIsCtrl
    {
        Send "{LCtrl Up}"
        spaceIsCtrl := false
    }

    if A_PriorKey = "Space"
    {
        Send "{Space}"
    }
}

OnExit ReleaseModifiers

ReleaseModifiers(*)
{
    Send "{LCtrl Up}{RCtrl Up}{Shift Up}{Alt Up}{LWin Up}{RWin Up}"
}
