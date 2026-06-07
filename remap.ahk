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

$Space::Send "{LCtrl Down}"

$Space Up::
{
    Send "{LCtrl Up}"

    if A_PriorKey = "Space"
    {
        Send "{Space}"
    }
}