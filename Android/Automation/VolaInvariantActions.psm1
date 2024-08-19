Import-Module -Name "$PSScriptRoot/VolaAutomation.psm1" -Force


$applicationId = "com.volaplay.vola"


[uint] $ShortSleepTimeInMillis = 85
[uint] $MediumSleepTimeInMillis = 500
[uint] $LargeSleepTimeInMillis = 1000
[uint] $ExtraLargeSleepTimeInMillis = 2000


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

    param (
        [Parameter(Mandatory)]
        [string[]] $DeviceId
    )

    process {
        foreach ($id in $DeviceId) {
            if (Invoke-AdbTestKeyBoardOpen -DeviceId $id) {
                Invoke-AdbKeyEvent -DeviceId $Id -KeyCode BACK
                MediumSleep
            }
        }
    }
}

function GetStoredValue {

    param (
        [Parameter(Mandatory)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [string] $Key
    )

    process {
        foreach ($id in $DeviceId) {
            $result = Invoke-AdbGetSetting -DeviceId $id -Namespace Global -Key "testing.$Key" -Verbose:$VerbosePreference
            if ($result -eq "null" -or -not $result) {
                return $null
            }
            else {
                return $result
            }
        }
    }
}

function SetStoredValue {

    param (
        [Parameter(Mandatory)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [string] $Key,

        [Parameter(Mandatory)]
        [string] $Value
    )

    process {
        foreach ($id in $DeviceId) {
            Invoke-AdbSetSetting -DeviceId $id -Namespace Global -Key "testing.$Key" -Value $Value -Verbose:$VerbosePreference
        }
    }
}

function Tap {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [float] $X,

        [Parameter(Mandatory)]
        [float] $Y
    )

    process {
        foreach ($id in $DeviceId) {
            Invoke-AdbTap -DeviceId $id -X $X -Y $Y -Verbose:$VerbosePreference
        }
    }
}

function GetNodeCenterPosition {

    [OutputType([float[]])]
    [CmdletBinding()]
    param (
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

    return @($centerX, $centerY)
}

function Invoke-VolaInvariantTap {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [scriptblock] $NodePredicate
    )

    process {
        foreach ($id in $DeviceId) {
            $key = Get-PSCallStack | Select-Object -SkipLast 1 | Select-Object -Last 1 | ForEach-Object {
                $functionName = $_.Command
                $argumentAsString = $_.InvocationInfo.BoundParameters.GetEnumerator()
                | Where-Object { $_.Key -ne "DeviceId" -and $_.Key -notin @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer') }
                | ForEach-Object { "$($_.Key)=$($_.Value)" }
                | Join-String -Separator "."

                "$($functionName):_$($argumentAsString)_"
            }

            $position = GetStoredValue -DeviceId $id -Key $key -Verbose:$VerbosePreference
            if (-not $position) {
                $nodes = Invoke-AdbGetCurrentScreenViewHierarchyNode -DeviceId $id -NormalizeText -Verbose:$VerbosePreference
                $targetNode = $nodes | Where-Object { $NodePredicate.Invoke($_) }

                $centerX, $centerY = GetNodeCenterPosition $targetNode

                $position = "$centerX,$centerY"

                SetStoredValue -DeviceId $id -Key $key -Value $position -Verbose:$VerbosePreference
            }

            $positionSplit = $position.Split(",")
            $x = [float] $positionSplit[0]
            $y = [float] $positionSplit[1]

            Tap -DeviceId $id -X $x -Y $y
        }
    }
}

function Invoke-VolaProfileMenu_Logout {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]] $DeviceId
    )

    process {
        foreach ($id in $DeviceId) {
            if (-not (Invoke-VolaCheckCurrentScreen -DeviceId $id -ActivityName "NewSettingsActivity")) {
                return
            }

            Invoke-VolaInvariantTap -DeviceId $id -NodePredicate { param ($node)
                $node.'resource-id'.EndsWith('logout')
            }
        }
    }
}

function Invoke-VolaHome_GoToProfileMenu {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]] $DeviceId
    )

    process {
        foreach ($id in $DeviceId) {
            foreach ($id in $DeviceId) {
                if (-not (Invoke-VolaCheckCurrentScreen -DeviceId $id -ActivityName "HomeActivity")) {
                    return
                }

                Invoke-VolaInvariantTap -DeviceId $id -NodePredicate { param ($node)
                    $node.'resource-id'.EndsWith('imvProfile')
                }
            }
        }
    }
}

function Invoke-VolaTopLevelAction {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [ValidateSet('Home', 'Ranking', 'Bookings', 'Instructors', 'Eshop')]
        [string] $ClickOn,

        [string] $Locale = (Get-VolaLocale -DeviceId $DeviceId)
    )

    process {
        foreach ($id in $DeviceId) {
            foreach ($id in $DeviceId) {
                if (-not (Invoke-VolaCheckCurrentScreen -DeviceId $id -ActivityName "HomeActivity")) {
                    return
                }

                $buttonName = switch ($ClickOn) {
                    Home { Get-VolaStringResourceById -Locale $Locale -Id "title_home" }
                    Ranking { Get-VolaStringResourceById -Locale $Locale -Id "drawer_ranking" }
                    Bookings { Get-VolaStringResourceById -Locale $Locale -Id "drawer_reservations" }
                    Instructors { Get-VolaStringResourceById -Locale $Locale -Id "drawer_monitors" }
                    Eshop { Get-VolaStringResourceById -Locale $Locale -Id "drawer_store" }
                }

                Invoke-VolaInvariantTap -DeviceId $id -NodePredicate { param ($node)
                    $node.text -like $buttonName
                }
            }
        }
    }
}

function Invoke-VolaHomeAction {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]] $DeviceId,

        [Parameter(Mandatory, ParameterSetName = "TopLevelDestination")]
        [ValidateSet('ProfileMenu')]
        [string] $ClickOn
    )

    process {
        foreach ($id in $DeviceId) {
            foreach ($id in $DeviceId) {
                if (-not (Invoke-VolaCheckCurrentScreen -DeviceId $id -ActivityName "HomeActivity")) {
                    return
                }

                switch ($CliClickOnck) {
                    ProfileMenu {
                        Invoke-VolaInvariantTap -DeviceId $id -NodePredicate { param ($node)
                            $node.'resource-id'.EndsWith('imvProfile')
                        }
                    }
                }
            }
        }
    }
}

function Invoke-VolaProfileMenuAction {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [ValidateSet('Logout', 'Profile')]
        [string] $ClickOn
    )

    process {
        foreach ($id in $DeviceId) {
            $targetNodeId = switch ($ClickOn) {
                Logout { 'logout' }
                Profile { 'profileLayout' }
            }
            Invoke-VolaInvariantTap -DeviceId $id -NodePredicate { param ($node)
                $node.'resource-id'.EndsWith($targetNodeId)
            }
        }
    }
}

function Invoke-VolaCompetitionsAction {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [ValidateSet(
            'OpenFilters', 'CloseFilters', 'Search',
            'Tournaments', "Tours", "Leagues"
        )]
        [string] $ClickOn
    )

    process {
        Write-Error "Not yet implemented"
        # TODO
        # foreach ($id in $DeviceId) {
        #     $targetNodeId = switch ($ClickOn) {
        #         Logout { 'logout' }
        #         Profile { 'profileLayout' }
        #     }
        #     Invoke-VolaInvariantTap -DeviceId $id -NodePredicate { param ($node)
        #         $node.'resource-id'.EndsWith($targetNodeId)
        #     }
        # }
    }
}

# It's not an invariant action
# function Invoke-VolaHome_GoToTournaments {

#     [CmdletBinding()]
#     param (
#         [Parameter(Mandatory)]
#         [string[]] $DeviceId
#     )

#     process {
#         foreach ($id in $DeviceId) {
#             foreach ($id in $DeviceId) {
#                 if (-not (Invoke-VolaCheckCurrentScreen -DeviceId $id -ActivityName "HomeActivity")) {
#                     return
#                 }

#                 [string] $appLocale = Invoke-AdbGetSharedPreferencesNode -DeviceId $DeviceId -Filename "SharedPreferences.xml" -ApplicationId $applicationId
#                 | Where-Object -Property "name" -EQ -Value "custom_locale" | Select-Object -Property InnerText

#                 [string] $deviceLocale = (Invoke-AdbGetProp -DeviceId $DeviceId -PropertyName ro.product.locale).Split("-")[0]

#                 $currentLocale = if ($appLocale) { $appLocale } else { $deviceLocale }

#                 Write-Verbose "Get app locale from settings: '$appLocale'"
#                 Write-Verbose "Get device locale: '$deviceLocale'"


#                 Invoke-VolaInvariantTap -DeviceId $id -NodePredicate { param ($node)
#                     $node.text -like (Get-VolaStringResourceById -Locale $currentLocale -Id "splash_text_welcome2_title")
#                 }
#             }
#         }
#     }
# }

function Invoke-VolaCompetitions_OpenFilters {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]] $DeviceId
    )

    process {
        foreach ($id in $DeviceId) {
            foreach ($id in $DeviceId) {
                if (-not (Invoke-VolaCheckCurrentScreen -DeviceId $id -ActivityName "NewSectionsDetailActivity")) {
                    return
                }

                Invoke-VolaInvariantTap -DeviceId $id -NodePredicate { param ($node)
                    $node.'resource-id'.EndsWith('btnFilter')
                }
            }
        }
    }
}

# function Invoke-VolaHome_GoToProfileMenu {

#     [CmdletBinding()]
#     param (
#         [Parameter(Mandatory)]
#         [string[]] $DeviceId,

#         [Parameter(Mandatory)]
#         [ValidateSet(
#             "Pixel_8_Pro_API_35",
#             "Medium_Phone_API_35",
#             "Small_Phone_API_35"
#         )]
#         [string] $DeviceType,

#         [switch] $DisableScreenCheck
#     )

#     begin {
#         if ($DisableScreenCheck) {
#             Write-Warning "Screen check disable, use it at your own risk"
#         }
#     }

#     process {
#         if ((Invoke-AdbGetApiLevel -DeviceId $DeviceId) -lt 35) {
#             Write-Error "This function is only meant to be used with API 35 devices"
#             return
#         }
#         $isNotInHomeFragment = -not (Invoke-AdbGetCurrentActivityFragmentStack -DeviceId $DeviceId | Select-Object -Last 1).Contains("HomeFragment")
#         if (-not $DisableScreenCheck -and $isNotInHomeFragment) {
#             Write-Error "Can't go to Profile Menu (NewSettingsActivity) if you are not in Home (HomeActivity)"
#             return
#         }

#         $screenWidth = (Invoke-AdbGetPhysicalSize -DeviceId $DeviceId)[0]
#         $halfScreenWidth = $screenWidth / 2

#         switch ($DeviceType) {
#             Pixel_8_Pro_API_35 {
#                 Invoke-AdbTap $DeviceId -X $halfScreenWidth -Y 460
#             }
#             Medium_Phone_API_35 {
#                 Invoke-AdbTap $DeviceId -X $halfScreenWidth -Y 335
#             }
#             Small_Phone_API_35 {
#                 Invoke-AdbTap $DeviceId -X $halfScreenWidth -Y 300
#             }
#         }
#     }
# }

function Invoke-VolaTopDestination_BottomBar {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]] $DeviceId,

        [Parameter(Mandatory)]
        [ValidateSet(
            "Pixel8Pro_API35",
            "MediumPhone_API35",
            "SmallPhone_API35"
        )]
        [string] $DeviceType,

        [Parameter(Mandatory)]
        [ValidateSet(
            "Home",
            "Ranking",
            "Bookings",
            "Instructors",
            "Eshop"
        )]
        [string] $TopDestination
    )

    process {
        if ((Invoke-AdbGetApiLevel -DeviceId $DeviceId) -lt 35) {
            Write-Error "This function is only meant to be used with API 35 devices"
            return
        }
        if (-not (Invoke-AdbGetTopActivity -DeviceId $DeviceId).Contains("HomeActivity")) {
            Write-Error "Can't go to $TopDestination if you are not in a top level location (HomeActivity)"
            return
        }

        $buttonY = switch ($DeviceType) {
            Pixel_8_Pro_API_35 { 2830 }
            Medium_Phone_API_35 { 2250 }
            Small_Phone_API_35 { 1170 }
        }

        $parameterList = (Get-Command -Name $MyInvocation.MyCommand).Parameters
        $topDestinationList = $parameterList["TopDestination"].Attributes.ValidValues
        $topDestinationIndex = $topDestinationList.IndexOf($TopDestination)

        $screenWidth = (Invoke-AdbGetPhysicalSize -DeviceId $DeviceId)[0]
        $buttonWidth = $screenWidth / $topDestinationList.Count
        $buttonX = ($buttonWidth / 2) + $topDestinationIndex * $buttonWidth

        Invoke-AdbTap -DeviceId $DeviceId -X $buttonX -Y $buttonY
    }
}


# function Invoke-VolaProfileMenu_Logout {

#     [CmdletBinding()]
#     param (
#         [Parameter(Mandatory)]
#         [string] $DeviceId,

#         [Parameter(Mandatory)]
#         [ValidateSet(
#             "Pixel_8_Pro_API_35",
#             "Medium_Phone_API_35",
#             "Small_Phone_API_35"
#         )]
#         [string] $DeviceType
#     )

#     process {
#         if ((Invoke-AdbGetApiLevel -DeviceId $DeviceId) -lt 35) {
#             Write-Error "This function is only meant to be used with API 35 devices"
#             return
#         }
#         if ("NewSettingsActivity" -notin (Invoke-AdbGetTopActivity -DeviceId $DeviceId)) {
#             Write-Error "Can't logout if you're not in Profile Menu (NewSettingsActivity)"
#             return
#         }

#         $screenWidth = (Invoke-AdbGetPhysicalSize -DeviceId $DeviceId)[0]
#         $halfScreenWidth = $screenWidth / 2


#         switch ($DeviceType) {
#             Pixel_8_Pro_API_35 {
#                 Invoke-AdbTap $DeviceId -X $halfScreenWidth -Y 2815
#             }
#             Medium_Phone_API_35 {
#                 Invoke-AdbTap $DeviceId -X $halfScreenWidth -Y 2245
#             }
#             Small_Phone_API_35 {
#                 Invoke-AdbTap $DeviceId -X $halfScreenWidth -Y 1165
#             }
#         }
#     }
# }

function Invoke-VolaBookings_OpenLocationSelector {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $DeviceId,

        [Parameter(Mandatory)]
        [ValidateSet(
            "Pixel_8_Pro_API_35",
            "Medium_Phone_API_35",
            "Small_Phone_API_35"
        )]
        [string] $DeviceType,

        [switch] $DisableScreenCheck,

        [Parameter(Mandatory, ParameterSetName = "SelectFirstLocation")]
        [switch] $SelectFirstLocation,

        [Parameter(Mandatory, ParameterSetName = "SelectFirstLocation")]
        [string] $Query,

        [Parameter(Mandatory, ParameterSetName = "NearMe")]
        [switch] $NearMe
    )

    begin {
        if ($DisableScreenCheck) {
            Write-Warning "Screen check disable, use it at your own risk"
        }
    }

    process {
        if ((Invoke-AdbGetApiLevel -DeviceId $DeviceId) -lt 35) {
            Write-Error "This function is only meant to be used with API 35 devices"
            return
        }
        $last = Invoke-AdbGetCurrentActivityFragmentStack -DeviceId $DeviceId | Select-Object -Last 1
        $isNotInBookingsFragment = -not $last.Contains("BookingsFragment")
        if (-not $DisableScreenCheck -and $isNotInBookingsFragment) {
            Write-Error "Can't open the location selector from the Book tap, you have to be on the Bookings screen (BookingsFragment)"
            return
        }

        $screenWidth = (Invoke-AdbGetPhysicalSize -DeviceId $DeviceId)[0]
        $halfScreenWidth = $screenWidth / 2


        switch ($DeviceType) {
            Pixel_8_Pro_API_35 {
                Invoke-AdbTap $DeviceId -X 0 -Y 400
                Start-Sleep -Milliseconds 800
                Invoke-AdbTap $DeviceId -X $halfScreenWidth -Y 565
                Start-Sleep -Milliseconds 450

                if ($NearMe) {
                    Invoke-AdbTap $DeviceId -X 220 -Y 1480
                }
                if ($SelectFirstLocation) {
                    Invoke-AdbTap $DeviceId -X $halfScreenWidth -Y 1670
                    Start-Sleep -Milliseconds 450
                    Invoke-AdbText -DeviceId $DeviceId -Text $Query
                    Invoke-AdbKeyEvent -DeviceId $DeviceId -KeyEvent ENTER
                    Start-Sleep -Milliseconds 1500
                    Invoke-AdbTap $DeviceId -X $halfScreenWidth -Y 1860
                }
            }
            Medium_Phone_API_35 {
                Invoke-AdbTap $DeviceId -X 0 -Y 265
                Start-Sleep -Milliseconds 800
                Invoke-AdbTap $DeviceId -X $halfScreenWidth -Y 410
                Start-Sleep -Milliseconds 450

                if ($NearMe) {
                    Invoke-AdbTap $DeviceId -X 200 -Y 1060
                }
            }
            Small_Phone_API_35 {
                Invoke-AdbSwipe -DeviceId $DeviceId -X1 $halfScreenWidth -Y1 100 -X2 $halfScreenWidth -Y2 500
                Start-Sleep -Milliseconds 450
                Invoke-AdbTap $DeviceId -X 0 -Y 265
                Start-Sleep -Milliseconds 450
                Invoke-AdbTap $DeviceId -X 0 -Y 40

                Invoke-AdbTap $DeviceId -X $halfScreenWidth -Y 320

                if ($NearMe) {
                    Invoke-AdbTap $DeviceId -X 140 -Y 260
                }
            }
        }
    }
}



Export-ModuleMember *-*
