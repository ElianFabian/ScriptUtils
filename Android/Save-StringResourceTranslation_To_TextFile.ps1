$translationsPerLanguageWithFormat = & "$PSScriptRoot\_Util\@Get-StringResourceTranslationWithFormat.ps1"



$translatedStringResourceSb = [System.Text.StringBuilder]::new()

foreach ($data in $translationsPerLanguageWithFormat)
{
    $header       = $data.Header
    $translations = $data.Translations -join "`n"

    $translatedStringResourceSb.Append("$header`n$translations`n`n") > $null
}

Clear-Host
Write-Host $translatedStringResourceSb.ToString()

$fileName = "strings $(Get-Date -Format 'yyyy-MM-dd hh;mm;ss').txt"
$filePath = Join-Path -Path $PSScriptRoot, "Translations" -ChildPath $fileName

New-Item -Path $filePath -Value $translatedStringResourceSb.ToString() -Force


# TODO: Find a way to show a notification cross-platform (Windows, Linux, macOS)
# function Show-Notification
# {
#     param
#     (
#         [string] $Title = "Title",
#         [string] $Text = "Some text"
#     )

#     Add-Type -AssemblyName System.Windows.Forms

#     $notif = New-Object System.Windows.Forms.NotifyIcon
#     $path = (Get-Process -Id $PID).Path
#     $notif.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
#     $notif.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
#     $notif.BalloonTipText = $Text
#     $notif.BalloonTipTitle = $Title
#     $notif.Visible = $true
#     $notif.ShowBalloonTip(0)
# }

# Show-Notification -Title "Translations finished" -Text "Path: $filePath"


while ($true)
{
    Read-Host
}