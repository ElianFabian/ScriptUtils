$Params =
@{
    InputObject = (Get-Clipboard -Raw)

    ItemPattern = '<string name="(?<Key>.+)">(?<Value>.+)<\/string>'

    DecodeMap = [ordered] @{
        "\'"    = "'"
        '&lt;'  = '<'
        '&amp;' = '&'
        "\n"    = [System.Environment]::NewLine
        #"\t"    = "`t"
    }
}


& "$PSScriptRoot\..\BaseFunctions\@BaseGet-StringResourceTranslationObject.ps1" @Params