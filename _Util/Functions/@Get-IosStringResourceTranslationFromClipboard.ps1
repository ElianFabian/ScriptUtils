$Params =
@{
    InputObject = (Get-Clipboard -Raw)

    ItemPattern = '"(?<Key>.+)" = "(?<Value>.+)";'

    DecodeMap = [ordered] @{
        "\'" = "'"
        '\"' = '"'
        "\n" = [System.Environment]::NewLine
        "\\" = "\"
    }
}



& "$PSScriptRoot\..\BaseFunctions\@BaseGet-StringResourceTranslationObject.ps1" @Params