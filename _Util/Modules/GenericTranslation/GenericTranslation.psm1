Import-Module -Name @(
        "$PSScriptRoot/../PSMyMemory",
        "$PSScriptRoot/../PSDeepl",
        "$PSScriptRoot/../PSGoogleTranslate"
    )



$script:allLanguages = Invoke-GoogleTranslate -AvailableLanguages

$script:DeeplTargetLanguages = Invoke-Deepl -AvailableTargetLanguages | ForEach-Object { @($_.Language, $_.Code) }

$LanguageToCode = @{}
foreach ($row in $script:allLanguages)
{
    $LanguageToCode[$row.Language] = $row.Code
}


function Invoke-StringTranslation
{
    param
    (
        [string] $InputObject,
        [string] $SourceLanguage,
        [string] $TargetLanguage
    )

    if ([string]:: IsNullOrWhiteSpace($InputObject))
    {
        return $InputObject
    }

    if ($TargetLanguage -in $DeeplTargetLanguages)
    {
        $translation = Invoke-Deepl `
            -InputObject $InputObject `
            -SourceLanguage $SourceLanguage `
            -TargetLanguage $TargetLanguage

        if ($translation)
        {
            return @{
                IsError = $false
                Data = $translation.Trim()
            }
        }
    }

    $response = Invoke-GoogleTranslate `
        -InputObject $InputObject `
        -SourceLanguage $SourceLanguage `
        -TargetLanguage $TargetLanguage

    if (-not $response.Translation)
    {
        $deeplLink           = GenerateDeeplLink @PSBoundParameters
        $googleTranslateLink = GenerateGoogleTranslateLink @PSBoundParameters

        return @{
            IsError = $true
            Message = "`n    Couldn't translate. Please, try these alternatives:`n`n    $deeplLink`n    $googleTranslateLink`n"
        }
    }

    return @{
        IsError = $false
        Data = $response.Translation.Trim()
    }
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
        -ItemPattern '<string name="(?<Key>.+)">(?<Value>.+)<\/string>' `
        -OnGetItem { $key, $value = $args
            "$key = ""$value"""
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

        $key   = $match.Groups["Key"]
        $value = $match.Groups["Value"]

        $newItem = $OnGetItem.Invoke($key, $value)

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
        [System.Collections.Specialized.OrderedDictionary] $DecodeMap
    )

    $decodedString = $InputObject
    $mapWithRightOrder = switch ($Mode)
    {
        Decode { $DecodeMap }
        Encode { GetReversedHashtable $DecodeMap }
    }

    foreach ($pair in $mapWithRightOrder.GetEnumerator())
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

function GetReversedHashtable
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [System.Collections.Specialized.OrderedDictionary]$Hashtable
    )

    $reversedHashtable = [ordered]@{}
    for ($i = $Hashtable.Keys.Count - 1; $i -ge 0; $i--) {
        $key = $Hashtable.Keys[$i]
        $value = $Hashtable[$key]
        $reversedHashtable[$key] = $value
    }
    return $reversedHashtable
}


$script:CurrentTranslatedItemsCount = 0
$script:StartTimeInUnixTimeSeconds = $null

function ShowTranslationProgress([int] $TotalItemCount)
{
    if ($null -eq $StartTimeInUnixTimeSeconds)
    {
        $script:StartTimeInUnixTimeSeconds = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    }

    $script:CurrentTranslatedItemsCount++

    [double] $currentTimeSinceStart = ([System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $script:StartTimeInUnixTimeSeconds)
    [double] $translationsPerSecond = $script:CurrentTranslatedItemsCount / $currentTimeSinceStart
    [int]    $timeLeft              = ($TotalItemCount - $script:CurrentTranslatedItemsCount) / $translationsPerSecond

    $percentComplete                = [math]::Round($script:CurrentTranslatedItemsCount / $TotalItemCount * 100)
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
        [System.Collections.Specialized.OrderedDictionary] $DecodeMap,

        [Parameter(Mandatory=$true)]
        [scriptblock] $OnGetItem,

        [Parameter(Mandatory=$true)]
        [scriptblock] $OnTranslateItem
    )

    $script:CurrentTranslatedItemsCount = 0
    $script:StartTimeInUnixTimeSeconds = $null


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
            Language = $targetLanguageItem
            Code = $LanguageToCode[$targetLanguageItem]
            Translations = $listOfTranslatedItems
        }

        $languageIndex++
    }

    return $itemsPerTargetLanguage
}



Export-ModuleMember -Function *-*
