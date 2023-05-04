Import-Module -Name DeeplTranslate -Force

if (-not (Get-Module -Name DeeplTranslate))
{
     Write-Error "The DeeplTranslate module is not installed, execute this command 'Install-Module -Name DeeplTranslate -Force' in your PowerShell console to be able to use the DeepL API."

     while ($true) { $true } 
}

$script:SourceLanguagesCsv = ConvertFrom-Csv -InputObject (Get-Content "$PSScriptRoot/SourceLanguages.csv" -Raw)
$script:TargetLanguagesCsv = ConvertFrom-Csv -InputObject (Get-Content "$PSScriptRoot/TargetLanguages.csv" -Raw)

$LanguageToCode = @{}
$CodeToLanguage = @{}

foreach ($row in $script:SourceLanguagesCsv)
{
    $LanguageToCode[$row.Language] = $row.Code
    $CodeToLanguage[$row.Code] = $row.Language
}
foreach ($row in $script:TargetLanguagesCsv)
{
    $LanguageToCode[$row.Language] = $row.Code
    $CodeToLanguage[$row.Code] = $row.Language
}

$script:pairOfSourceLanguageAndCode = $script:SourceLanguagesCsv | ForEach-Object { $_.Language, $_.Code }
$script:pairOfTargetLanguageAndCode = $script:TargetLanguagesCsv | ForEach-Object { $_.Language, $_.Code } 

class SourceLanguage : System.Management.Automation.IValidateSetValuesGenerator
{
    [String[]] GetValidValues()
    {
        return $script:pairOfSourceLanguageAndCode
    }
}

class TargetLanguage : System.Management.Automation.IValidateSetValuesGenerator
{
    [String[]] GetValidValues()
    {
        return $script:pairOfTargetLanguageAndCode
    }
}


$DeeplApiKey = '3329b827-c3f9-79a3-1d77-6d7f1694e42c:fx'


<#
    .PARAMETER InputObject
    Text to translate or word that can be treated differently depending on the value of the ReturnType parameter.

    .PARAMETER SourceLanguage
    Source language as code or English word.

    .PARAMETER TargetLanguage
    Target language as code or English word.

    .PARAMETER AvailableLanguages
    Return an array with all the available languages with the English name and language code.

    .OUTPUTS
    PSCustomObject
    PSCustomObject[]
#>
function Invoke-Deepl
{
    [OutputType([PSCustomObject], [PSCustomObject[]])]
    param
    (
        [Alias('Query')]
        [Parameter(Mandatory=$true, ParameterSetName='Translation')]
        [string] $InputObject,

        [Alias('From')]
        [ValidateSet([SourceLanguage])]
        [Parameter(ParameterSetName='Translation')]
        [string] $SourceLanguage = $null,

        [Alias('To')]
        [ValidateSet([TargetLanguage])]
        [Parameter(ParameterSetName='Translation')]
        [string] $TargetLanguage,

        [Parameter(ParameterSetName='AvailableSourceLanguages')]
        [switch] $AvailableSourceLanguages,

        [Parameter(ParameterSetName='AvailableTargetLanguages')]
        [switch] $AvailableTargetLanguages
    )

    if ($AvailableSourceLanguages)
    {
        return $script:SourceLanguagesCsv
    }
    if ($AvailableTargetLanguages)
    {
        return $script:TargetLanguagesCsv
    }

    $sourceLanguageCode, $targetLanguageCode = TryConvertLanguageToCode $SourceLanguage $TargetLanguage

    $response = Invoke-DeeplTranslateText `
        -ApiKey $DeeplApiKey `
        -TextToTranslate $InputObject `
        -SourceLanguage $sourceLanguageCode `
        -TargetLanguage $targetLanguageCode `
        -Formality less
    
    return $response.TargetText
}



function TryConvertLanguageToCode([string] $SourceLanguage, [string] $TargetLanguage)
{
    $languageCodes = @($SourceLanguage, $TargetLanguage)

    if ($LanguageToCode.ContainsKey($SourceLanguage))
    {
        $languageCodes[0] = $LanguageToCode[$SourceLanguage]
    }
    if ($LanguageToCode.ContainsKey($TargetLanguage))
    {
        $languageCodes[1] = $LanguageToCode[$TargetLanguage]
    }

    return $languageCodes
}



Export-ModuleMember -Function *-*
