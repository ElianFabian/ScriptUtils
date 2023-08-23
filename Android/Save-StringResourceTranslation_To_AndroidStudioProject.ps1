param
(
    [string] $AndroidStudioProjectPath = 'C:\Users\empresa\Documents\GitHub\PadelManager',

    [ValidateSet('app', 'rrss')]
    [string] $Module = "app"
)


$translationsPerLanguageWithFormat = & "$PSScriptRoot\_Util\@Get-StringResourceTranslationWithFormat.ps1"



$NewLine = [System.Environment]::NewLine

$AppResourceFolder = "$AndroidStudioProjectPath/$Module/src/main/res"


$displayInfoSb = [System.Text.StringBuilder]::new()

foreach ($data in $translationsPerLanguageWithFormat)
{
    $currentStringResourceFilePath = "$AppResourceFolder/values-$($data.Code)/strings.xml"

    $translatedStringResourceSb = [System.Text.StringBuilder]::new()

    $lineSeparator = ""
    foreach ($stringResource in $data.Translations)
    {
        $translatedStringResourceSb.Append("$lineSeparator    $stringResource") > $null

        $lineSeparator = $NewLine
    }

    $displayInfoSb.Append("`n<!-- $($data.Language) | Modified file: $currentStringResourceFilePath -->$NewLine") > $null
    $displayInfoSb.Append("$translatedStringResourceSb$NewLine") > $null

    $translatedStringResourceSb.Append("$NewLine</resources>") > $null

    $stringResourceFileContent = Get-Content -Path $currentStringResourceFilePath -Encoding utf8 -Raw

    $stringResourceFileWithNewTranslatedContent = $stringResourceFileContent.Replace("$NewLine</resources>", '') + $translatedStringResourceSb.ToString()

    Set-Content -Path $currentStringResourceFilePath -Value $stringResourceFileWithNewTranslatedContent -Encoding utf8
}

#Clear-Host
Write-Host $displayInfoSb.ToString().Replace("    ", "")


while ($true)
{
    Read-Host
}