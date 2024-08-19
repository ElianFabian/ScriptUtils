Import-Module -Name "$PSScriptRoot/AdbModule.psm1" -Force

function Invoke-AdbPrettyPrintAvailableDevice {
    $availableDevices = Invoke-AdbGetAvailableDevices

    Write-Host

    if (-not $availableDevices) {
        Write-Error "There are no available devices right now"
        Write-Host
        return
    }

    $longestIdLength = ($availableDevices | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $longestDeviceName = ($availableDevices | Invoke-AdbGetDeviceNameById | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum

    $spaceSize = 5

    Write-Host "$("DeviceId".PadRight($longestIdLength + $spaceSize, " "))$("Name".PadRight($longestDeviceName + $spaceSize, " "))API level" -ForegroundColor Green
    Write-Host "$("--------".PadRight($longestIdLength + $spaceSize, " "))$("----".PadRight($longestDeviceName + $spaceSize, " "))---------" -ForegroundColor Green

    foreach ($id in $availableDevices) {
        $deviceName = Invoke-AdbGetDeviceNameById -DeviceId $id
        if (-not $deviceName) {
            Write-Error "Couldn't get device name from device id '$id'"
            return
        }

        Write-Host $id.PadRight($longestIdLength + $spaceSize, " ") -NoNewline -ForegroundColor Cyan
        Write-Host $deviceName.PadRight($longestDeviceName + $spaceSize, " ") -NoNewline -ForegroundColor DarkCyan
        Write-Host $(Invoke-AdbGetApiLevel -DeviceId $id) -NoNewline

        Write-Host
    }
    Write-Host
}

function Invoke-AdbGetTopActivity {

    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory)]
        [string[]] $DeviceId,

        [switch] $GroupByDeviceId
    )

    $activityPerDeviceId = [ordered]@{}

    foreach ($id in $DeviceId) {
        $activityName = (Invoke-Adb -DeviceId $id -Command "shell dumpsys activity activities" -Verbose:$VerbosePreference | Select-String -Pattern "topResumedActivity=.+{.+ .+ (.+) .+}" -AllMatches)
        | ForEach-Object { $_.Matches[0].Groups[1].Value.Replace('/', '') }

        $activityPerDeviceId.$id = $activityName
    }

    if ($GroupByDeviceId) {
        return $activityPerDeviceId
    }

    return $activityPerDeviceId.Values
}

# It's not reliable, sometimes it does not get anything
function Invoke-AdbGetTopFragment {

    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId
    )

    begin {
        Write-Warning "Getting top fragment it's not reliable, sometimes it gets nothing, use it at your own risk."
    }

    process {
        foreach ($id in $DeviceId) {
            $appData = Invoke-Adb -DeviceId $id -Command "shell dumpsys activity top" -Verbose:$VerbosePreference

            # In case there is only one single Fragment we have to do it like this:
            [string[]] $singleFragmentMatches = ($appData | Select-String -Pattern "mParent=(.+){.+}" -AllMatches).Matches
            | ForEach-Object { $_.Groups[1].Value }
            | Select-Object -Unique
            | Where-Object { $_.Length -gt 3 } # To filter things like zzd
            | Where-Object { -not $_.Contains("SupportRequestManagerFragment") }
            | Where-Object { -not $_.Contains("ReportFragment") }

            $navHostFragmentMatch = $singleFragmentMatches
            | Where-Object { $_.Contains("NavHostFragment") }

            $fragmentNames = $singleFragmentMatches
            if ($navHostFragmentMatch) {
                $navHostFragmentIndex = $singleFragmentMatches.IndexOf($navHostFragmentMatch)
                [string[]] $fragmentNames = $singleFragmentMatches[0..($navHostFragmentIndex - 1)]
            }

            if ($fragmentNames.Count -eq 1) {
                return $fragmentNames
            }


            # In case there are multiple fragments we do it this way:
            return ($appData | Select-String -Pattern "SET_PRIMARY_NAV (.+){.+}.+" -AllMatches).Matches
            | Select-Object -Last 1
            | Where-Object { $_ }
            | ForEach-Object { $_.Groups[1].Value }
        }
    }
}

function Invoke-AdbGetTopActivityFragmentStack {

    [CmdletBinding(DefaultParameterSetName = "Default")]
    [OutputType([PSCustomObject], ParameterSetName = "Default")]
    [OutputType([string[]], ParameterSetName = "GroupByDeviceId")]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(ParameterSetName = "GroupByDeviceId")]
        [switch] $GroupByDeviceId
    )

    Write-Warning "The order of the fragment stack is not reliable, use it at your own risk"

    $stackPerDeviceId = [ordered]@{}

    foreach ($id in $DeviceId) {
        $appData = Invoke-Adb -DeviceId $id -Command "shell dumpsys activity top" -Verbose:$VerbosePreference

        # We have to check 2 cases, one in case there is a single Fragment and when there are multiple Fragments
        # We first check for the single Fragment case
        $singleFragmentMatches = ($appData | Select-String -Pattern "mParent=(.+){[0-9a-f]{7}}" -AllMatches).Matches
        | ForEach-Object { $_.Groups[1].Value }
        | Select-Object -Unique
        | Where-Object { -not $_.Contains("SupportRequestManagerFragment") }

        $navHostFragmentMatch = $singleFragmentMatches
        | Where-Object { $_.Contains("NavHostFragment") }

        $navHostFragmentIndex = $singleFragmentMatches.IndexOf($navHostFragmentMatch)

        $fragmentNames = $singleFragmentMatches[0..($navHostFragmentIndex - 1)]

        if ($fragmentNames.Length -eq 1) {
            $stackPerDeviceId.$id = $fragmentNames
            continue
        }

        # Here we have the multiple fragments case
        $fragmentNames = ($appData | Select-String -Pattern "Op #\d+: [A-Z_]+ (.+){.+}" -AllMatches).Matches
        | ForEach-Object { $_.Groups[1].Value }
        | Select-Object -Unique

        $stackPerDeviceId.$id = $fragmentNames
    }

    if ($GroupByDeviceId) {
        return $stackPerDeviceId
    }

    return $stackPerDeviceId.GetEnumerator() | ForEach-Object { $_.Value }
}

function Invoke-AdbGetApiLevel {

    [CmdletBinding()]
    [OutputType([uint[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId
    )

    process {
        $DeviceId | Invoke-AdbGetProp -PropertyName "ro.build.version.sdk" -Verbose:$VerbosePreference | ForEach-Object {
            [uint] $_
        }
    }
}

function Invoke-AdbGetCurrentScreenViewHierarchyNode {

    [CmdletBinding()]
    [OutputType([System.Xml.XmlLinkedNode[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [switch] $NormalizeText
    )

    return $DeviceId | Invoke-AdbGetCurrentScreenViewHierarchyContent -NormalizeText:$NormalizeText -Verbose:$VerbosePreference
    | Select-Xml -XPath "//node" | ForEach-Object { $_.Node }
}

function Invoke-AdbTapNode {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [System.Xml.XmlLinkedNode] $Node
    )

    [string] $bounds = $Node.bounds
    $cornersStr = $bounds.Trim("[]").Split("][")
    $leftTopCornerStr = $cornersStr[0].Split(",")
    $rightBottomStr = $cornersStr[1].Split(",")

    $leftTopCornerX = [float] $leftTopCornerStr[0]
    $leftTopCornerY = [float] $leftTopCornerStr[1]
    $rightBottomX = [float] $rightBottomStr[0]
    $rightBottomY = [float] $rightBottomStr[1]

    $centerX = ($leftTopCornerX + $rightBottomX) / 2
    $centerY = ($leftTopCornerY + $rightBottomY) / 2

    $DeviceId | Invoke-AdbTap -X $centerX -Y $centerY -Verbose:$VerbosePreference
}

function Invoke-AdbGetSharedPreferencesContent {

    [OutputType([string[]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [string] $ApplicationId,

        [Parameter(Mandatory)]
        [string] $Filename
    )

    process {
        $command = "shell run-as $ApplicationId cat /data/data/$ApplicationId/shared_prefs/$Filename"
        foreach ($id in $DeviceId) {
            $id | Invoke-Adb -Command $command -Verbose:$VerbosePreference | Out-String
        }
    }
}

function Invoke-AdbGetSharedPreferencesNode {

    [OutputType([System.Xml.XmlLinkedNode[]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [string] $ApplicationId,

        [Parameter(Mandatory)]
        [string] $Filename
    )

    $DeviceId | Invoke-AdbGetSharedPreferencesContent -ApplicationId $ApplicationId -Filename $Filename
    | ForEach-Object {
        $xml = [xml] $_
        $xml.map.ChildNodes
    }
    | ForEach-Object {
        [System.Xml.XmlLinkedNode] $_
    }
}



Export-ModuleMember *-*
