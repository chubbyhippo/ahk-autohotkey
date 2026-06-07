CapsLock::LCtrl

LControl::
{
    Send "{Shift Down}"
    Send "{Alt Down}"
    Send "{Shift Up}"
    Send "{Alt Up}"
}

+LControl::CapsLock

RAlt::Ctrl

$Space::Send("{LCtrl down}")
$Space up:: {
    Send("{LCtrl up}")
    If (A_PriorKey = "Space") {
        Send("{Space}")
    }
}