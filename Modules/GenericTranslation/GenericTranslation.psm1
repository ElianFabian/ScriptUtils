Import-Module -Name @(
        "$PSScriptRoot/../PSMyMemory",
        "$PSScriptRoot/../PSDeepl",
        "$PSScriptRoot/../PSGoogleTranslate"
    )



$global:allLanguages = Invoke-MyMemory -AvailableLanguages

$LanguageToCode = @{}
foreach ($row in $global:allLanguages)
{
    $LanguageToCode[$row.Language] = $row.LanguageCode
}


function Invoke-StringTranslation
{
    param
    (
        [string] $InputObject,
        [string] $SourceLanguage,
        [string] $TargetLanguage
    )

    # The Google Translate API sometimes doesn't work
    # $response = Invoke-GoogleTranslate `
    #     -InputObject $InputObject `
    #     -SourceLanguage $SourceLanguage `
    #     -TargetLanguage $TargetLanguage
    
    # return $response.Translation.Trim()

    if ($TargetLanguage -ne 'Catalan')
    {
        $translation = Invoke-Deepl `
            -InputObject $InputObject `
            -SourceLanguage $SourceLanguage `
            -TargetLanguage $TargetLanguage

        if ($translation)
        {
            return $translation.Trim()
        }
    }

    $response = Invoke-MyMemory `
        -InputObject $InputObject `
        -SourceLanguage $SourceLanguage `
        -TargetLanguage $TargetLanguage

    if (-not $response.Translation)
    {
        $deeplLink           = GenerateDeeplLink @PSBoundParameters
        $googleTranslateLink = GenerateGoogleTranslateLink @PSBoundParameters

        return "`n    Translation limit exceeded, try these alternatives:`n`n    $deeplLink`n    $googleTranslateLink`n    "
    }

    return $response.Translation.Trim()
}

function GenerateGoogleTranslateLink
{
    param
    (
        [string] $InputObject,
        [string] $SourceLanguage,
        [string] $TargetLanguage
    )

    $sourceLanguageCode = $LanguageToCode[$SourceLanguage]
    $targetLanguageCode = $LanguageToCode[$TargetLanguage]

    $encodedQuery = [uri]::EscapeDataString($InputObject)

    return "https://translate.google.es/?sl=$sourceLanguageCode&tl=$targetLanguageCode&text=$encodedQuery"
}

function GenerateDeeplLink
{
    param
    (
        [string] $InputObject,
        [string] $SourceLanguage,
        [string] $TargetLanguage
    )

    $sourceLanguageCode = $LanguageToCode[$SourceLanguage]
    $targetLanguageCode = $LanguageToCode[$TargetLanguage]

    $encodedQuery = [uri]::EscapeDataString($InputObject)

    return "https://www.deepl.com/es/translator#$sourceLanguageCode/$targetLanguageCode/$encodedQuery"
}

<#
    .SYNOPSIS
    Given a string returns an array of every item using a pattern to convert it into another string with items.
    .PARAMETER InputObject
    A string of items that matches a certain pattern.
    .PARAMETER ItemPattern
    The pattern to match each item of the given InputObject. 
    .PARAMETER OnGetItem
    An script block which $args contains all the groups defined in $ItemPattern and returns an item as string.
    .EXAMPLE
    Get-ItemFromStringWithRegex `
        -InputObject @"
        <string name="name">Alice</string>
        <string name="age">25</string>
    "@ `
        -ItemPattern '<string name="(.+)">(.+)<\/string>' `
        -OnGetItem { $name, $content = $args  
            "$name = ""$content"""
        }
    output:
        name = "Alice"
        age = "25"
#>
function Get-ItemFromStringWithRegex
{
    [OutputType([object[]], ParameterSetName='Normal')]
    [OutputType([int], ParameterSetName='Count')]
    param
    (
        [Parameter(Mandatory=$true, ParameterSetName='Normal')]
        [Parameter(Mandatory=$true, ParameterSetName='Count')]
        [string] $InputObject,

        [Parameter(Mandatory=$true, ParameterSetName='Normal')]
        [Parameter(Mandatory=$true, ParameterSetName='Count')]
        [string] $ItemPattern,

        [Parameter(Mandatory=$true, ParameterSetName='Normal')]
        [scriptblock] $OnGetItem
    )

    $allMatches = $InputObject | Select-String -Pattern $ItemPattern -AllMatches | Select-Object -ExpandProperty Matches

    $arrayOfItems = New-Object object[] $allMatches.Count

    $itemIndex = 0
    foreach ($match in $allMatches)
    {
        $_first, $groups = foreach ($group in $match.Groups) { $group.Value }

        $newItem = $OnGetItem.Invoke($groups)

        $arrayOfItems[$itemIndex] = $newItem

        $itemIndex++
    }

    return $arrayOfItems
}

function Convert-String
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $InputObject,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Encode', 'Decode')]
        [string] $Mode,

        [Parameter(Mandatory=$true)]
        [hashtable] $DecodeMap
    )

    $decodedString = $InputObject

    foreach ($pair in $DecodeMap.GetEnumerator())
    {
        $encodedValue = $pair.Key
        $decodedValue = $pair.Value

        $decodedString = switch ($Mode)
        {
            Encode { $decodedString.Replace($decodedValue, $encodedValue) }
            Decode { $decodedString.Replace($encodedValue, $decodedValue) }
        }
    }
    return $decodedString
}

$global:CurrentTranslatedItemsCount = 0
$global:StartTimeInUnixTimeSeconds = $null

function ShowTranslationProgress([int] $TotalItemCount)
{
    if ($null -eq $StartTimeInUnixTimeSeconds)
    {
        $global:StartTimeInUnixTimeSeconds = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    }

    $global:CurrentTranslatedItemsCount++

    [double] $currentTimeSinceStart = ([System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $global:StartTimeInUnixTimeSeconds)
    [double] $translationsPerSecond = $global:CurrentTranslatedItemsCount / $currentTimeSinceStart
    [int]    $timeLeft              = ($TotalItemCount - $global:CurrentTranslatedItemsCount) / $translationsPerSecond

    $percentComplete                = [math]::Round($global:CurrentTranslatedItemsCount / $TotalItemCount * 100)
    $timeLeftInSeconds              = ([timespan]::FromSeconds($timeLeft) -f '')
    $currentTimeSinceStartInSeconds = ([timespan]::FromSeconds($currentTimeSinceStart) -f '')

    Write-Progress `
        -Activity "Time: $currentTimeSinceStartInSeconds | Time left: $timeLeftInSeconds | Velocity: $('{0:0}' -f $translationsPerSecond)" `
        -Status "$($percentComplete)%" `
        -PercentComplete $percentComplete
}

function Invoke-ItemTranslation
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $InputObject,

        [Parameter(Mandatory=$true)]
        [string] $ItemPattern,

        [Parameter(Mandatory=$true)]
        [string] $SourceLanguage,

        [Parameter(Mandatory=$true)]
        [string[]] $TargetLanguage,

        [Parameter(Mandatory=$true)]
        [hashtable] $DecodeMap,

        [scriptblock] $OnGetItem = { $name, $content = $args

            $decodedContent = Convert-String $content -Mode Decode -DecodeMap $DecodeMap
    
            [pscustomobject]@{
                Name = $name
                Content = $decodedContent
            }
        },

        [scriptblock] $OnTranslateItem = { $item, $source, $target = $args

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
    )

    $itemsPerTargetLanguage = New-Object object[] $TargetLanguage.Count

    $parsedItems = Get-ItemFromStringWithRegex `
        -InputObject $InputObject `
        -ItemPattern $ItemPattern `
        -OnGetItem $OnGetItem

    if ($parsedItems.Count -eq 0)
    {
        return $null
    }

    $totalItemCountForAllTargetLanguages = $parsedItems.Count * $TargetLanguage.Count

    $languageIndex = 0
    foreach ($targetLanguageItem in $TargetLanguage)
    {
        $listOfTranslatedItems = New-Object object[] $parsedItems.Count

        $parsedItemIndex = 0
        foreach ($item in $parsedItems)
        {
            $tranlatedItem = $OnTranslateItem.Invoke($item, $SourceLanguage, $targetLanguageItem)[0]

            ShowTranslationProgress -TotalItemCount $totalItemCountForAllTargetLanguages

            $listOfTranslatedItems[$parsedItemIndex] = $tranlatedItem

            $parsedItemIndex++
        }

        $itemsPerTargetLanguage[$languageIndex] =
        @{
            LanguageName = $targetLanguageItem
            LanguageCode = $LanguageToCode[$targetLanguageItem]
            Translations = $listOfTranslatedItems
        }

        $languageIndex++
    }

    return $itemsPerTargetLanguage
}



Export-ModuleMember -Function *-*
