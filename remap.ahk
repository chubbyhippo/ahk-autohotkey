CapsLock::LCtrl

LControl::
{
    Send("{Shift Down}")
    Send("{Alt Down}")
    Send("{Shift Up}")
    Send("{Alt Up}")
}

+LControl::CapsLock

RAlt::Ctrl

$Space::Send("{LCtrl Down}")

$Space Up::
{
    Send("{LCtrl Up}")

    if (A_PriorKey == "Space")
    {
        Send("{Space}")
    }
}
