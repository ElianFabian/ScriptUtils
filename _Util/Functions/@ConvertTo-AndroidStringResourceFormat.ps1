param
(
    [Parameter(Mandatory=$true)]
    [pscustomobject[]] $TranslationsPerLanguage
)


$Params =
@{
    TranslationsPerLanguage = $TranslationsPerLanguage

    GetHeader = { param([string] $targetLanguage)
        "<!-- $targetLanguage -->"
    }

    GetStringResource = { param([string] $key, [string] $value)
        "<string name=""$key"">$value</string>"
    }
}



& "$PSScriptRoot\..\BaseFunctions\@BaseGet-StringResourceTranslationWithFormat.ps1" @Params