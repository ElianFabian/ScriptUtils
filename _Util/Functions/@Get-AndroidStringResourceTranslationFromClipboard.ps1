$Params =
@{
    InputObject = (Get-Clipboard -Raw)

    ItemPattern = '<string name="(.+)">(.+)<\/string>'

    DecodeMap =
    @{
        "\'"    = "'"
        '&amp;' = '&'
        '&gt;'  = '>'
        '&lt;'  = '<'
        "\n"    = [System.Environment]::NewLine
    }
}


& "$PSScriptRoot\..\BaseFunctions\@BaseGet-StringResourceTranslationObject.ps1" @Params