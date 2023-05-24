param
(
    [Parameter(Mandatory=$true)]
    [string] $InputObject,

    [string] $SourceLanguage = 'English',

    [string[]] $TargetLanguage = @(
        'Catalan',
        'German',
        'Spanish',
        'French',
        'Italian',
        'Portuguese',
        'Swedish'
    ),

    [Parameter(Mandatory=$true)]
    [string] $ItemPattern,

    [Parameter(Mandatory=$true)]
    [System.Collections.Specialized.OrderedDictionary] $DecodeMap
)


Import-Module -Name "$PSScriptRoot/../Modules/GenericTranslation"



$Params =
@{
    InputObject    = $InputObject
    SourceLanguage = $SourceLanguage
    TargetLanguage = $TargetLanguage
    ItemPattern    = $ItemPattern
    DecodeMap      = $DecodeMap

    OnGetItem = { $name, $content = $args

        $decodedContent = Convert-String $content -Mode Decode -DecodeMap $DecodeMap

        [pscustomobject]@{
            Name = $name
            Content = $decodedContent
        }
    }

    OnTranslateItem = { $item, $source, $target = $args

        $translatedContent = Invoke-StringTranslation `
            -InputObject $item.Content `
            -SourceLanguage $source `
            -TargetLanguage $target

        $encodedTranslatedContent = Convert-String $translatedContent -Mode Encode -DecodeMap $DecodeMap

        [pscustomobject]@{
            Name = $item.Name
            TranslatedContent = $encodedTranslatedContent
        }
    }
}



$translationsPerLanguage = Invoke-ItemTranslation @Params

if ($null -eq $translationsPerLanguage)
{
    Write-Host "Couldn't find any string resource in your clipboard.`n" -ForegroundColor Red
    Write-Host "Your clipboard content:`n" -ForegroundColor Green
    Write-Host (Get-Clipboard -Raw)

    while ($true)
    {
        Read-Host
    }
}

return $translationsPerLanguage