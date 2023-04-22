Import-Module -Name "$PSScriptRoot/../Modules/GenericTranslation"



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
    ItemPattern = '"(.+)" = "(.+)";'
}

$DecodeMap = 
@{
    "\'" = "'"
    '\"' = '"'
    "\\" = "\"
    "\n" = [System.Environment]::NewLine
}


return Invoke-ItemTranslation @Params `
    -OnGetItem { $name, $content = $args

        $decodedContent = Convert-String $content -Mode Decode -DecodeMap $DecodeMap

        [pscustomobject]@{
            Name = $name
            Content = $decodedContent
        }
    } `
    -OnTranslateItem { $item, $source, $target = $args

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
