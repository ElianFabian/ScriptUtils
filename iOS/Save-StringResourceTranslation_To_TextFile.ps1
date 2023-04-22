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


New-Item -Path "Translations/strings $(Get-Date -Format 'yyyy-MM-dd hh;mm;ss').txt" -Value $translatedStringResourceSb.ToString() -Force


while ($true)
{
    Read-Host
}