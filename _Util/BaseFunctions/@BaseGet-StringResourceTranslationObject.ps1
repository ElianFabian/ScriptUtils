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

    OnGetItem = { param($key, $value)

        $decodedValue = Convert-String $value -DecodeMap $DecodeMap -Mode Decode

        [pscustomobject]@{
            Key = $key
            Value = $decodedValue
        }
    }

    OnTranslateItem = { $item, $source, $target = $args

        $result = Invoke-StringTranslation `
            -InputObject $item.Value `
            -SourceLanguage $source `
            -TargetLanguage $target

        $encodedTranslatedValue = if ($result.IsError)
        {
            $result.Message
        }
        else
        {
            Convert-String $result.Data -DecodeMap $DecodeMap -Mode Encode
        }

        [pscustomobject]@{
            Key = $item.Key
            TranslatedValue = $encodedTranslatedValue
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