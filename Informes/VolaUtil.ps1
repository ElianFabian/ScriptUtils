function Get-VolaDbData {

    [OutputType([PSCustomObject[]])]
    param (
        [string] $Query
    )

    $ip = $env:Vola_ProdIp
    $port = '3306'
    $user = $env:Vola_ProdUser
    $password = $env:Vola_ProdPassword
    $database = 'padelmanager'

    if (-not $ip) {
        throw "Establece el ip del servidor de Vola de producción en la variable de entorno Vola_ProdId"
    }
    if (-not $user) {
        throw "Establece el usuario de Vola de producción en la variable de entorno Vola_ProdPassword"
    }
    if (-not $password) {
        throw "Establece la contraseña del usuario de Vola de producción en la variable de entorno Vola_ProdPassword"
    }

    Write-Verbose $Query

    return mysql -h $ip -P $port -u $user --password="$password" $database -B -e $Query `
    | ConvertFrom-Csv -Delimiter "`t"
}


function Get-LatamCountries {
    return 'Chile', 'Uruguay', 'Paraguay', 'Argentina', 'Perú', 'Colombia'
}

function Get-ExcelSafeWorksheetName {
    param (
        [string] $Name
    )

    $invalidCharsRegex = '[\[\]\*\?/\\:]'
    $sanitized = ($Name -replace $invalidCharsRegex, '') -replace '\s+', ' '
    if ($sanitized.Length -gt 31) {
        $sanitized = $sanitized.Substring(0, 31)
    }

    return $sanitized.Trim()
}

function Ensure-ImportExcel {
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        throw "El módulo ImportExcel no está instalado. Instálalo con 'Install-Module ImportExcel -Scope CurrentUser' y vuelve a ejecutar."
    }

    Import-Module ImportExcel -ErrorAction Stop
}

function Export-VolaWorkbook {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [hashtable] $SheetData,

        [switch] $AutoSize,
        [switch] $BoldTopRow
    )

    Ensure-ImportExcel

    $Path = [System.IO.Path]::GetFullPath($Path)
    $folder = Split-Path -Path $Path -Parent
    if ($folder -and -not (Test-Path $folder)) {
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
    }

    if (Test-Path $Path) {
        Remove-Item -Path $Path -Force
    }

    foreach ($worksheetName in $SheetData.Keys) {
        $data = $SheetData[$worksheetName]
        if (-not $data) {
            $data = @()
        }

        $safeWorksheetName = Get-ExcelSafeWorksheetName -Name $worksheetName

        $exportParams = @{
            Path = $Path
            WorksheetName = $safeWorksheetName
            TableName = ($safeWorksheetName -replace '\s+', '_')
            FreezeTopRow = $true
            Append = (Test-Path $Path)
        }

        if ($AutoSize.IsPresent) {
            $exportParams.AutoSize = $true
        }
        if ($BoldTopRow.IsPresent) {
            $exportParams.BoldTopRow = $true
        }

        if ($data -and $data.Count -gt 0) {
            $data | Export-Excel @exportParams
        }
        else {
            Export-Excel -Path $Path -WorksheetName $safeWorksheetName -InputObject @() @exportParams
        }
    }

    return $Path
}

function Export-VolaWorkbookLatam {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [hashtable] $SheetData,

        [switch] $AutoSize,
        [switch] $BoldTopRow
    )

    $paisesLatam = Get-LatamCountries
    $filteredData = [ordered]@{}

    foreach ($worksheetName in $SheetData.Keys) {
        $data = $SheetData[$worksheetName]

        if ($data | Get-Member -Name 'País' -ErrorAction SilentlyContinue) {
            $latamData = $data | Where-Object { $_.'País' -in $paisesLatam }
            $filteredData[$worksheetName] = if ($latamData) { $latamData } else { @() }
        }
        else {
            $filteredData[$worksheetName] = @()
        }
    }

    Export-VolaWorkbook -Path $Path -SheetData $filteredData -AutoSize:$AutoSize.IsPresent -BoldTopRow:$BoldTopRow.IsPresent
}

function Convert-PayProDateFormat {

    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $PayProDate
    )

    $format = 'MM/dd/yyyy HH:mm:ss'
    try {
        $date = [DateTime]::ParseExact($PayProDate, $format, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        throw "El formato de fecha no es válido. Se esperaba 'MM/dd/yyyy HH:mm:ss', por ejemplo '05/29/2026 15:07:29'. Valor recibido: '$PayProDate'"
    }

    return $date.ToString('yyyy-MM-dd HH:mm')
}

function Export-VolaDataAsCsv {

    param (
        [string] $FechaInicio,

        [string] $FechaFin,

        [ValidateSet('Lunes', 'Viernes')]
        [string] $Paquete,

        [string] $NombreDeFicheroBase,

        [PSCustomObject[]] $Data,

        [switch] $ReturnData
    )

    $dateRegex = '^\d{4}-\d{2}-\d{2}$'

    if ($FechaInicio -and $FechaInicio -notmatch $dateRegex) {
        throw "El parámetro FechaInicio no tiene un formato válido (AAAA-MM-DD): '$FechaIncio'"
    }
    if ($FechaFin -and $FechaFin -notmatch $dateRegex) {
        throw "El parámetro FechaFin no tiene un formato válido (AAAA-MM-DD): '$FechaFin'"
    }
    if ($FechaFin -and -not $FechaInicio) {
        throw "Si se establece la fecha de inicio también se tiene que establecer la fecha de fin"
    }

    $sanitizedData = if ($Data) {
        $Data
    }
    else {
        @()
    }
    $paisesLatam = Get-LatamCountries
    $latamData = $sanitizedData | Where-Object { $_.'País' -in $paisesLatam }

    $fechaActual = Get-Date -Format 'yyyy-MM-dd'

    $carpeta = "Paquete $Paquete CSV"
    New-Item -Name $carpeta -ItemType Directory -Force > $null

    if ($FechaInicio -and $FechaFin) {
        $rangoDeFecha = "__$FechaInicio-$FechaFin"
    }

    $sanitizedData | Export-Csv -Delimiter ';' -Path "$carpeta/$($NombreDeFicheroBase)__$($fechaActual)$rangoDeFecha.csv" -Force -Verbose
    $latamData | Export-Csv -Delimiter ';' -Path "$carpeta/$($NombreDeFicheroBase)__$($fechaActual)$rangoDeFecha-LATAM.csv" -Force -Verbose

    if ($ReturnData.IsPresent) {
        return $sanitizedData
    }
}


function Invoke-CrossPlatformFileSelector {

    [OutputType([string])]
    param (
        [string] $Title = "Select a File"
    )

    # 1. Windows Architecture
    if ($IsWindows) {
        Add-Type -AssemblyName System.Windows.Forms
        $Dialog = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Title            = $Title
            InitialDirectory = (Get-Location).Path
            Multiselect      = $false
        }
        if ($Dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $Dialog.FileName
        }
        return $null
    }

    # 2. macOS Architecture
    elseif ($IsMacOS) {
        $Result = osascript -e "POSIX path of (choose file with prompt `"$Title`")" 2> $null
        if ($Result) {
            return $Result.Trim()
        }
    }

    # 3. Linux Architecture (Zenity / Yad Fallback)
    elseif ($IsLinux) {
        if (Get-Command zenity -ErrorAction SilentlyContinue) {
            return (zenity --file-selection --title=$Title 2> $null)
        }
        elseif (Get-Command yad -ErrorAction SilentlyContinue) {
            return (yad --file-selection --title=$Title 2> $null)
        }
    }

    # 4. Ultimate TUI Fallback (Headless environments / SSH / Missing GUI tools)
    if (Get-Module -ListAvailable -Name Microsoft.PowerShell.ConsoleGuiTools) {
        $Selection = Get-ChildItem -Path "." -File |
        Out-ConsoleGridView -Title "$Title (Console Mode)" -OutputMode Single
        if ($Selection) {
            return $Selection.FullName
        }
    }

    Write-Warning "No compatible file selector (GUI or TUI) could be launched."
    return $null
}
