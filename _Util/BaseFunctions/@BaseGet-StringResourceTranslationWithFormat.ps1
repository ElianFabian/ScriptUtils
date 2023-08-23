param
(
    [Parameter(Mandatory=$true)]
    [pscustomobject] $TranslationsPerLanguage,

    [Parameter(Mandatory=$true)]
    [scriptblock] $GetHeader = { param([string] $targetLanguage)

    },

    [Parameter(Mandatory=$true)]
    [scriptblock] $GetStringResource = { param([string] $key, [string] $value)

    }
)



Write-Host "Reading from clipboard...`n" -ForegroundColor Green



$targetLanguageIndex = 0
$translationsWithFormat = New-Object pscustomobject[] $TranslationsPerLanguage.Count
foreach ($data in $TranslationsPerLanguage)
{
    $translationsPerLanguageWithFormat = [PSCustomObject]@{
       Header   = (& $GetHeader -targetLanguage $data.Language)
       Code     = $data.Code
       Language = $data.Language
       Translations = foreach ($stringResourceData in $data.Translations)
       {
           (& $GetStringResource -key $stringResourceData.Key -value $stringResourceData.TranslatedValue)
       }
    }

    $translationsWithFormat[$targetLanguageIndex] = $translationsPerLanguageWithFormat

    $targetLanguageIndex++
}



return $translationsWithFormat