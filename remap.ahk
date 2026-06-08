SetCapsLockState "AlwaysOff"

CapsLock::
{
    Send "{LControl Down}"
    KeyWait "CapsLock"
    Send "{LControl Up}"

    if A_PriorKey = "CapsLock"
    {
        Send "{Esc}"
    }
}

LControl::
{
    Send "{Shift Down}"
    Send "{Alt Down}"
    Send "{Shift Up}"
    Send "{Alt Up}"
}

+LControl::CapsLock

spaceIsCtrl := false

*$Space::
{
    global spaceIsCtrl

    if !spaceIsCtrl
    {
        spaceIsCtrl := true
        Send "{RCtrl Down}"
    }
}

*$Space Up::
{
    global spaceIsCtrl

    if spaceIsCtrl
    {
        Send "{RCtrl Up}"
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
    Send "{RCtrl Up}{LCtrl Up}{LControl Up}{RControl Up}"
}
