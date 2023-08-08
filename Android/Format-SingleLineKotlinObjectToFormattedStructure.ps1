<#
This script receives a kotlin object string like this:
Person(name='John Doe', age=30)

And returns the same but with format:
Person(
    name='John Doe',
    age=30
)
#>


function ConvertTo-StructuredKotlinObjectString
{
    param
    (
        [string] $InputObject,
        [int] $IndentationLevel = 4
    )

    $NewLine = [System.Environment]::NewLine

    $objectAsSingleLineString = $InputObject
    $outputSb = [System.Text.StringBuilder]::new()

    $currentIndentationLevel = 0

    $singleQuoteCount = 0
    for ($charIndex = 0; $charIndex -lt $objectAsSingleLineString.Length; $charIndex++)
    {
        $previousChar = $charIndex -gt 0 ? $objectAsSingleLineString[$charIndex - 1] : $null
        $currentChar = $objectAsSingleLineString[$charIndex]
        $nextChar = $charIndex -lt $objectAsSingleLineString.Length ? $objectAsSingleLineString[$charIndex + 1] : $null
        
        if ($currentChar -eq "'" -and $previousChar -ne "\")
        {
            $singleQuoteCount++
        }

        $isBetweenSingleQuotes = $singleQuoteCount % 2 -eq 1

        if ($isBetweenSingleQuotes)
        {
            $outputSb.Append($currentChar) > $null
            continue
        }

        switch ($currentChar)
        {
           { $_ -in '(', '[' }
            {
                $outputSb.Append($currentChar) > $null
                $currentIndentationLevel += $IndentationLevel

                if (($currentChar -eq "[" -and $nextChar -ne "]") -or ($currentChar -eq "(" -and $nextChar -ne ")"))
                {
                   $outputSb.Append($NewLine + (" " * $currentIndentationLevel)) > $null
                }
            }
            { $_ -in ')', ']' }
            {
                if ($currentIndentationLevel - $IndentationLevel -ge 0)
                {
                    $currentIndentationLevel -= $IndentationLevel
                }

                if ($previousChar -ne "[")
                {
                    $outputSb.Append($NewLine + (" " * $currentIndentationLevel)) > $null
                }
                $outputSb.Append($currentChar) > $null
            }
            ','
            {
                $outputSb.Append("$currentChar$NewLine$(" " * $currentIndentationLevel)") > $null
            }
            default
            {
                if (-not ($currentChar -eq " " -and $previousChar -eq  ","))
                {
                    $outputSb.Append($currentChar) > $null
                }
            }
        }
    }

    return $outputSb.ToString()
}

Clear-Host

$singleLineKotlinObject = Get-Clipboard -Raw

$output = ConvertTo-StructuredKotlinObjectString $singleLineKotlinObject


$exampleInput = "Person(name='John Doe', age=30)"
$exampleOutput = @"
Person(
    name='John Doe',
    age=30
)
"@

Write-Host "Example input:"
Write-Host $exampleInput -ForegroundColor Yellow
Write-Host
Write-Host "Example output:"
Write-Host $exampleOutput -ForegroundColor Yellow

Write-Host "`n`n`n" -NoNewline

Write-Host "Your input:"
Write-Host $singleLineKotlinObject -ForegroundColor Green
Write-Host
Write-Host "The output:"
Write-Host $output -ForegroundColor Cyan

while ($true)
{
    Read-Host
}