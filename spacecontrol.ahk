$Space::Send("{LCtrl Down}")

$Space Up::
{
    Send("{LCtrl Up}")

    if (A_PriorKey == "Space")
    {
        Send("{Space}")
    }
}