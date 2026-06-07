$Space::Send("{LCtrl down}")
$Space up:: {
    Send("{LCtrl up}")
    If (A_PriorKey = "Space") {
        Send("{Space}")
    }
}