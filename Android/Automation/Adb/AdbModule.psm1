function Invoke-AdbGetAvailableDevices {
    [OutputType([string[]])]
    param ()

    Write-Verbose "adb devices"

    return [string[]] (adb devices | Select-Object -Skip 1 | Select-Object -SkipLast 1 | ForEach-Object { $_.Split("`t")[0] })
}

function Invoke-Adb {

    [OutputType([string[]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [string] $Command
    )

    process {
        foreach ($id in $DeviceId) {
            if (-not $id) {
                $availableDevicesCount = (adb devices).Count - 2
                if ($availableDevicesCount -eq 0) {
                    Write-Warning "There are no available devices"
                    return
                }
                if ($availableDevicesCount -gt 1) {
                    Write-Error "There are multiple devices connected, you have to indicate the device id"
                    return
                }

                Write-Warning "It's recommended to pass the device id"

                Write-Verbose "adb $Command"

                return [string] (& "adb" $Command.Split(" "))
            }

            return $id | ForEach-Object {
                Write-Verbose "adb -s $_ $Command"

                & "adb" "-s" $_ $Command.Split(" ")
            }
        }
    }
}

function Invoke-AdbAll {

    [OutputType([string[]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Command
    )

    return Invoke-AdbGetAvailableDevices | Invoke-Adb -DeviceId $_ -Command $Command
}

function Invoke-AdbGetDeviceNameById {

    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId
    )

    process {
        foreach ($id in $DeviceId) {
            if ((Invoke-AdbTestEmulator -DeviceId $id)) {
                return [string] (Invoke-Adb -DeviceId $id -Command "emu avd name" | Select-Object -First 1)
            }
            return $id | Invoke-AdbGetProp -PropertyName "ro.product.model"
        }
    }
}

# TODO: check if device is offline, adb -s "emulator-5554" get-state (offline, device, bootloader, unauthorized)
# https://android.stackexchange.com/a/164050
function Invoke-AdbGetState {

    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId
    )

    process {
        foreach ($id in $DeviceId) {
            return Invoke-Adb -DeviceId $id -Command "get-state"
        }
    }
}

function Invoke-AdbWaitFor {

    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [ValidateSet("Device", "Recovery", "Rescue", "Sideload", "Bootloader", "Disconnect")]
        [string] $State,

        [ValidateSet("Usb", "Local", "Any")]
        [string] $Transport = "Any"
    )

    begin {
        $stateLowercase = $State.ToLower()
        $transportLowercase = $Transport.ToLower()
    }

    process {
        foreach ($id in $DeviceId) {
            return Invoke-Adb -DeviceId $id -Command "wait-for-$transportLowercase-$stateLowercase"
        }
    }
}

function Invoke-AdbTap {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [float] $X,

        [Parameter(Mandatory)]
        [float] $Y
    )

    process {
        foreach ($id in $DeviceId) {
            $width, $height = Invoke-AdbGetPhysicalSize -DeviceId $id
            if ($X -lt 0.0 -or $X -gt $width) {
                Write-Error "X coordinate in device with id '$id' must be between 0 and $width, but was '$X'"
                return
            }
            if ($Y -lt 0.0 -or $Y -gt $height) {
                Write-Error "Y coordinate in device with id '$id' must be between 0 and $height, but was '$Y'"
                return
            }

            Invoke-Adb -DeviceId $id -Command "shell input tap $X $Y" | Out-Null
        }
    }
}

function Invoke-AdbSwipe {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [float] $X1,

        [Parameter(Mandatory)]
        [float] $Y1,

        [Parameter(Mandatory)]
        [float] $X2,

        [Parameter(Mandatory)]
        [float] $Y2
    )

    process {
        foreach ($id in $DeviceId) {
            $width, $height = Invoke-AdbGetPhysicalSize -DeviceId $id
            if ($X1 -lt 0.0 -or $X1 -gt $width) {
                Write-Error "X1 coordinate in device with id '$id' must be between 0 and $width, but was '$X1'"
                return
            }
            if ($Y1 -lt 0.0 -or $Y1 -gt $height) {
                Write-Error "Y1 coordinate in device with id '$id' must be between 0 and $height, but was '$Y1'"
                return
            }
            if ($X2 -lt 0.0 -or $X2 -gt $width) {
                Write-Error "X2 coordinate in device with id '$id' must be between 0 and $width, but was '$X2'"
                return
            }
            if ($Y2 -lt 0.0 -or $Y2 -gt $height) {
                Write-Error "Y2 coordinate in device with id '$id' must be between 0 and $height, but was '$Y2'"
                return
            }

            Invoke-Adb -DeviceId $id -Command "shell input touchscreen swipe $X1 $Y1 $X2 $Y2" | Out-Null
        }
    }
}


$script:AdbKeyCodes = @(
    "UNKNOWN", "MENU", "SOFT_RIGHT", "HOME",
    "BACK", "CALL", "ENDCALL",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "STAR", "POUND",
    "DPAD_UP", "DPAD_DOWN", "DPAD_LEFT", "DPAD_RIGHT", "DPAD_CENTER",
    "VOLUME_UP", "VOLUME_DOWN",
    "POWER", "CAMERA", "CLEAR",
    "A", "B", "C", "D",
    "E", "F", "G", "H",
    "I", "J", "K", "L",
    "M", "N", "O", "P",
    "Q", "R", "S", "T",
    "U", "V", "W", "X", "Y", "Z",
    "COMMA", "PERIOD",
    "ALT_LEFT", "ALT_RIGHT",
    "CTRL_LEFT", "CTRL_RIGHT",
    "SHIFT_LEFT", "SHIFT_RIGHT",
    "TAB", "SPACE", "SYM", "EXPLORER",
    "ENVELOPE", "ENTER", "DEL", "GRAVE",
    "MINUS", "EQUALS",
    "LEFT_BRACKET", "RIGHT_BRACKET",
    "BACKSLASH", "SEMICOLON", "APOSTROPHE", "SLASH", "AT", "NUM",
    "HEADSETHOOK", "FOCUS", "PLUS",
    "MENU", "NOTIFICATION", "SEARCH",
    "ESCAPE", "BUTTON_START",
    "TAG_LAST_KEYCODE",
    "PAGE_UP", "PAGE_DOWN",
    "PASTE"
)

class KeyCode : System.Management.Automation.IValidateSetValuesGenerator {

    [string[]] GetValidValues() {
        return $script:AdbKeyCodes
    }
}

function Invoke-AdbKeyEvent {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [ValidateCount(1, [int]::MaxValue)]
        [ValidateSet([KeyCode])]
        [Parameter(Mandatory)]
        [string[]] $KeyCode
    )

    process {
        foreach ($id in $DeviceId) {
            foreach ($code in $KeyCode) {
                Invoke-Adb -DeviceId $id -Command "shell input keyevent KEYCODE_$code" | Out-Null
            }
        }
    }
}

function Invoke-AdbKeyCombination {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $DeviceId,

        [ValidateCount(2, [int]::MaxValue)]
        [ValidateSet([KeyCode])]
        [Parameter(Mandatory)]
        [string[]] $KeyCodes
    )

    foreach ($id in $DeviceId) {
        $apiLevel = [uint] (Invoke-AdbGetProp -DeviceId $id -PropertyName ro.build.version.sdk)
        if ($apiLevel -le 30) {
            Write-Error "'adb shell input keycombination' is not available for api levels lower or equal to 30. Device id: '$id', api level: '$apiLevel'"
            return
        }
        if ($apiLevel -le 33) {
            Write-Error "'adb shell input keycombination' is not available for api levels [31, 32, 33] (the command exists but it doesn't seem to work properly). Device id: '$id', api level: '$apiLevel'"
            return
        }
        Invoke-Adb -DeviceId $id -Command "shell input keycombination $($KeyCodes | ForEach-Object { "KEYCODE_$_" })" | Out-Null
    }
}

function Invoke-AdbText {

    # These ( ) < > | ; & * \ ~ " ' ` % and space all need escaping. Space can be replaced with %s
    # https://stackoverflow.com/a/31371987/18418162

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [string] $Text
    )

    begin {
        if (Compare-Object -ReferenceObject ([System.Text.Encoding]::ASCII.GetBytes($Text)) -DifferenceObject ([System.Text.Encoding]::Latin1.GetBytes($Text))) {
            Write-Error "'adb shell input text' only accepts latin1 characters. Text: '$Text'"
            return $null
        }

        $charMapping = @{
            '(' = '\('
            ')' = '\)'
            '<' = '\<'
            '>' = '\>'
            '|' = '\|'
            ';' = '\;'
            '&' = '\&'
            '\' = '\\'
            '~' = '\~'
            "'" = "\'"
            '`' = '\`'
            '%' = '\%'
        }
    }

    process {
        foreach ($id in $DeviceId) {
            $sb = [System.Text.StringBuilder]::new($Text)
            foreach ($char in $charMapping.Keys) {
                $sb.Replace($char, $charMapping[$char]) > $null
            }

            $sb.Replace(" ", "%s") > $null

            $encodedText = $sb.ToString()

            Invoke-Adb -DeviceId $id -Command "shell input text ""$encodedText"""
        }
    }
}

function Invoke-AdbGetProp {

    [CmdletBinding(DefaultParameterSetName = "Default")]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory, ParameterSetName = "Default")]
        [string[]] $PropertyName,

        [Parameter(Mandatory, ParameterSetName = "List")]
        [switch] $List
    )

    process {
        foreach ($id in $DeviceId) {
            if ($List) {
                return Invoke-Adb -DeviceId $id -Command "shell getprop"
            }

            return $PropertyName | ForEach-Object {
                if ($_.Contains(" ")) {
                    Write-Error "PropertyName '$_' can't contain space characters"
                    return
                }

                Invoke-Adb -DeviceId $id -Command "shell getprop $PropertyName"
            } | Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            }
        }
    }
}

function Invoke-AdbSetProp {

    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [string[]] $PropertyName,

        [Parameter(Mandatory)]
        [string] $Value
    )

    begin {
        if ($PropertyName.Contains(" ")) {
            Write-Error "PropertyName '$PropertyName' can't contain space characters"
            return
        }
    }

    process {
        foreach ($id in $DeviceId) {
            Invoke-Adb -DeviceId $id -Command "shell setprop $PropertyName ""$Value"""
        }
    }
}

function Invoke-AdbGetSetting {

    [CmdletBinding(DefaultParameterSetName = "Default")]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [ValidateSet("Global", "System", "Secure")]
        [string] $Namespace,

        [Parameter(Mandatory, ParameterSetName = "List")]
        [switch] $List
    )

    dynamicparam {
        if ($PSBoundParameters.ContainsKey('Namespace')) {
            $KeyAttribute = New-Object System.Management.Automation.ParameterAttribute
            $KeyAttribute.Mandatory = $true
            $KeyAttribute.HelpMessage = "Must specify Namespace first before setting Key"
            $KeyAttribute.ParameterSetName = "Default"

            $Key = New-Object System.Management.Automation.RuntimeDefinedParameter('Key', [string], $KeyAttribute)
            $KeyDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $KeyDictionary.Add('Key', $Key)
            return $KeyDictionary
        }
    }

    begin {
        $Key = [string] $PSBoundParameters['Key']
        if ($Key.Contains(" ")) {
            Write-Error "Key '$Key' can't contain space characters"
            return
        }

        $namespaceLowercase = $Namespace.ToLower()
    }

    process {
        foreach ($id in $DeviceId) {
            if ($List) {
                return Invoke-Adb -DeviceId $id -Command "shell settings list $namespaceLowercase"
            }

            return Invoke-Adb -DeviceId $id -Command "shell settings get $namespaceLowercase ""$Key"""
        }
    }
}

# This one works better with unicode that "setprop"
# I should check the verify characters for Key, ("." and "_" and regular letters and characters seem to work well)
function Invoke-AdbSetSetting {

    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [ValidateSet("Global", "System", "Secure")]
        [string] $Namespace,

        [Parameter(Mandatory)]
        [string] $Key,

        [Parameter(Mandatory)]
        [string] $Value
    )

    begin {
        if ($Key.Contains(" ")) {
            Write-Error "Key '$Key' can't contain space characters"
            return
        }

        $namespaceLowercase = $Namespace.ToLower()
    }

    process {
        foreach ($id in $DeviceId) {
            $id | Invoke-Adb -Command "shell settings put $namespaceLowercase $Key ""$Value"""
        }
    }
}

# TODO: I should check how "adb shell settings reset" works and the {default} value for global/secure
function Invoke-AdbRemoveSetting {

    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [ValidateSet("Global", "System", "Secure")]
        [string] $Namespace
    )

    dynamicparam {
        if ($PSBoundParameters.ContainsKey('Namespace')) {
            $KeyAttribute = New-Object System.Management.Automation.ParameterAttribute
            $KeyAttribute.Mandatory = $true
            $KeyAttribute.HelpMessage = "Must specify Namespace first before setting Key"

            $Key = New-Object System.Management.Automation.RuntimeDefinedParameter('Key', [string], $KeyAttribute)
            $KeyDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $KeyDictionary.Add('Key', $Key)
            return $KeyDictionary
        }
    }

    begin {
        $Key = [string]$PSBoundParameters['Key']
        if ($Key.Contains(" ")) {
            Write-Error "Key '$Key' can't contain space characters"
            return
        }

        $namespaceLowercase = $Namespace.ToLower()
    }

    process {
        foreach ($id in $DeviceId) {
            return Invoke-Adb -DeviceId $id -Command "shell settings delete $namespaceLowercase ""$Key"""
        }
    }
}

function Invoke-AdbFindPropByName {

    [CmdletBinding(DefaultParameterSetName = "Default")]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory, ParameterSetName = "Default")]
        [string] $Query
    )

    process {
        foreach ($id in $DeviceId) {
            return $PropertyName | ForEach-Object {
                Invoke-Adb -DeviceId $id -Command "shell getprop" | Out-String -Stream | Where-Object {
                    $_ -like "*$Query*"
                }
            }
            | ForEach-Object {
                ($_ | Select-String -Pattern "\[(.+)\]:" -AllMatches).Matches
            }
            | ForEach-Object {
                $_.Groups[1].Value
            }
            | Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            }
        }
    }
}

function Invoke-AdbTakeScreenShot {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [string] $Destination
    )

    begin {
        $adbCommand = "adb exec-out screencap -p > $Destination"
    }

    process {
        if ($VerbosePreference) {
            Write-Verbose $adbCommand
        }
        cmd /c $adbCommand
    }
}

function Invoke-AdbGetPhysicalSize {

    [CmdletBinding()]
    [OutputType([uint[]], [string])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [switch] $AsString
    )

    process {
        foreach ($id in $DeviceId) {
            $result = Invoke-Adb -DeviceId $id -Command "shell wm size"

            $resolutionStr = $result.Split(": ")[1]

            if ($AsString) {
                return $resolutionStr
            }

            $resolution = $resolutionStr.Split("x")

            return @(
                [uint] $resolution[0],
                [uint] $resolution[1]
            )
        }
    }
}

function Invoke-AdbGetPhysicalDensity {

    [CmdletBinding()]
    [OutputType([uint[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId
    )

    process {
        foreach ($id in $DeviceId) {
            return (Invoke-Adb -DeviceId $id -Command "shell wm density") -as [uint ]
        }
    }
}

function Invoke-AdbGetPackageList {

    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId
    )

    process {
        foreach ($id in $DeviceId) {
            return Invoke-Adb -DeviceId $id -Command "shell pm list packages" | ForEach-Object { $_.Replace("package:", "") }
        }
    }
}

function Invoke-AdbTestEmulator {

    [CmdletBinding()]
    [OutputType([bool[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId
    )

    process {
        foreach ($id in $DeviceId) {
            if ($DeviceId -notin (Invoke-AdbGetAvailableDevices)) {
                Write-Warning "There's no available device with an id of '$DeviceId'"
                return $null
            }
            return $DeviceId.StartsWith("emulator-")
        }
    }
}

function Invoke-AdbIsKeyBoardOpen {

    [CmdletBinding()]
    [OutputType([bool[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId
    )

    process {
        foreach ($id in $DeviceId) {
            try {
                [bool]::Parse(($id | Invoke-Adb -Command "shell dumpsys input_method" | Select-String -Pattern "mInputShown=(true|false)").Matches[0].Groups[1].Value)
            }
            catch {
                Write-Error "Couldn't determine if the device with id '$id' is a real device or an emulator"
            }
        }
    }
}

function Invoke-AdbShowKeyboard {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $DeviceId
    )

    process {
        foreach ($id in $DeviceId) {
            $id | Invoke-AdbKeyEvent -KeyCode BUTTON_START
        }
    }
}

function Invoke-AdbHideKeyboard {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $DeviceId
    )

    process {
        foreach ($id in $DeviceId) {
            $id | Invoke-AdbKeyEvent -KeyCode ESCAPE
        }
    }
}

function Invoke-AdbStartOrResumeApp {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [string[]] $ApplicationId
    )

    process {
        foreach ($id in $DeviceId) {
            foreach ($appId in $ApplicationId) {
                $id | Invoke-Adb -Command "shell monkey -p ""$appId"" -c android.intent.category.LAUNCHER 1" -Verbose:$VerbosePreference | Out-Null
            }
        }
    }
}

function Invoke-AdbStopApp {

    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [string[]] $ApplicationId
    )

    process {
        foreach ($id in $DeviceId) {
            foreach ($appId in $ApplicationId) {
                $result = $id | Invoke-Adb -Command "shell am force-stop ""$appId""" -Verbose:$VerbosePreference
                Write-Verbose "Force stop ""$appId"": $result"
            }
        }
    }
}

# If the app is open it will be close after calling this function
function Invoke-AdbClearAppData {

    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [string[]] $ApplicationId
    )

    process {
        foreach ($id in $DeviceId) {
            foreach ($appId in $ApplicationId) {
                $result = $id | Invoke-Adb -Command "shell pm clear ""$appId""" -Verbose:$VerbosePreference
                Write-Verbose "Clear data from ""$appId"": $result"
            }
        }
    }
}

function Invoke-AdbGetApplicationPid {

    [OutputType([uint[]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [string[]] $ApplicationId
    )

    process {
        foreach ($id in $DeviceId) {
            foreach ($appId in $ApplicationId) {
                [uint] ($id | Invoke-Adb -Command "shell pidof ""$appId""" -Verbose:$VerbosePreference)
            }
        }
    }
}

# TODO: Doesn't seem to work with real devices
# I should test it on different API levels: https://stackoverflow.com/a/28573364/18418162, https://stackoverflow.com/a/45217400/18418162
function Invoke-AdbGetForegroundApplicationId {

    [OutputType([string[]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId
    )

    process {
        foreach ($id in $DeviceId) {
            if (-not (Invoke-AdbTestEmulator -DeviceId $id)) {
                Write-Error "Can't get foreground application in real device. Device id: '$id'"
                return
            }
        }
        $DeviceId | Invoke-Adb -Command "shell dumpsys window windows" -Verbose:$VerbosePreference
        | Select-String -Pattern "mCurrentFocus=.+ u0 (.+)/" -AllMatches
        | Select-Object -ExpandProperty Matches
        | ForEach-Object { $_.Groups[1].Value }
    }
}

function Invoke-AdbGetFontScale {

    [OutputType([float[]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId
    )

    process {
        foreach ($id in $DeviceId) {
            $result = ($id | Invoke-Adb -Command "shell settings get system font_scale" -Verbose:$VerbosePreference) -as [float]
            if ($result) {
                return $result
            }
            else {
                # When it's null it means it's the default value, 1
                return 1.0
            }
        }
    }
}

function Invoke-AdbSetFontScale {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [ValidateRange(0.25, 5)]
        [float] $FontScale
    )

    process {
        foreach ($id in $DeviceId) {
            $id | Invoke-Adb -Command "shell settings put system font_scale $FontScale" -Verbose:$VerbosePreference | Out-Null
        }
    }
}

function Invoke-AdbGetCurrentScreenViewHierarchyContent {

    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        # It's not a perfect, but it's good enough
        [switch] $NormalizeText
    )

    begin {
        if ($NormalizeText) {
            #region NormalizeText mapping
            $mapping = New-Object System.Collections.Hashtable
            $mapping["├Ñ"] = "å"
            $mapping["─à"] = "ą"
            $mapping["├ª"] = "æ"
            $mapping["─ü"] = "ā"
            $mapping["┬¬"] = "ª"
            $mapping["├í"] = "á"
            $mapping["├á"] = "à"
            $mapping["├ñ"] = "ä"
            $mapping["├ó"] = "â"
            $mapping["├ú"] = "ã"
            $mapping["├à"] = "Å"
            $mapping["─ä"] = "Ą"
            $mapping["├å"] = "Æ"
            $mapping["─Ç"] = "Ā"
            $mapping["├ü"] = "Á"
            $mapping["├Ç"] = "À"
            $mapping["├ä"] = "Ä"
            $mapping["├é"] = "Â"
            $mapping["├â"] = "Ã"
            $mapping["─ù"] = "ė"
            $mapping["├¬"] = "ê"
            $mapping["─Ö"] = "ę"
            $mapping["─ô"] = "ē"
            $mapping["├¿"] = "è"
            $mapping["├®"] = "é"
            $mapping["├®"] = "é"
            $mapping["├½"] = "ë"
            $mapping["─û"] = "Ė"
            $mapping["├è"] = "Ê"
            $mapping["─ÿ"] = "Ę"
            $mapping["─Æ"] = "Ē"
            $mapping["├ê"] = "È"
            $mapping["├ë"] = "É"
            $mapping["├ï"] = "Ë"
            $mapping["─½"] = "ī"
            $mapping["├«"] = "î"
            $mapping["─»"] = "į"
            $mapping["├¼"] = "ì"
            $mapping["├»"] = "ï"
            $mapping["├¡"] = "í"
            $mapping["─¬"] = "Ī"
            $mapping["├Ä"] = "Î"
            $mapping["─«"] = "Į"
            $mapping["├î"] = "Ì"
            $mapping["├Å"] = "Ï"
            $mapping["├ì"] = "Í"
            $mapping["┬║"] = "º"
            $mapping["┼ì"] = "ō"
            $mapping["┼ô"] = "œ"
            $mapping["├©"] = "ø"
            $mapping["├Á"] = "õ"
            $mapping["├┤"] = "ô"
            $mapping["├Â"] = "ö"
            $mapping["├▓"] = "ò"
            $mapping["├│"] = "ó"
            $mapping["┼î"] = "Ō"
            $mapping["┼Æ"] = "Œ"
            $mapping["├ÿ"] = "Ø"
            $mapping["├ò"] = "Õ"
            $mapping["├ö"] = "Ô"
            $mapping["├û"] = "Ö"
            $mapping["├Æ"] = "Ò"
            $mapping["├ô"] = "Ó"
            $mapping["┼½"] = "ū"
            $mapping["├╣"] = "ù"
            $mapping["├╗"] = "û"
            $mapping["├╝"] = "ü"
            $mapping["├║"] = "ú"
            $mapping["┼¬"] = "Ū"
            $mapping["├Ö"] = "Ù"
            $mapping["├ø"] = "Û"
            $mapping["├£"] = "Ü"
            $mapping["├Ü"] = "Ú"
            $mapping["├▒"] = "ñ"
            $mapping["┼ä"] = "ń"
            $mapping["├æ"] = "Ñ"
            $mapping["┼â"] = "Ń"
            $mapping["─ì"] = "č"
            $mapping["├º"] = "ç"
            $mapping["─ç"] = "ć"
            $mapping["─î"] = "Č"
            $mapping["├ç"] = "Ç"
            $mapping["─å"] = "Ć"

            $mapping["┬á"] = " "
            $mapping["┬┐"] = "¿"
            $mapping["┬í"] = "¡"
            $mapping["┬½"] = "«"
            $mapping["┬╗"] = "»"
            $mapping["ÔÇª"] = "…"
            $mapping["┬À"] = "·"
            $mapping["Ôé¼"] = "€"
            $mapping["ÔÇó"] = "•"
            $mapping["├À"] = "÷"
            $mapping["├ù"] = "×"
            $mapping["┬º"] = "§"
            $mapping["Ôêå"] = "∆"
            $mapping["┬ú"] = "£"
            $mapping["┬Ñ"] = "¥"
            $mapping["┬ó"] = "¢"
            $mapping["┬░"] = "°"
            $mapping["┬®"] = "©"
            $mapping["┬«"] = "®"
            $mapping["Ôäó"] = "™"
            $mapping["Ô£ô"] = "✓"
            $mapping["ÔàÖ"] = "⅙"
            $mapping["ÔàÉ"] = "⅐"
            $mapping["Ô£ô"] = "⅛"
            $mapping["Ôàø"] = "⅑"
            $mapping["Ôàæ"] = "⅒"
            $mapping["ÔàÆ"] = "¹"
            $mapping["┬╣"] = "¹"
            $mapping["┬¢"] = "½"
            $mapping["Ôàô"] = "⅓"
            $mapping["┬╝"] = "¼"
            $mapping["Ôàò"] = "⅕"
            $mapping["┬▓"] = "²"
            $mapping["Ôàö"] = "⅔"
            $mapping["Ôàû"] = "⅖"
            $mapping["Ôàù"] = "⅗"
            $mapping["┬│"] = "³"
            $mapping["┬¥"] = "¾"
            $mapping["Ôà£"] = "⅜"
            $mapping["Ôü┤"] = "⁴"
            $mapping["Ôàÿ"] = "⅘"
            $mapping["ÔàØ"] = "⅝"
            $mapping["ÔüÁ"] = "⁵"
            $mapping["ÔàÜ"] = "⅚"
            $mapping["ÔüÂ"] = "⁶"
            $mapping["ÔüÀ"] = "⁷"
            $mapping["Ôà×"] = "⅞"
            $mapping["Ôü©"] = "⁸"
            $mapping["Ôü╣"] = "⁹"
            $mapping["Ôêà"] = "∅"
            $mapping["Ôü┐"] = "ⁿ"
            $mapping["Ôü░"] = "⁰"
            $mapping["Ôäû"] = "№"
            $mapping["Ôé╣"] = "₹"
            $mapping["Ôé▒"] = "₱"
            $mapping["Ôÿà"] = "★"
            $mapping["ÔÇá"] = "†"
            $mapping["ÔÇí"] = "‡"
            $mapping["ÔÇ×"] = '„'
            $mapping["ÔÇ£"] = '“'
            $mapping["ÔÇÜ"] = "‚"
            $mapping["ÔÇÖ"] = "’"
            $mapping["ÔÇ╣"] = "‹"
            $mapping["ÔÇ║"] = "›"
            $mapping["ÔÇ¢"] = "‽"
            $mapping["ÔÇö"] = "—"
            $mapping["ÔÇô"] = "–"
            $mapping["┬▒"] = "±"
            $mapping["ÔÇ░"] = "‰"
            $mapping["Ôäà"] = "℅"
            $mapping["ÔÇ▓"] = "′"
            $mapping["ÔÇ│"] = "″"
            $mapping["ÔåÉ"] = "←"
            $mapping["Ôåæ"] = "↑"
            $mapping["Ôåô"] = "↓"
            $mapping["ÔåÆ"] = "→"
            $mapping["┬Â"] = "¶"
            $mapping["╬®"] = "Ω"
            $mapping["╬á"] = "Π"
            $mapping["╬╝"] = "μ"
            #endregion
        }
    }

    process {
        foreach ($id in $DeviceId) {
            $apiLevel = [uint] (Invoke-AdbGetProp -DeviceId $id -PropertyName ro.build.version.sdk)
            if ($apiLevel -le 23) {
                Write-Error "'adb exec-out uiautomator dump' is not available for api levels lower or equal to 23. Device id: '$id', api level: '$apiLevel'"
                return
            }
        }
        return $DeviceId | Invoke-Adb -Command "exec-out uiautomator dump /dev/tty" -Verbose:$VerbosePreference
        | Out-String
        | ForEach-Object { $_.Replace("UI hierchary dumped to: /dev/tty", "") }
        | ForEach-Object {
            # Suppress any possible exception stacktrance like "java.io.FileNotFoundException [...] Caused by: android.system.ErrnoException: open failed: ENOENT (No such file or directory) [...]"
            $xmlHeaderIndex = $_.IndexOf("<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>")
            $_.Substring($xmlHeaderIndex)
        }
        | ForEach-Object {
            if (-not $NormalizeText) {
                $_
            }
            else {
                $result = $_

                foreach ($key in $mapping.Keys) {
                    $result = $result.Replace($key, $mapping[$key])
                }
                $result
            }
        }
    }
}

function Invoke-AdbGrantPermission {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [string[]] $ApplicationId,

        [Parameter(Mandatory)]
        [string[]] $Permission
    )

    process {
        foreach ($id in $DeviceId) {
            foreach ($appId in $ApplicationId) {
                foreach ($permissionName in $Permission) {
                    $id | Invoke-Adb -Command "shell pm grant ""$appId"" ""$permissionName""" -Verbose:$VerbosePreference | Out-Null
                }
            }
        }
    }
}

function Invoke-AdbRevokePermission {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [string[]] $ApplicationId,

        [Parameter(Mandatory)]
        [string[]] $Permission
    )

    process {
        foreach ($id in $DeviceId) {
            foreach ($appId in $ApplicationId) {
                foreach ($permissionName in $Permission) {
                    $id | Invoke-Adb -Command "shell pm revoke ""$appId"" ""$permissionName""" -Verbose:$VerbosePreference
                }
            }
        }
    }
}


#### TODO: I should learn more before implementing this function
# https://stackoverflow.com/a/75021052/18418162
# https://developer.android.com/training/permissions/usage-notes
# function Invoke-AdbGetPermission {

#     [OutputType([string[]])]
#     [CmdletBinding()]
#     param (
#         [Parameter(Mandatory, ValueFromPipeline)]
#         [string[]] $DeviceId,

#         [Parameter(Mandatory)]
#         [string[]] $ApplicationId,

#         [Parameter(ParameterSetName = "Granted")]
#         [switch] $Granted,

#         [Parameter(ParameterSetName = "Revoked")]
#         [switch] $Revoked
#     )

#     begin {
#         if ($Granted) {
#             $grantedArg = "true"
#         }
#         if ($Revoked) {
#             $grantedArg = "false"
#         }
#     }

#     process {
#         foreach ($id in $DeviceId) {
#             foreach ($appId in $ApplicationId) {
#                 (Invoke-Adb -Command "shell dumpsys package $appId" | Out-String | Select-String -Pattern "(\S+\.permission\.\S+): granted=$grantedArg" -AllMatches).Matches
#                 | Where-Object { $null -ne $_ }
#                 | ForEach-Object { $_.Groups[1].Value }
#             }
#         }
#     }

# }



Register-ArgumentCompleter `
    -CommandName (Get-Command -Module $MyInvocation.MyCommand.ModuleName -Name "Invoke-Adb*") `
    -ParameterName DeviceId -ScriptBlock {

    param(
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    Invoke-AdbGetAvailableDevices | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        $deviceName = Invoke-AdbGetDeviceNameById -DeviceId $_
        $apiLevel = Invoke-AdbGetProp -DeviceId $_ -PropertyName "ro.build.version.sdk"

        New-Object -Type System.Management.Automation.CompletionResult -ArgumentList @(
            $_
            "$_ ($deviceName, $apiLevel)"
            'ParameterValue'
            "Device: $deviceName`nAPI level: $apiLevel"
        )
    }
}

Register-ArgumentCompleter -CommandName @(
    "Invoke-AdbStartOrResumeApp"
    "Invoke-AdbGetApplicationPid"
    "Invoke-AdbGrantPermission"
    "Invoke-AdbRevokePermission"
) `
    -ParameterName ApplicationId -ScriptBlock {

    param(
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    $deviceId = $fakeBoundParameters['DeviceId']

    $applicationIds = Invoke-AdbGetPackageList -DeviceId $deviceId

    $startMatches = $applicationIds | Where-Object { $_ -like "$wordToComplete*" }
    $containMatches = $applicationIds | Where-Object { $_ -like "*$wordToComplete*" -and $_ -notlike "$wordToComplete*" }
    $startMatches + $containMatches
}

Register-ArgumentCompleter -CommandName @(
    "Invoke-AdbGetProp"
    "Invoke-AdbSetProp"
) -ParameterName PropertyName -ScriptBlock {

    param(
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    $deviceId = $fakeBoundParameters['DeviceId']

    $properties = Invoke-AdbGetProp -DeviceId $deviceId -List | ForEach-Object {
        $_ -match '^\[(.*?)\]' > $null
        $Matches[1]
    }

    $startMatches = $properties | Where-Object { $_ -like "$wordToComplete*" }
    $containMatches = $properties | Where-Object { $_ -like "*$wordToComplete*" -and $_ -notlike "$wordToComplete*" }
    $startMatches + $containMatches
}

Register-ArgumentCompleter -CommandName @(
    "Invoke-AdbGetSetting"
    "Invoke-AdbSetSetting"
    "Invoke-AdbRemoveSetting"
) `
    -ParameterName Key -ScriptBlock {

    param(
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    $deviceId = $fakeBoundParameters['DeviceId']
    $namespace = $fakeBoundParameters['Namespace']

    $deviceId | Invoke-AdbGetSetting -Namespace $namespace -List
    | ForEach-Object { $_.Split("=")[0] }
    | Where-Object { $_ -like "$wordToComplete*" }
    | ForEach-Object { "$_" }
}



Export-ModuleMember *-*
