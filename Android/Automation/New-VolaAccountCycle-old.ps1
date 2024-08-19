param (
    [string] $DeviceId,
    [string] $BaseAccountName = "elian.vola.plus.test.",
    [string] $AccountSuffix = "",
    [string] $MailDomain = "gmail.com",
    [uint] $ShortSleepTimeInMillis = 450,
    [switch] $DisableScreenCheck
)


Import-Module -Name .\VolaAutomation.psm1 -Force -ErrorAction Stop
Import-Module -Name .\VolaApis.psm1 -Force -ErrorAction Stop


if (-not $MyInvocation.Line) {
    Write-Error "In order to use this script you must call it from the command line."
    exit
}
if (-not (Test-AdbDeviceWithIdAndShowErrors -DeviceId $DeviceId)) {
    exit
}

$expectedResolution = "1344x2992"
$resolution = Invoke-AdbGetPhysicalSize -DeviceId $DeviceId -AsString
if ($resolution -ne $expectedResolution) {
    Write-Error "The device must have a resolution of '$expectedResolution', but was '$resolution'. Try with a Pixel 8 Pro device."
    exit
}
$expectedApiLevel = 35
$apiLevel = Invoke-AdbGetApiLevel -DeviceId $DeviceId
if ($apiLevel -ne $expectedApiLevel) {
    Write-Error "The device must have API level of $expectedApiLevel, but was $apiLevel"
    exit
}



$screenWidth = (Invoke-AdbGetPhysicalSize -DeviceId $DeviceId)[0    ]
$screenWidthHalf = $screenWidth / 2.0



$nickName = if ($AccountSuffix) {
    "$BaseAccountName$AccountSuffix"
}
else { $BaseAccountName }
$email = "$nickName@$MailDomain"


if (-not $DisableScreenCheck) {
    $topFragment = Invoke-AdbGetTopFragment -DeviceId $DeviceId
}
$topActivity = Invoke-AdbGetTopActivity -DeviceId $DeviceId
if (-not $DisableScreenCheck -and $topFragment -ne "FragmentRegister1") {
    Show-Notification -Title "Can't create the account" -Text "You must be located in the first registration screen (FragmentRegister1)" -ToolTipIcon Error
    Write-Error "You must be located in the first registration screen (FragmentRegister1), but you were in '$topFragment' at '$topActivity'"
    exit
}
if (Invoke-ApiUserExists -Email $email) {
    Show-Notification -Title "Can't create the account" -Text "The email '$email' has already been used." -ToolTipIcon Error
    Write-Error "The email '$email' has already been used."
    exit
}

$name = "Efe$AccountSuffix"
$surname = Get-Date -Format "yyyyMMdd"
$dni = "123456789A"
$password = "elianFabian1!"
$number = "643606637"



function SelectAndRemoveTextFromFocusedView {
    Invoke-AdbKeyCombination -DeviceId $DeviceId -KeyCodes CTRL_LEFT, A
    Invoke-AdbKeyEvent -DeviceId $DeviceId -KeyCode DEL
}

function EnterText([string] $Text) {
    SelectAndRemoveTextFromFocusedView
    Invoke-AdbText -DeviceId $DeviceId -Text $Text
}

function ShortSleep {
    Start-Sleep -Milliseconds $ShortSleepTimeInMillis
}

function Tap([uint] $X, [uint] $Y) {
    Invoke-AdbTap -DeviceId $DeviceId -X $X -Y $Y
}

function HideKeyboard {
    Invoke-AdbHideKeyboard -DeviceId $DeviceId
}


#region Register 1

$firstInputY = 860
$inputDistance = 180

# Just in case
HideKeyboard
ShortSleep

Tap -X $screenWidthHalf -Y $firstInputY
EnterText -DeviceId $DeviceId -Text $name

Tap -X $screenWidthHalf -Y ($firstInputY + $inputDistance * 1)
EnterText -DeviceId $DeviceId -Text $surname

Tap -X $screenWidthHalf -Y ($firstInputY + $inputDistance * 2)
EnterText -DeviceId $DeviceId -Text $email

Tap -X $screenWidthHalf -Y ($firstInputY + $inputDistance * 3)
EnterText -DeviceId $DeviceId -Text $password

Tap -X $screenWidthHalf -Y ($firstInputY + $inputDistance * 4)
EnterText -DeviceId $DeviceId -Text $password

Tap -X $screenWidthHalf -Y ($firstInputY + $inputDistance * 5)
EnterText -DeviceId $DeviceId -Text $nickName

HideKeyboard
ShortSleep

Tap -X $screenWidthHalf -Y ($firstInputY + $inputDistance * 6)
EnterText -DeviceId $DeviceId -Text $dni

HideKeyboard
ShortSleep

Tap -X ($screenWidthHalf * 1.5) -Y ($firstInputY + $inputDistance * 7)
EnterText -DeviceId $DeviceId -Text $number

HideKeyboard
ShortSleep

Tap -X $screenWidthHalf -Y ($firstInputY + $inputDistance * 8)
ShortSleep
Tap -X 965 -Y 1860
ShortSleep

Tap -X $screenWidthHalf -Y 2600
Start-Sleep 1

#endregion

#region Register 2

# Click empty space, just in case
Tap -X $screenWidthHalf -Y 400
ShortSleep

function MoveVerticallyInSpinner {

    param (
        [Parameter(Mandatory)]
        [uint] $Steps,

        [ValidateSet("DPAD_UP", "DPAD_DOWN")]
        [Parameter(Mandatory)]
        [string] $KeyCode,

        [switch] $DisableForceSelect
    )

    # Force selection when the spinner is open
    if (-not $DisableForceSelect) {
        Invoke-AdbKeyEvent -DeviceId $DeviceId -KeyCode TAB
    }

    foreach ($n in 0..$Steps) {
        Invoke-AdbKeyEvent -DeviceId $DeviceId -KeyCode $KeyCode
    }
}

function MovePageInSpinner {

    param (
        [Parameter(Mandatory)]
        [uint] $Steps,

        [ValidateSet("PAGE_UP", "PAGE_DOWN")]
        [Parameter(Mandatory)]
        [string] $KeyCode,

        [switch] $DisableForceSelect
    )

    # Force selection when the spinner is open
    if (-not $DisableForceSelect) {
        Invoke-AdbKeyEvent -DeviceId $DeviceId -KeyCode TAB
    }

    foreach ($n in 0..$Steps) {
        Invoke-AdbKeyEvent -DeviceId $DeviceId -KeyCode $KeyCode
    }
}

Tap -X $screenWidthHalf -Y 900
ShortSleep
$nationalities = [array] (Invoke-ApiNationalities)
$nationalityCode = "ES"
$nationalityIndex = $nationalities.IndexOf(($nationalities | Where-Object { $_.code -eq $nationalityCode }))
MovePageInSpinner -Steps ([math]::Ceiling($nationalities.Count / 8)) -KeyCode PAGE_UP # Clean up
MoveVerticallyInSpinner -Steps $nationalityIndex -KeyCode DPAD_DOWN -DisableForceSelect
Invoke-AdbKeyEvent -DeviceId $DeviceId -KeyCode ENTER
ShortSleep

Tap -X $screenWidthHalf -Y 1230
$countries = [array] (Invoke-ApiContries)
$countryCode = "ES"
$country = $countries | Where-Object { $_.country_code -eq $countryCode }
$countryIndex = $countries.IndexOf($country)
MovePageInSpinner -Steps ([math]::Ceiling($countries.Count / 8)) -KeyCode PAGE_UP # Clean up
MoveVerticallyInSpinner -Steps $countryIndex -KeyCode DPAD_DOWN -DisableForceSelect
Invoke-AdbKeyEvent -DeviceId $DeviceId -KeyCode ENTER

Tap -X $screenWidthHalf -Y 1395
$cities = [array] $country.cities
$cityNameSeo = "malaga"
$cityIndex = $cities.IndexOf(($cities | Where-Object { $_.name_seo -eq $cityNameSeo }))
MovePageInSpinner -Steps ([math]::Ceiling($cities.Count / 8)) -KeyCode PAGE_UP # Clean up
MoveVerticallyInSpinner -Steps $cityIndex -KeyCode DPAD_DOWN -DisableForceSelect
Invoke-AdbKeyEvent -DeviceId $DeviceId -KeyCode ENTER
ShortSleep

Tap -X ($screenWidthHalf * 0.5) -Y 1740
Start-Sleep -Milliseconds 100

Tap -X 115 -Y 1960

Tap -X $screenWidthHalf -Y 2770
Start-Sleep 1

#endregion

#region Leveling 1

Tap -X $screenWidthHalf -Y 1230

Tap -X $screenWidthHalf -Y 2770
Start-Sleep 1

#endregion

#region Leveling 2

# Tap first, just in case
Tap -X $screenWidthHalf -Y 925

Tap -X $screenWidthHalf -Y 1420

Tap -X $screenWidthHalf -Y 2770

do {
    Start-Sleep 4
}
while (-not (Invoke-ApiUserExists -Email $email))
Start-Sleep 6

#endregion

#region Vola Slider

# Possible location permission dialog
Tap -X $screenWidthHalf -Y 1810
ShortSleep

Tap -X $screenWidthHalf -Y 2650
ShortSleep

Tap -X $screenWidthHalf -Y 2650
Start-Sleep 6

Tap -X $screenWidthHalf -Y 2650
Start-Sleep 2

#endregion

#region Home

Tap -X $screenWidthHalf -Y 460
Start-Sleep 1

#endregion

#region Profile menu

Tap -X $screenWidthHalf -Y 2820
Start-Sleep 2

#endregion

#region Login

Tap -X $screenWidthHalf -Y 2725

#endregion
