$Params =
@{
    InputObject = (Get-Clipboard -Raw)

    ItemPattern = '"(.+)" = "(.+)";'

    DecodeMap = 
    @{
        "\'" = "'"
        '\"' = '"'
        "\n" = [System.Environment]::NewLine
        "\\" = "\"
    }
}



& "$PSScriptRoot\..\BaseFunctions\@BaseGet-StringResourceTranslationObject.ps1" @Params