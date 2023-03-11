# Translation.psm1



$global:languagesCsv = ConvertFrom-Csv -InputObject ( Get-Content "$PSScriptRoot/Languages.csv" -Raw )

$languageToCode = @{}
$codeToLanguage = @{}
foreach($row in $global:languagesCsv)
{
    $languageToCode[$row.Language] = $row.Code
    $codeToLanguage[$row.Code] = $row.Language
}

class Language : System.Management.Automation.IValidateSetValuesGenerator
{
    [String[]] GetValidValues()
    {
        $languages = $global:languagesCsv | ForEach-Object { $_.Language }
        $codes     = $global:languagesCsv | ForEach-Object { $_.Code }

        return $languages + $codes
    }
}



<#
    .DESCRIPTION
    A function that uses the free Google Translate API to retrieve Datarmation.

    .PARAMETER InputObject
    Text to translate or get some type of Datarmation depending on the ReturnType parameter.

    .PARAMETER SourceLanguage
    Source language as code or English.

    .PARAMETER TargetLanguage
    Target language as code or English.

    .PARAMETER ReturnType
    The type of Dataration to return, it can be any of these:

    [Translation, Alternative, LanguageDetection, LanguageDetectionAsEnglishWord, Dictionary, Definition, Synonym, Example]

    .NOTES
    This function uses the free google translate API, if you try doing parallelism it will block.
#>
function Invoke-GoogleTranslate(
    [Parameter(Mandatory=$true)]
    [string] $InputObject,
    [ValidateSet([Language])]
    [Alias('From')]
    [string] $SourceLanguage = 'auto',
    [ValidateSet([Language])]
    [Alias('To')]
    [string] $TargetLanguage,
    [ValidateSet('Translation', 'Alternative', 'LanguageDetection', 'LanguageDetectionAsEnglishWord', 'Dictionary', 'Definition', 'Synonym', 'Example')]
    [string] $ReturnType = 'Translation'
) {
    if ($ListOfSingleWordReturnType.Contains($ReturnType) -and ($InputObject.Trim().Contains(' ') -or $InputObject.Trim().Contains("`n")))
    {
        Write-Error "The return type '$ReturnType' only works for single words, your input is '$InputObject'."
    }
    if ($ListReturnTypeThatTheTargetLanguageIsRequired.Contains($ReturnType) -and -not $TargetLanguage)
    {
        Write-Error "You must specify a the TargetLanguage if the ReturnType is '$ReturnType'."
    }

    $sourceLanguageCode, $targetLanguageCode = TryConvertLanguageToCode $SourceLanguage $TargetLanguage

    $returnTypeAsQueryParameter = GetReturnTypeAsQueryParameter -ReturnType $ReturnType

    $query = if ($ReturnType -eq 'Example')
    {
        # 'Example' does not work if there are capital letters
        [uri]::EscapeDataString($InputObject.ToLower())
    }
    else { [uri]::EscapeDataString($InputObject) }

    $uri = "https://translate.googleapis.com/translate_a/single?client=gtx&dj=1&sl=$sourceLanguageCode&tl=$targetLanguageCode&dt=t&q=$query&dt=$returnTypeAsQueryParameter"

    $response = Invoke-WebRequest -Uri $uri -Method Get

    Write-Verbose -Message $response.Content -Verbose:$VerbosePreference

    $data = $response.Content | ConvertFrom-Json

    $result = switch ($ReturnType)
    {
        LanguageDetection { $data.src }
        LanguageDetectionAsEnglishWord { $codeToLanguage[$data.src] }
        Translation { $data.sentences | Select-Object -ExpandProperty trans | Join-String }
        Alternative
        {
            [PSCustomObject]@{
                SourceLanguage = $data.src
                AlternativesPerLine = $data.alternative_translations
                    | Where-Object { $null -ne $_.alternative }
                    | Group-Object { $_.src_phrase }
                    | ForEach-Object { 
                        [PSCustomObject]@{
                            SourceLine = $_.Name
                            TranslationAlternatives = @($_.Group[0].alternative | ForEach-Object { $_.word_postproc })
                        }
                    }
            }
        }
        Dictionary
        {
            [PSCustomObject]@{
                SourceLanguage = $data.src
                Dictionary = $data.dict | ForEach-Object { 
                    [PSCustomObject]@{
                        WordClass = $_.pos
                        Terms = $_.terms
                        Entries = foreach ($wordData in $_.entry)
                        {
                            [PSCustomObject]@{
                                Word = $wordData.word
                                ReverseTranslations = $wordData.reverse_translation
                                Score = $wordData.score
                            }
                        }
                    }
                }
            }
        }
        Definition 
        { 
            [PSCustomObject]@{
                SourceLanguage = $data.src
                Definitions = foreach ($definitionData in $data.definitions)
                {
                    [PSCustomObject]@{
                        WordClass = $definitionData.pos
                        Glossary = @($definitionData.entry | Select-Object -ExpandProperty gloss)
                    }
                }
            }
        }
        Synonym
        { 
            [PSCustomObject]@{
                SourceLanguage = $data.src
                Translation = $data.sentences.trans
                SynonymSets = foreach ($set in $data.synsets)
                {
                    [PSCustomObject]@{
                        WordClass = $set.pos
                        SynonymGroups = foreach ($synonymData in $set.entry)
                        {
                            [PSCustomObject]@{
                                Register = $synonymData.label_inforegister
                                Synonyms = @($synonymData.synonym)
                            }
                        }
                    }
                }
            }
        }
        Example
        {
            [PSCustomObject]@{
                SourceLanguage = $data.src
                Translation = $data.sentences.trans
                Examples = @($data.examples[0] | Select-Object -ExpandProperty example | Select-Object -ExpandProperty text)
            }
        }
    }

    return $result
}

function TryConvertLanguageToCode([string] $SourceLanguage, [string] $TargetLanguage)
{
    $languageCodes = @($SourceLanguage, $TargetLanguage)

    if ($languageToCode.ContainsKey($SourceLanguage))
    {
        $languageCodes[0] = $languageToCode[$SourceLanguage]
    }
    if ($languageToCode.ContainsKey($TargetLanguage))
    {
        $languageCodes[1] = $languageToCode[$TargetLanguage]
    }

    return $languageCodes
}

# https://wiki.freepascal.org/Using_Google_Translate
function GetReturnTypeAsQueryParameter($ReturnType)
{
    $result = switch ($ReturnType)
    {
        Translation { 't' }
        Alternative { 'at' }
        Dictionary { 'bd' }
        Definition { 'md' }
        Synonym { 'ss' }
        Example { 'ex' }

        default { Write-Warning "Unexpected ReturnType value '$ReturnType'" }
    }

    return $result
}

$ListOfSingleWordReturnType = @('Definition', 'Synonym', 'Example')
$ListReturnTypeThatTheTargetLanguageIsRequired = @('Translation', 'Alternative', 'Dictionary', 'Example')



Export-ModuleMember -Function *-*