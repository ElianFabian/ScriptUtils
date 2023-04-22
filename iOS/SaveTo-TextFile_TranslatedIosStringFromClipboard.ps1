Write-Host "Reading from clipboard...`n" -ForegroundColor Green


$translationsPerLanguage = .\@Get-IosStringResourceTranslationFromClipboard.ps1

if ($null -eq $translationsPerLanguage)
{
    Clear-Host

    Write-Host "Couldn't find any string resource in your clipboard.`n" -ForegroundColor Red
    Write-Host "Your clipboard content:`n" -ForegroundColor Green
    Write-Host (Get-Clipboard -Raw)

    # Remain console open
    while ($true)
    {
        Read-Host
    }
}

$translatedStringResourceSb = [System.Text.StringBuilder]::new()

foreach ($data in $translationsPerLanguage)
{
    $translatedStringResourceSb.Append("/* $($data.LanguageName) */`n") > $null

    $listOfTranslationByName = $data.Translations

    foreach ($stringResourceData in $listOfTranslationByName)
    {
        $translatedStringResourceSb.Append("""$($stringResourceData.Name)"" = ""$($stringResourceData.TranslatedContent)"";`n") > $null
    }

    $translatedStringResourceSb.Append("`n") > $null
}

Clear-Host
Write-Host $translatedStringResourceSb.ToString()

New-Item -Path "Translations/strings $(Get-Date -Format 'yyyy-MM-dd hh;mm;ss').txt" -Value $translatedStringResourceSb.ToString() -Force

# Remain console open
while ($true)
{
    Read-Host
}