Import-Module -Name @(
        "$PSScriptRoot/../PSGoogleTranslate",
        "$PSScriptRoot/../PSMyMemory"
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

    # The Google Translate API stop working propertly
    # $response = Invoke-GoogleTranslate `
    #     -InputObject $item.Content `
    #     -SourceLanguage $SourceLanguage `
    #     -TargetLanguage $TargetLanguage

    $response = Invoke-MyMemory `
        -InputObject $item.Content `
        -SourceLanguage $SourceLanguage `
        -TargetLanguage $TargetLanguage


    $translation = $response.Translation
   

    return $translation.Trim()
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
        [scriptblock] $OnGetItem,

        [Parameter(Mandatory=$true, ParameterSetName='Count')]
        [switch] $Count
    )

    $allMatches = $InputObject | Select-String -Pattern $ItemPattern -AllMatches | Select-Object -ExpandProperty Matches

    if ($Count)
    {
        return $allMatches.Count
    }

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

        [scriptblock] $OnGetItem,

        [Parameter(Mandatory=$true)]
        [string] $SourceLanguage,

        [Parameter(Mandatory=$true)]
        [string[]] $TargetLanguage,

        [Parameter(Mandatory=$true)]
        [scriptblock] $OnTranslateItem
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
