param
(
    [string] $AndroidStudioProjectPath = 'D:/Todo/Documentos/Git/AndroidStudio/PadelManager',

    [ValidateSet('app', 'rrss')]
    [string] $Module = "app"
)


$NewLine = [System.Environment]::NewLine

$AppResourceFolder = "$AndroidStudioProjectPath/$Module/src/main/res"

$LanguageToCode =
@{
    'Catalan'    = 'ca'
    'German'     = 'de'
    'Spanish'    = 'es'
    'French'     = 'fr'
    'Italian'    = 'it'
    'Portuguese' = 'pt'
    'Swedish'    = 'sv'
}



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

$displayInfoSb = [System.Text.StringBuilder]::new()

foreach ($languageAndTranslations in $translationsPerLanguage.PSObject.Properties)
{
    $currentStringResourceFilePath = "$AppResourceFolder/values-$($LanguageToCode[$languageAndTranslations.Name])/strings.xml"

    $stringResourceFileContent = Get-Content -Path $currentStringResourceFilePath -Encoding utf8 -Raw

    $translatedStringResourceSb = [System.Text.StringBuilder]::new()

    $listOfTranslationByName = $languageAndTranslations.Value

    $lineSeparator = ""
    foreach ($data in $listOfTranslationByName)
    {
        $newStringResource = "<string name=""$($data.Name)"">$($data.TranslatedContent)</string>"

        $translatedStringResourceSb.Append("$lineSeparator    $newStringResource") > $null

        $lineSeparator = $NewLine
    }

    $displayInfoSb.Append("`n<!-- $($languageAndTranslations.Name) | Modified file: $currentStringResourceFilePath -->$NewLine") > $null
    $displayInfoSb.Append("$translatedStringResourceSb$NewLine") > $null

    $translatedStringResourceSb.Append("$NewLine</resources>") > $null

    $stringResourceFileWithNewTranslatedContent = $stringResourceFileContent.Replace("$NewLine</resources>", '') + $translatedStringResourceSb.ToString()

    Set-Content -Path $currentStringResourceFilePath -Value $stringResourceFileWithNewTranslatedContent -Encoding utf8
}

Clear-Host
Write-Host $displayInfoSb.ToString().Replace("    ", "")


while ($true)
{
    Read-Host
}