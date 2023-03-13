Import-Module -Name @(
        "$PSScriptRoot/../Modules/GenericTranslation/GenericTranslation.psm1",
        "$PSScriptRoot/../Modules/GenericTranslation/Modules/PSGoogleTranslate/PSGoogleTranslate.psm1"
    ) `



$Params =
@{
    InputObject = (Get-Clipboard -Raw)

    SourceLanguage = 'English'
    TargetLanguage =
    @(
        'Catalan',
        'German',
        'Spanish',
        'French',
        'Italian',
        'Portuguese',
        'Swedish'
    )
    ItemPattern = '<string name="(.+)">(.+)<\/string>'
}

$DecodeMap = 
@{
    "\'" = "'"
    "\n" = [System.Environment]::NewLine
}


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
        $encodedValue = $pair.Key
        $decodedValue = $pair.Value

        $decodedString = switch ($Mode)
        {
            Encode { $decodedString.Replace($decodedValue, $encodedValue) }
            Decode { $decodedString.Replace($encodedValue, $decodedValue) }
        }
    }
    return $decodedString
}


$ItemsPerLanguageCount = Get-ItemFromStringWithRegex -InputObject $Params.InputObject -ItemPattern $Params.ItemPattern -Count
$TotalItemsCount = $Params.TargetLanguage.Count * $ItemsPerLanguageCount


if ($TotalItemsCount -eq 0) { return $null }

return Invoke-ItemTranslation @Params `
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
