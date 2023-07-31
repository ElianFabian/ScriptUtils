
function Get-BaseStringResourceFileFormat
{
    param
    (
        [string] $BaseStringResourceFileContent,
        [string] $TargetStringResourceFileContent
    )

    $baseLines           = $BaseStringResourceFileContent.Split("`n")
    $targetContentByName = Get-TargetContentByName $TargetStringResourceFileContent

    $targetLinesList = [System.Collections.Generic.List[string]] $baseLines
    $indexesToRemove = [System.Collections.Generic.List[int]]::new()

    $index = 0
    foreach ($line in $baseLines)
    {
        $stringResource = ConvertTo-XmlOrNull $line

        if (-not $stringResource)
        {
            $index++
            continue
        }

        $translatable = [string] $stringResource.translatable

        if ($translatable -eq "false")
        {
            $indexesToRemove.Add($index++)
            continue
        }

        $name          = $stringResource.name
        $targetContent = $targetContentByName.$name
        $indentation   = ' ' * (Get-NumberOfLeadingSpaces $line)

        $targetLinesList[$index] = "$indentation<string name=""$name"">$targetContent</string>"

        $index++
    }

    foreach ($indexToRemove in $indexesToRemove)
    {
        $targetLinesList.RemoveAt($indexToRemove)
    }

    # TODO: Improve this part to always guarantee that there is no extra blank lines
    if ([string]::IsNullOrWhiteSpace($targetLinesList[2]))
    {
        $targetLinesList.RemoveAt(2)
    }

    return $targetLinesList -join [System.Environment]::NewLine
}

function ConvertTo-XmlOrNull
{
    param
    (
        [string] $Text
    )

    try
    {
        $stringResourceNode = [xml] $Text

        if (-not $stringResourceNode.string)
        {
            return $null
        }

        return $stringResourceNode.ChildNodes[0]
    }
    catch { return $null}
}

function Get-TargetContentByName
{
    param
    (
        [string] $TargetContent
    )

    $xml = [xml] $TargetContent

    $root = $xml.ChildNodes[1]

    $stringResources = $root.ChildNodes

    $targetContentByName = @{}

    foreach ($stringResource in $stringResources)
    {
        $name    = $stringResource.name
        $content = $stringResource.InnerText

        $targetContentByName.$name = $content
    }

    return $targetContentByName
}

function Get-NumberOfLeadingSpaces
{
    param
    (
        [string] $InputObject
    )

    $leadingSpaces = 0
    foreach ($char in $InputObject.ToCharArray())
    {
        if ($char -eq ' ')
        {
            $leadingSpaces++
        }
        else { break }
    }

    return $leadingSpaces
}