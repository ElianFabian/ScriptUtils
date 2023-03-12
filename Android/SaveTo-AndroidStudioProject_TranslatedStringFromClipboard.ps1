param
(
    [string] $AndroidStudioProjectPath = 'D:/Todo/Documentos/Git/AndroidStudio/PadelManager',

    [ValidateSet('app', 'rrss')]
    [string] $Module = "app"
)


$NewLine = [System.Environment]::NewLine

$AppResourceFolder = "$AndroidStudioProjectPath/$Module/src/main/res"



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

foreach ($data in $translationsPerLanguage)
{
    $currentStringResourceFilePath = "$AppResourceFolder/values-$($data.LanguageCode)/strings.xml"

    $stringResourceFileContent = Get-Content -Path $currentStringResourceFilePath -Encoding utf8 -Raw

    $translatedStringResourceSb = [System.Text.StringBuilder]::new()

    $lineSeparator = ""
    foreach ($stringResourceData in $data.Translations)
    {
        $newStringResource = "<string name=""$($stringResourceData.Name)"">$($stringResourceData.TranslatedContent)</string>"

        $translatedStringResourceSb.Append("$lineSeparator    $newStringResource") > $null

        $lineSeparator = $NewLine
    }

    $displayInfoSb.Append("`n<!-- $($data.LanguageName) | Modified file: $currentStringResourceFilePath -->$NewLine") > $null
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