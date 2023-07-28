# By ChatGPT


function Convert-HexToRGB
{
    param
    (
        [string] $HexColor
    )

    # Remove the "#" symbol if present
    $hexColorWithoutPrefix = $HexColor -replace "#", ""

    # Parse the hex values for each color component
    $red   = [Convert]::ToInt32($hexColorWithoutPrefix.Substring(0, 2), 16)
    $green = [Convert]::ToInt32($hexColorWithoutPrefix.Substring(2, 2), 16)
    $blue  = [Convert]::ToInt32($hexColorWithoutPrefix.Substring(4, 2), 16)

    return $red, $green, $blue
}

function Convert-RGBToHex
{
    param
    (
        [int] $Red,
        [int] $Green,
        [int] $Blue
    ) 

    # Ensure RGB values are within the valid range (0-255)
    $clampedRed = [math]::Clamp($Red, 0, 255)
    $clampedGreen = [math]::Clamp($Green, 0, 255)
    $clampedBlue = [math]::Clamp($Blue, 0, 255)


    # Convert to hexadecimal format
    $hexColor = "#"
    $hexColor += $clampedRed.ToString("X2")
    $hexColor += $clampedGreen.ToString("X2")
    $hexColor += $clampedBlue.ToString("X2")

    return $hexColor
}

function Convert-ARGBToOpaqueColor
{
    param
    (
        [string] $ArgbColor,
        [string] $RgbBackgroundColor
    )

    # Extract alpha channel and RGB components from the ARGB color
    $alpha = [Convert]::ToInt32($ArgbColor.Substring(1, 2), 16)
    $red   = [Convert]::ToInt32($ArgbColor.Substring(3, 2), 16)
    $green = [Convert]::ToInt32($ArgbColor.Substring(5, 2), 16)
    $blue  = [Convert]::ToInt32($ArgbColor.Substring(7, 2), 16)

    # Convert the background color to RGB
    $backgroundRed, $backgroundGreen, $backgroundBlue = Convert-HexToRGB $RgbBackgroundColor

    # Calculate premultiplied alpha values
    $alphaFactor        = $alpha / 255.0
    $premultipliedRed   = [math]::Round($red   * $alphaFactor)
    $premultipliedGreen = [math]::Round($green * $alphaFactor)
    $premultipliedBlue  = [math]::Round($blue  * $alphaFactor)

    # Calculate opaque RGB values against the background
    $opaqueRed   = [math]::Round((1 - $alphaFactor) * $backgroundRed   + $premultipliedRed)
    $opaqueGreen = [math]::Round((1 - $alphaFactor) * $backgroundGreen + $premultipliedGreen)
    $opaqueBlue  = [math]::Round((1 - $alphaFactor) * $backgroundBlue  + $premultipliedBlue)

    # Return the resulting opaque color as an RGB tuple
    return $opaqueRed, $opaqueGreen, $opaqueBlue
}

$argbHexColorPattern = "^#[A-Fa-f0-9]{8}$"
$hexColorPattern     = "^#[A-Fa-f0-9]{6}$"

function Write-Values
{
    param
    (
        $TransparentColor,
        $BackgroundColor
    )

    Clear-Host

    if ($TransparentColor)
    {
        Write-Host "Transparent color = $TransparentColor" -ForegroundColor Cyan
    }
    if ($BackgroundColor)
    {
        Write-Host "Background color = $BackgroundColor" -ForegroundColor Cyan
    }

    Write-Host "`n`n"
}

do
{
    Write-Values

    $argbColor = Read-Host -Prompt "Transparent color (e.g. #AA112233)"

    $inputMatches = Select-String -InputObject $argbColor -Pattern $argbHexColorPattern
}
while (-not $inputMatches)

Write-Values -TransparentColor $argbColor

do
{
    Write-Values -TransparentColor $argbColor

    $rgbBackgroundColor = Read-Host -Prompt "Background color (e.g. #112233)"

    $inputMatches = Select-String -InputObject $rgbBackgroundColor  -Pattern $hexColorPattern
}
while (-not $inputMatches)

Write-Values -TransparentColor $argbColor -BackgroundColor $rgbBackgroundColor


$opaqueRgb = Convert-ARGBToOpaqueColor -ArgbColor $argbColor -RgbBackgroundColor $rgbBackgroundColor
$red, $green, $blue = $opaqueRgb
$opaqueHexColor = Convert-RGBToHex -Red $red -Green $green -Blue $blue
$colorLink = "https://google.com/search?q=$([uri]::EscapeDataString($opaqueHexColor))"

Write-Host "The opaque version of $argbColor is $opaqueHexColor." -ForegroundColor Green
Set-Clipboard -Value $opaqueHexColor
Write-Host "It's copied into your clipboard!"
Write-Host "See your color (press Enter to see the color): $colorLink" -ForegroundColor Cyan


while ($true)
{
    Read-Host

    Start-Process $colorLink
}

