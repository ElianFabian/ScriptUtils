# From: https://stackoverflow.com/a/9733420/18418162
# Learn more in: https://m3.material.io/foundations/designing/color-contrast

$RED = 0.2126
$GREEN = 0.7152
$BLUE = 0.0722
$GAMMA = 2.4

function HexToRGB($hex) {
    $hex = $hex -replace '^(#|0x)', ''
    [int]$r = [Convert]::ToInt32($hex.Substring(0, 2), 16)
    [int]$g = [Convert]::ToInt32($hex.Substring(2, 2), 16)
    [int]$b = [Convert]::ToInt32($hex.Substring(4, 2), 16)
    return @($r, $g, $b)
}

function Luminance($r, $g, $b) {
    $a = @($r, $g, $b) | ForEach-Object {
        $b = $_ / 255.0
        if ($b -le 0.03928) {
            $b / 12.92
        }
        else {
            [math]::Pow(($b + 0.055) / 1.055, $GAMMA)
        }
    }
    return $a[0] * $RED + $a[1] * $GREEN + $a[2] * $BLUE
}

function ContrastRatio($hex1, $hex2) {
    $rgb1 = HexToRGB $hex1
    $rgb2 = HexToRGB $hex2

    $lum1 = Luminance $rgb1[0] $rgb1[1] $rgb1[2]
    $lum2 = Luminance $rgb2[0] $rgb2[1] $rgb2[2]

    $brightest = [math]::Max($lum1, $lum2)
    $darkest = [math]::Min($lum1, $lum2)

    return ($brightest + 0.05) / ($darkest + 0.05)
}

function ValidateHexColor($color) {
    return $color -match '^(#|0x)?([a-fA-F0-9]{6})$'
}

# Function to prompt for valid hex color
function Get-ValidHexColor($prompt) {
    do {
        $color = Read-Host -Prompt $prompt
        if (ValidateHexColor $color) {
            return $color
        }
        else {
            Write-Host "Invalid hex color format. Please enter a valid hex color (e.g., #FFFFFF, 0xFFFFFF, or FFFFFF)." -ForegroundColor Red
        }
    }
    while ($true)
}

Write-Host "Calculate the contrast between 2 colors" -ForegroundColor Cyan
Write-Host "Other resources you can use:" -ForegroundColor Cyan
Write-Host "- https://coolors.co/contrast-checker/000000-ffffff" -ForegroundColor Cyan
Write-Host "- https://webaim.org/resources/contrastchecker" -ForegroundColor Cyan
Write-Host

$color1 = Get-ValidHexColor "First color"
$color2 = Get-ValidHexColor "Second color"

$contrastRatio = [math]::Round((ContrastRatio $color1 $color2), 2)
$formattedContrastRatio = "{0:N2}" -f $contrastRatio
Write-Host "`nContrast ratio between '$color1' and '$color2' is '$formattedContrastRatio'" -ForegroundColor Green

Read-Host "`nPress enter to exit"
