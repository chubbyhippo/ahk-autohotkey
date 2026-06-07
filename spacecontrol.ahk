Space::
{
    Send("{LCtrl Down}")
    KeyWait("Space")
    Send("{LCtrl Up}")

    if (A_PriorKey == "Space")
    {
        Send("{Space}")
    }
}
return