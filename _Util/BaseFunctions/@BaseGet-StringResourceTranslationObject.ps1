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
    [hashtable] $DecodeMap
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



return Invoke-ItemTranslation @Params