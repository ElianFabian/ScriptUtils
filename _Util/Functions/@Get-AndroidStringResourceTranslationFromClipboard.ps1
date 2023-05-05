$Params =
@{
    InputObject = (Get-Clipboard -Raw)

    ItemPattern = '<string name="(.+)">(.+)<\/string>'

    DecodeMap = [ordered] @{
        "\'"    = "'"
        '&lt;'  = '<'
        '&amp;' = '&'
        "\n"    = [System.Environment]::NewLine
    }
}


& "$PSScriptRoot\..\BaseFunctions\@BaseGet-StringResourceTranslationObject.ps1" @Params