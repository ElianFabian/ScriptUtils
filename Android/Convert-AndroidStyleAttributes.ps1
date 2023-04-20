# Made by ChatGPT

function Convert-AndroidStyleToViewAttributes {
    param(
        [Parameter(Mandatory=$true)]
        [string]$StyleString
    )
    
    # Split the input style string into lines
    $lines = $StyleString -split "`n"
    
    # Create an array to store the formatted attributes and values
    $formattedAttributes = @()
    
    # Iterate through each line
    foreach ($line in $lines) {
        # Extract the attribute name and value using regex pattern
        if ($line -match 'name="(?<attribute>[^"]+)"\s*>(?<value>[^<]+)</item>') {
            $attribute = $matches['attribute']
            $value = $matches['value']
            
            # Check if the attribute has a namespace, if not, add "app:" namespace
            if ($attribute -notlike "*:*") {
                $attribute = "app:$attribute"
            }
            
            # Add the formatted attribute and value to the array
            $formattedAttributes += "$attribute=`"$value`""
        }
    }
    
    # Join the formatted attributes and values with a space separator
    $formattedString = $formattedAttributes -join "`n"
    
    # Return the formatted string
    return $formattedString
}


function Convert-ViewAttributesToAndroidStyle {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AttributesString
    )
    
    # Split the input attributes string into individual attributes and values
    $attributes = $AttributesString -split "\s+"
    
    # Create an empty array to store the formatted lines
    $lines = @()
    
    # Iterate through each attribute and value
    foreach ($attribute in $attributes) {
        # Extract the attribute name and value
        if ($attribute -match '(?<attribute>(android|app):[^=]+)="(?<value>[^"]+)"') {
            $attributeName = $matches['attribute']
            $attributeValue = $matches['value']
            
            # Check if the attribute has "android:" namespace
            if ($attributeName -notlike "android:*") {
                # Check if the attribute has "app:" namespace
                if ($attributeName -like "app:*") {
                    # Remove the "app:" namespace from the attribute name
                    $attributeName = $attributeName -replace "^app:", ""
                }
                else {
                    # Add "android:" namespace to the attribute name
                    $attributeName = "android:$attributeName"
                }
            }
            
            # Create a formatted line with the attribute name and value
            $line = '<item name="{0}">{1}</item>' -f $attributeName, $attributeValue
            
            # Add the formatted line to the array of lines
            $lines += $line
        }
    }
    
    # Join all lines with a newline character and return the formatted style string
    return $lines -join "`n"
}


$clipboardContent = Get-Clipboard -Raw


$attributesFromStyle = Convert-AndroidStyleToViewAttributes $clipboardContent
$styleFromAttributes = Convert-ViewAttributesToAndroidStyle $clipboardContent

$output = if (-not [string]::IsNullOrWhiteSpace($attributesFromStyle))
{
    $attributesFromStyle
}
elseif (-not [string]::IsNullOrWhiteSpace($styleFromAttributes))
{
    $styleFromAttributes
}
else
{
    Write-Host "Coundn't find any style item or attribute`n" -ForegroundColor Red
    Write-Host "Your clipboard content`n"
    Write-Host $clipboardContent

    while ($true) { Read-Host }
}


Set-Clipboard -Value $output

Write-Host "It's copied into your clipboard!`n"

Write-Host $output -ForegroundColor Green

while ($true) { Read-Host }