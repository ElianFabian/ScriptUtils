Import-Module -Name @(
        "$PSScriptRoot/../Modules/GenericTranslation/GenericTranslation.psm1",
        "$PSScriptRoot/../Modules/GenericTranslation/Modules/PSGoogleTranslate/PSGoogleTranslate.psm1"
    ) `



$SourceLanguage = 'English'

$TargetLanguage =
@(
    'Catalan',
    'German',
    'Spanish',
    'French',
    'Italian',
    'Portuguese',
    'Swedish'
)

$DecodeMap = 
@{
    "\'" = "'"
    "\n" = [System.Environment]::NewLine
}

$StringResourcePattern = '<string name="(.+)">(.+)<\/string>'


function Convert-String
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $InputObject,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Encode', 'Decode')]
        [string] $Mode
    )

    $decodedString = $InputObject

    foreach ($pair in $DecodeMap.GetEnumerator())
    {
        $decodedString = switch ($Mode)
        {
            Encode { $decodedString.Replace($pair.Value, $pair.Key) }
            Decode { $decodedString.Replace($pair.Key, $pair.Value) }
        }
    }
    return $decodedString
}


$ClipboardContent = (Get-Clipboard -Raw)


$ItemsPerLanguageCount = Get-ItemFromStringWithRegex -InputObject $ClipboardContent -ItemPattern $StringResourcePattern -Count
$TotalItemsCount = $TargetLanguage.Count * $ItemsPerLanguageCount


if ($TotalItemsCount -eq 0) { return $null }

return Invoke-ItemTranslation `
    -InputObject $ClipboardContent `
    -ItemPattern $StringResourcePattern `
    -SourceLanguage $SourceLanguage `
    -TargetLanguage $TargetLanguage `
    -OnGetItem { $name, $content = $args

        $decodedContent = Convert-String $content -Mode Decode

        [pscustomobject]@{
            Name = $name
            Content = $decodedContent
        }
    } `
    -OnTranslateItem { $item, $source, $target = $args

        $translatedContent = Invoke-GoogleTranslate `
            -InputObject $item.Content `
            -SourceLanguage $source `
            -TargetLanguage $target

        Show-TranslationProgress -TotalItemsCount $TotalItemsCount

        $encodedTranslatedContent = Convert-String $translatedContent -Mode Encode

        [pscustomobject]@{
            Name = $item.Name
            TranslatedContent = $encodedTranslatedContent
        }
    }
