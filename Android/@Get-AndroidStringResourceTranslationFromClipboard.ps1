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

function FromStringResContentToRegularString([string] $InputObject)
{
    $decodedString = $InputObject

    foreach ($pair in $DecodeMap.GetEnumerator())
    {
        $decodedString = $decodedString.Replace($pair.Key, $pair.Value)
    }
    return $decodedString
}

function FromRegularStringToStringResContent([string] $InputObject)
{
    $encodedString = $InputObject

    foreach ($pair in $DecodeMap.GetEnumerator())
    {
        $encodedString = $encodedString.Replace($pair.Value, $pair.Key)
    }
    return $encodedString
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

        $decodedContent = FromStringResContentToRegularString $content

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

        $encodedTranslatedContent = FromRegularStringToStringResContent $translatedContent

        [pscustomobject]@{
            Name = $item.Name
            TranslatedContent = $encodedTranslatedContent
        }
    }
