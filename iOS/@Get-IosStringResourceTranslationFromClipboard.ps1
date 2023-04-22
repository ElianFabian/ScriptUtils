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

    DecodeMap = 
    @{
        "\'" = "'"
        '\"' = '"'
        "\\" = "\"
        "\n" = [System.Environment]::NewLine
    }
}



return Invoke-ItemTranslation @Params
