param (
    [string] $DeviceId,
    [string] $BaseAccountName = "elian.vola.plus.test",
    [string] $AccountSuffix = "",
    [string] $MailDomain = "gmail.com",

    [uint] $ShortSleepTimeInMillis = 85,
    [uint] $MediumSleepTimeInMillis = 500,
    [uint] $LargeSleepTimeInMillis = 1000,
    [uint] $ExtraLargeSleepTimeInMillis = 2000,
    [switch] $DisableScreenCheck
)

$applicationId = "com.volaplay.vola"

$script:VerbosePreference = 'Continue'
$script:ErrorActionPreference = 'Stop'

Import-Module -Name .\VolaAutomation.psm1 -Force -ErrorAction Stop
Import-Module -Name .\VolaApis.psm1 -Force -ErrorAction Stop
Import-Module -Name ..\..\_Util\Modules\PSGoogleTranslate


if (-not $MyInvocation.Line) {
    Write-Error "In order to use this script you must call it from the command line."
    exit
}
if (-not (Test-AdbDeviceWithIdAndShowErrors -DeviceId $DeviceId)) {
    exit
}

function GetCurrentNodes {

    [OutputType([System.Xml.XmlLinkedNode[]])]
    param ()

    return Invoke-AdbGetCurrentScreenViewHierarchyNode -DeviceId $DeviceId
}

function TapNode {
    [CmdletBinding()]
    param (
        [System.Xml.XmlLinkedNode] $Node
    )

    Write-Verbose "Tap node $($Node.class)(id = $($Node.'resource-id'), text = $($Node.text), bounds = $($Node.bounds))"

    Invoke-AdbTapNode -DeviceId $DeviceId -Node $Node -ErrorAction Inquire
}




$rootAccountName = if ($AccountSuffix) {
    "$BaseAccountName.$AccountSuffix"
}
else { $BaseAccountName }

$register1TextFieldValues = [PSCustomObject]@{
    nick        = $rootAccountName
    email       = "$rootAccountName@$MailDomain"
    name        = "Efe$AccountSuffix"
    surname     = Get-Date -Format "yyyyMMdd"
    dni         = "123456789A"
    password    = "elianFabian1!"
    phoneNumber = "643606637"
}

if (-not $DisableScreenCheck) {
    $topFragment = Invoke-AdbGetTopFragment -DeviceId $DeviceId
    if (-not $topFragment -and -not $DisableScreenCheck) {
        Write-Error "Couldn't get top fragment. You have to make sure you are on Register1 screen (FragmentRegister1) to use this script."
        Show-Notification -Title "Couldn't get top fragment" -Text "Check the console for more information" -ToolTipIcon Error
        $value = Read-Host "Are you sure you want to continue? Press enter to leave, insert any character and enter to continue:"
        if ($value) {
            exit
        }
    }
}
$topActivity = Invoke-AdbGetTopActivity -DeviceId $DeviceId
if (-not $DisableScreenCheck -and (-not $topFragment -or ($topFragment -ne "FragmentRegister1") -or -not $topActivity.Contains("ActivityRegister"))) {
    Show-Notification -Title "Can't create the account" -Text "You must be located in the first registration screen (FragmentRegister1)" -ToolTipIcon Error
    Write-Error "You must be located in the first registration screen (FragmentRegister1), but you were in '$topFragment' at '$topActivity'"
    exit
}
if (Invoke-ApiUserExists -Email $register1TextFieldValues.email) {
    Show-Notification -Title "Can't create the account" -Text "The email '$($register1TextFieldValues.email)' has already been used." -ToolTipIcon Error
    Write-Error "The email '$($register1TextFieldValues.email)' has already been used."
    exit
}


function RemoveTextFromFocusedView {
    [CmdletBinding()]
    param ()

    Invoke-AdbKeyCombination -DeviceId $DeviceId -KeyCodes CTRL_LEFT, A
    Invoke-AdbKeyEvent -DeviceId $DeviceId -KeyCode DEL
}

function EnterText {
    [CmdletBinding()]
    param (
        [string] $Text
    )

    RemoveTextFromFocusedView
    Invoke-AdbText -DeviceId $DeviceId -Text $Text
}

function ShortSleep {
    [CmdletBinding()]
    param ()

    Start-Sleep -Milliseconds $ShortSleepTimeInMillis
}

function MediumSleep {
    [CmdletBinding()]
    param ()

    Start-Sleep -Milliseconds $MediumSleepTimeInMillis
}

function LargeSleep {
    [CmdletBinding()]
    param ()

    Start-Sleep -Milliseconds $LargeSleepTimeInMillis
}

function ExtraLargeSleep {
    [CmdletBinding()]
    param ()

    Start-Sleep -Milliseconds $ExtraLargeSleepTimeInMillis
}


function HideKeyboard {
    [CmdletBinding()]
    param ()

    if (Invoke-AdbTestKeyBoardOpen -DeviceId $DeviceId) {
        Invoke-AdbKeyEvent -DeviceId $DeviceId -KeyCode BACK
        ShortSleep
        ShortSleep
    }
}

function GetNodeById {

    [OutputType([System.Xml.XmlLinkedNode])]
    param (
        [Parameter(Mandatory)]
        [string] $Id,

        [Parameter(Mandatory)]
        [System.Xml.XmlLinkedNode[]] $From
    )

    return $From
    | Where-Object { $_.'resource-id'.EndsWith($Id) }
    | ForEach-Object {
        if (-not $_) {
            Read-Host "Couldn't find a node with an id the ends with '$Id'"
            Show-Notification -Title "Couldn't find node" -Text "There's no node with an id that ends with '$Id'"
            exit
        }
        else {
            Write-Verbose "Get node with resource id '$Id'"
            $_
        }
    }
}

function GetNodeByText {

    [OutputType([System.Xml.XmlLinkedNode])]
    param (
        [Parameter(Mandatory)]
        [string] $Text,

        [Parameter(Mandatory)]
        [System.Xml.XmlLinkedNode[]] $From
    )

    return $From
    | Where-Object { $_.text -like $Text }
    | ForEach-Object {
        if (-not $_) {
            Read-Host "Couldn't find a node with text that contains '$Text'"
            Show-Notification -Title "Couldn't find node" -Text "There's no node with an id that contains '$Text'"
            exit
        }
        else {
            Write-Verbose "Get node with resource id '$Text'"
            $_
        }
    }
}



#region Register1

Write-Verbose "Enter Register 1 screen"

HideKeyboard

$register1Nodes = GetCurrentNodes

$register1NamedNodes = [PsCustomObject]@{
    name            = GetNodeById -From $register1Nodes "tieName"
    surname         = GetNodeById -From $register1Nodes "tieSurname"
    email           = GetNodeById -From $register1Nodes "tieEmail"
    password        = GetNodeById -From $register1Nodes "tiePassword"
    confirmPassword = GetNodeById -From $register1Nodes "tieConfirmPassword"
    nick            = GetNodeById -From $register1Nodes "tieNick"
    dni             = GetNodeById -From $register1Nodes "tieDni"
    phoneNumber     = GetNodeById -From $register1Nodes "tietPhoneNumber"
    birthDate       = GetNodeById -From $register1Nodes "tieBirthDate"
    continueButton  = GetNodeById -From $register1Nodes "btnContinue"
}

TapNode $register1NamedNodes.name
EnterText $register1TextFieldValues.name
HideKeyboard

TapNode $register1NamedNodes.surname
EnterText $register1TextFieldValues.surname
HideKeyboard

TapNode $register1NamedNodes.email
EnterText $register1TextFieldValues.email
HideKeyboard

TapNode $register1NamedNodes.password
EnterText $register1TextFieldValues.password
HideKeyboard

TapNode $register1NamedNodes.confirmPassword
EnterText $register1TextFieldValues.password
HideKeyboard

TapNode $register1NamedNodes.nick
EnterText $register1TextFieldValues.nick
HideKeyboard

TapNode $register1NamedNodes.dni
EnterText $register1TextFieldValues.dni
HideKeyboard

TapNode $register1NamedNodes.phoneNumber
EnterText $register1TextFieldValues.phoneNumber
HideKeyboard

TapNode $register1NamedNodes.birthDate
$register1DateDialogNodes = GetCurrentNodes
$register1DateDialogOkButton = $register1DateDialogNodes | Where-Object { $_.'resource-id'.EndsWith("button1") }
TapNode $register1DateDialogOkButton
ShortSleep

TapNode $register1NamedNodes.continueButton
MediumSleep

#endregion

#region Register2

Write-Verbose "Enter Register 2 screen"

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

$register2Nodes = GetCurrentNodes

$register2NamedNodes = [PsCustomObject]@{
    nationalitySelector    = GetNodeById -From $register2Nodes "spNationality"
    countrySelector        = GetNodeById -From $register2Nodes "spinner_country"
    citySelector           = GetNodeById -From $register2Nodes "spinner_city"
    maleGenderRadioButton  = GetNodeById -From $register2Nodes "rbMale"
    acceptConditionsButton = GetNodeById -From $register2Nodes "cbTyC"
    continueButton         = GetNodeById -From $register2Nodes "btnContinue"
}

$register2Values = [PSCustomObject]@{
    nationalityCode = "ES"
    countryCode     = "ES"
    cityNameSeo     = "malaga"
}

TapNode $register2NamedNodes.nationalitySelector
MediumSleep
$nationalities = [array] (Invoke-ApiNationalities)
$nationalityIndex = $nationalities.IndexOf(($nationalities | Where-Object { $_.code -eq $register2Values.nationalityCode }))
MovePageInSpinner -Steps ([math]::Ceiling($nationalities.Count / 8)) -KeyCode PAGE_DOWN # Clean up
# Since spain is in the last positions this is faster
MoveVerticallyInSpinner -Steps ($nationalities.Count - $nationalityIndex - 2) -KeyCode DPAD_UP -DisableForceSelect
Invoke-AdbKeyEvent -DeviceId $DeviceId -KeyCode ENTER
MediumSleep

TapNode $register2NamedNodes.countrySelector
MediumSleep
$countries = [array] (Invoke-ApiContries)
$country = $countries | Where-Object { $_.country_code -eq $register2Values.countryCode }
$countryIndex = $countries.IndexOf($country)
MovePageInSpinner -Steps ([math]::Ceiling($countries.Count / 8)) -KeyCode PAGE_UP # Clean up
MoveVerticallyInSpinner -Steps $countryIndex -KeyCode DPAD_DOWN -DisableForceSelect
Invoke-AdbKeyEvent -DeviceId $DeviceId -KeyCode ENTER
MediumSleep

TapNode $register2NamedNodes.citySelector
MediumSleep
$cities = [array] $country.cities
$cityIndex = $cities.IndexOf(($cities | Where-Object { $_.name_seo -eq $register2Values.cityNameSeo }))
MovePageInSpinner -Steps ([math]::Ceiling($cities.Count / 8)) -KeyCode PAGE_UP # Clean up
MoveVerticallyInSpinner -Steps $cityIndex -KeyCode DPAD_DOWN -DisableForceSelect
Invoke-AdbKeyEvent -DeviceId $DeviceId -KeyCode ENTER
MediumSleep

TapNode $register2NamedNodes.maleGenderRadioButton

if ($register2NamedNodes.acceptConditionsButton.checked -eq "false") {
    TapNode $register2NamedNodes.acceptConditionsButton
    MediumSleep
}

TapNode $register2NamedNodes.continueButton
MediumSleep

#enderegion

#region Leveling 1

Write-Verbose "Enter Leveling 1 screen"

$leveling1Nodes = GetCurrentNodes

[string] $appLocale = Invoke-AdbGetSharedPreferencesNode -DeviceId $DeviceId -Filename "SharedPreferences.xml" -ApplicationId $applicationId
| Where-Object -Property "name" -EQ -Value "custom_locale" | Select-Object -Property InnerText

[string] $deviceLocale = (Invoke-AdbGetProp -DeviceId $DeviceId -PropertyName ro.product.locale).Split("-")[0]

$currentLocale = if ($appLocale) { $appLocale } else { $deviceLocale }

Write-Verbose "Get app locale from settings: '$appLocale'"
Write-Verbose "Get device locale: '$deviceLocale'"

$localizedSportName = (Invoke-GoogleTranslate -InputObject "Padel" -SourceLanguage en -TargetLanguage $currentLocale).Translation
Write-Verbose "Localized sport name: $localizedSportName"

$leveling1NamedNodes = [PSCustomObject]@{
    padel          = GetNodeByText -Text $localizedSportName -From $leveling1Nodes
    continueButton = GetNodeById -Id "btnContinue" -From $leveling1Nodes
}

TapNode $leveling1NamedNodes.padel
ShortSleep

TapNode $leveling1NamedNodes.continueButton
MediumSleep

#endregion

#region Leveling 2

Write-Verbose "Enter Leveling 2 screen"

$leveling2Nodes = GetCurrentNodes

$leveling2NamedNodes = [PSCustomObject]@{
    #initiation       = GetNodeByText -From $leveling2Nodes -Text (Get-VolaStringResourceById -Locale $currentLocale -Id level__initiation)
    highIntermediate = GetNodeByText -From $leveling2Nodes -Text (Get-VolaStringResourceById -Locale $currentLocale -Id level__high_intermediate)
    registerButton   = GetNodeById -From $leveling2Nodes -Id "btnRegister"
}

TapNode $leveling2NamedNodes.highIntermediate
ShortSleep

TapNode $leveling2NamedNodes.registerButton

Invoke-AdbGrantPermission -DeviceId $DeviceId -ApplicationId $applicationId -Permission android.permission.ACCESS_COARSE_LOCATION, android.permission.ACCESS_FINE_LOCATION

do {
    Start-Sleep 4
}
while (-not (Invoke-ApiUserExists -Email $register1TextFieldValues.email))
Start-Sleep 6

#endregion

if ((Invoke-AdbGetTopActivity -DeviceId $DeviceId).Contains("VolaInfoActivity")) {
    #region Vola Slider (1, 2, 3)

    Write-Verbose "Enter Slider 1"

    $slider1ContinueButton = GetNodeById -From (GetCurrentNodes) -Id "btnContinue"
    TapNode $slider1ContinueButton

    Write-Verbose "Enter Slider 2"
    $slider2ContinueButton = GetNodeById -From (GetCurrentNodes) -Id "btnContinue"
    TapNode $slider2ContinueButton

    Write-Verbose "Enter Slider 3"
    $slider3ContinueButton = GetNodeById -From (GetCurrentNodes) -Id "btnContinue"
    ExtraLargeSleep
    TapNode $slider3ContinueButton
    ExtraLargeSleep

    #endregion
}

#region Home

$homeProfileMenuButton = GetNodeById -From (GetCurrentNodes) -Id "imvProfile"
TapNode $homeProfileMenuButton
MediumSleep

#endregion

#region Profile menu

$profileMenuLogoutButton = GetNodeById -From (GetCurrentNodes) -Id "logout"
TapNode $profileMenuLogoutButton
MediumSleep

#endregion

#region Login

$loginRegisterButton = GetNodeById -From (GetCurrentNodes) -Id "fragment_login_ll_sign_up_area"
TapNode $loginRegisterButton
MediumSleep


#endregion

Show-Notification -Title "The script $($MyInvocation.MyCommand.Name) finished!" -Text "Check the console for more details."
