Write-Host "Reading from clipboard...`n" -ForegroundColor Green


$translationsPerLanguage = .\@Get-AndroidStringResourceTranslationFromClipboard.ps1

if ($null -eq $translationsPerLanguage)
{
    Clear-Host

    Write-Host "Couldn't find any string resource in your clipboard.`n" -ForegroundColor Red
    Write-Host "Your clipboard content:`n" -ForegroundColor Green
    Write-Host (Get-Clipboard -Raw)

    while ($true)
    {
        Read-Host
    }
}

$translatedStringResourceSb = [System.Text.StringBuilder]::new()

foreach ($translationsInfo in $translationsPerLanguage.PSObject.Properties)
{
    $translatedStringResourceSb.Append("<!-- $($translationsInfo.Name) -->`n") > $null

    $listOfTranslationByName = $translationsInfo.Value

    foreach ($info in $listOfTranslationByName)
    {
        $translatedStringResourceSb.Append("<string name=""$($info.Name)"">$($info.TranslatedContent)</string>`n") > $null
    }

    $translatedStringResourceSb.Append("`n") > $null
}

Clear-Host
Write-Host $translatedStringResourceSb.ToString()

New-Item -Name "Translations" -ItemType Directory -ErrorAction Ignore
New-Item -Path "Translations/strings $(Get-Date -Format 'yyyy-MM-dd hh-mm-ss').txt" -Value $translatedStringResourceSb.ToString()

while ($true)
{
    Read-Host
}