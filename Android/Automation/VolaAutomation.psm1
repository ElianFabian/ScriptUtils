Import-Module -Name "$PSScriptRoot/Adb/AdbExtModule.psm1" -Force

if ($IsWindows) {
    Add-Type -AssemblyName System.Windows.Forms
}

function Show-Notification {

    param (
        [Parameter(Mandatory)]
        [string] $Title,

        [Parameter(Mandatory)]
        [string] $Text,

        [System.Windows.Forms.ToolTipIcon] $ToolTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
    )

    $balloon = New-Object System.Windows.Forms.NotifyIcon
    $path = (Get-Process -id $pid).Path

    $balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
    $balloon.BalloonTipIcon = $ToolTipIcon
    $balloon.BalloonTipText = $Text
    $balloon.BalloonTipTitle = $Title
    $balloon.Visible = $true
    $balloon.ShowBalloonTip(50000)
}


$script:ProjectPath = $env:VolaAndroidProjectPath

if (-not (Test-Path -LiteralPath $ProjectPath)) {
    Write-Error "The android project path '$ProjectPath' does not exit"
    Show-Notification -Title "Couldn't read string" -Text "The android project path '$ProjectPath' does not exist" -ToolTipIcon Error
    throw
}
if (-not (Test-Path -LiteralPath "$ProjectPath\app") -and (Test-Path -LiteralPath "$ProjectPath\gradlew")) {
    Write-Error "Are you sure the path '$ProjectPath' is an Android project?"
    Show-Notification -Title "Couldn't read string" -Text "Are you sure the path '$ProjectPath' is an Android project?" -ToolTipIcon Error
    throw
}

$script:ResPath = "$ProjectPath\app\src\main\res"
$script:DefaultLocale = "en"
$script:SupportedLanguages = @($DefaultLocale) + (Get-Item -Path "$ResPath\values-*\strings.xml").Directory.BaseName.Replace("values-", "")

class SupportedLocale : System.Management.Automation.IValidateSetValuesGenerator {
    [String[]] GetValidValues() {
        return $script:SupportedLanguages
    }
}

$script:StringResourceDecodeMap = [ordered] @{
    "\'"    = "'"
    '&lt;'  = '<'
    '&amp;' = '&'
    "\n"    = [System.Environment]::NewLine
}






function Test-VolaAdbDeviceWithIdAndShowError {

    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [string] $DeviceId
    )

    $availableDevices = Invoke-AdbGetAvailableDevices

    if (($availableDevices.Count -gt 0) -and ($DeviceId -notin $availableDevices)) {
        Write-Error "The device id '$DeviceId' is not one of the available devices."
        Invoke-PrettyPrintAdbListOfDevices
        Write-Host
        Show-Notification -Title "Bad device id" -Text "The device id '$DeviceId' is not one of the available devices." -ToolTipIcon Error
        return $false
    }
    if ($availableDevices.Count -eq 0) {
        Write-Error "There are no available devices"
        Show-Notification -Title "Error" -Text "There are no available devices" -ToolTipIcon Error
        return $false
    }
    if (-not $DeviceId) {
        Invoke-PrettyPrintAdbListOfDevices
        Show-Notification -Title "Can't execute script" -Text "Must provide a device id. See the avaible devices printed on the console." -ToolTipIcon Error
        return $false
    }

    return $true
}


function GetVolaStringResourcesIdFromProject {

    [OutputType([string[]])]
    param (
        [ValidateSet([SupportedLocale])]
        [Parameter(Mandatory)]
        [string] $Locale
    )

    if ($Locale -eq $script:DefaultLocale) {
        $stringsFilePath = "$script:ResPath\values\strings.xml"
    }
    else {
        $stringsFilePath = "$script:ResPath\values-$Locale\strings.xml"
    }

    return (Get-Content $stringsFilePath -Raw | Select-Xml -XPath "//string").Node.Name
}


function Get-VolaStringResourceById {

    [OutputType([string])]
    param (
        [ValidateSet([SupportedLocale])]
        [Parameter(Mandatory)]
        [string] $Locale,

        [switch] $Raw
    )

    dynamicparam {
        if ($PSBoundParameters.ContainsKey('Locale')) {
            $IdAttribute = New-Object System.Management.Automation.ParameterAttribute
            $IdAttribute.Mandatory = $true
            $IdAttribute.HelpMessage = "Must specify Locale first before setting Id"

            $Id = New-Object System.Management.Automation.RuntimeDefinedParameter('Id', [string[]], $IdAttribute)
            $IdDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $IdDictionary.Add('Id', $Id)
            return $IdDictionary
        }
    }

    begin {
        $defaultStringsFilePath = "$ResPath\values\strings.xml"

        if ($Locale -eq $DefaultLocale) {
            $stringsFilePath = $defaultStringsFilePath
        }
        else {
            $stringsFilePath = "$ResPath\values-$Locale\strings.xml"
        }
    }

    process {
        $Id = $PSBoundParameters['Id']

        foreach ($resourceId in $Id) {
                (Get-Content (($stringsFilePath, $defaultStringsFilePath) | Select-Object -Unique) -Raw | Select-Xml -XPath "//string[@name='$resourceId']").Node.InnerText | ForEach-Object {
                if ($Raw) {
                    $_
                }
                else {
                    $realContent = $_
                    foreach ($pair in $script:StringResourceDecodeMap.GetEnumerator()) {
                        $encodedValue = $pair.Key
                        $decodedValue = $pair.Value

                        $realContent = $realContent.Replace($encodedValue, $decodedValue)
                    }
                    $realContent
                }
            }
            | Select-Object -First 1
        }
    }
}

Register-ArgumentCompleter -CommandName Get-VolaStringResourceById -ParameterName Id -ScriptBlock {

    param(
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    $locale = $fakeBoundParameters['Locale']

    GetVolaStringResourcesIdFromProject $locale | Where-Object { $_ -like "$wordToComplete*" }
}




function Invoke-VolaGetNodeById {

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

function Invoke-VolaGetNodeByText {

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

[hashtable] $script:screenNodesByTag = [ordered] @{}

function Invoke-VolaGetCurrentScreenNode {

    [OutputType([System.Xml.XmlLinkedNode[]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $DeviceId,

        [string] $Tag,

        [switch] $ForceUpdate
    )

    begin {
        if ($Tag -in $script:screenNodesByTag -and -not $ForceUpdate) {
            return $script:screenNodesByTag.$Tag
        }
    }

    process {
        foreach ($id in $DeviceId) {
            $nodes = $id | Invoke-AdbGetCurrentScreenViewHierarchyNode -NormalizeText
            $script:screenNodesByTag.$Tag = $nodes
            return $nodes
        }
    }
}

function Invoke-VolaTapNode {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [System.Xml.XmlLinkedNode] $Node
    )

    Write-Verbose "Tap node $($Node.class)(id = '$($Node.'resource-id')', text = $($Node.text), bounds = $($Node.bounds))"

    Invoke-AdbTapNode -DeviceId $DeviceId -Node $Node
}


function Invoke-VolaCheckCurrentScreen {

    [OutputType([bool])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [string] $ActivityName,

        [string] $FragmentName
    )

    $topActivity = Invoke-AdbGetTopActivity -DeviceId $DeviceId
    if ($FragmentName) {
        $topFragment = Invoke-AdbGetTopFragment -DeviceId $DeviceId
    }
    if (-not $topFragment -and $FragmentName) {
        Write-Error "Couldn't get the top Fragment"
        return $false
    }
    if (-not $topActivity.Contains($ActivityName)) {
        Write-Error "Expected Activity '$ActivityName', but was '$topActivity'"
        return $false
    }
    if (-not $FragmentName) {
        return $true
    }
    if (-not $topFragment.Contains($FragmentName)) {
        Write-Error "Expected Fragment '$FragmentName', but was '$topFragment'"
        return $false
    }

    return $true

    # if (-not $topFragment -or ($topFragment -ne "FragmentRegister1") -or -not $topActivity.Contains("ActivityRegister")) {
    #     Show-Notification -Title "Can't create the account" -Text "You must be located in the first registration screen (FragmentRegister1)" -ToolTipIcon Error
    #     Write-Error "You must be located in the first registration screen (FragmentRegister1), but you were in '$topFragment' at '$topActivity'"
    #     exit
    # }
}


function Get-VolaLocale {

    [OutputType([string[]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId
    )

    process {
        foreach ($id in $DeviceId) {
            [string] $appLocale = Invoke-AdbGetSharedPreferencesNode -DeviceId $DeviceId -Filename "SharedPreferences.xml" -ApplicationId "com.volaplay.vola"
            | Where-Object -Property "name" -EQ -Value "custom_locale"
            | Select-Object -Property InnerText
            $systemLocale = (Invoke-AdbGetProp -DeviceId $id -PropertyName "persist.sys.locale").Split("-")[0]

            if ($appLocale) {
                $appLocale
            }
            else { $systemLocale }
        }
    }
}



Export-ModuleMember *-*
