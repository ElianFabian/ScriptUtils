function Test-EsLunesValido {
    param (
        [string] $fechaStr
    )

    try {
        $date = [DateTime]::ParseExact($fechaStr, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
        return $date.DayOfWeek -eq "Monday"
    }
    catch {
        return $false
    }
}

function Get-FechaDeFinSemanaActual {
    param (
        [string] $fechaInicioStr
    )

    $dateInicio = [DateTime]::ParseExact($fechaInicioStr, "yyyy-MM-dd", $null)
    return $dateInicio.AddDays(6).ToString("yyyy-MM-dd")
}

function Get-FechaSemanaAnterior {
    param (
        [string] $fechaInicioStr
    )

    $dateInicio = [DateTime]::ParseExact($fechaInicioStr, "yyyy-MM-dd", $null)
    return $dateInicio.AddDays(-7).ToString("yyyy-MM-dd")
}

function Es-PrimerLunesDelMes {
    param (
        [string] $fechaInicioStr
    )

    $dateInicio = [DateTime]::ParseExact($fechaInicioStr, "yyyy-MM-dd", $null)
    return $dateInicio.DayOfWeek -eq 'Monday' -and $dateInicio.Day -le 7
}

function Get-FirstAndLastDateOfPreviousMonth {
    param (
        [string] $fechaInicioStr
    )

    $dateInicio = [DateTime]::ParseExact($fechaInicioStr, "yyyy-MM-dd", $null)
    $firstOfCurrentMonth = Get-Date -Year $dateInicio.Year -Month $dateInicio.Month -Day 1
    $lastOfPreviousMonth = $firstOfCurrentMonth.AddDays(-1)
    $firstOfPreviousMonth = Get-Date -Year $lastOfPreviousMonth.Year -Month $lastOfPreviousMonth.Month -Day 1

    return @{ Start = $firstOfPreviousMonth.ToString('yyyy-MM-dd'); End = $lastOfPreviousMonth.ToString('yyyy-MM-dd') }
}

function Get-PaqueteLunesCsvFilePath {
    param (
        [string] $NombreDeFicheroBase,

        [string] $FechaInicio,

        [string] $FechaFin,

        [switch] $Latam
    )

    if (-not $NombreDeFicheroBase) {
        throw "Get-PaqueteLunesCsvFilePath requiere NombreDeFicheroBase no vacío."
    }

    $nombreBaseLimpio = $NombreDeFicheroBase.Trim()
    $fechaActual = Get-Date -Format 'yyyy-MM-dd'
    $rangoDeFecha = ''
    if ($FechaInicio -and $FechaFin) {
        $rangoDeFecha = "__$FechaInicio-$FechaFin"
    }

    $latamSuffix = if ($Latam) { '-LATAM' } else { '' }
    $fileName = "$nombreBaseLimpio__$fechaActual$rangoDeFecha$latamSuffix.csv"
    $csvFolder = Join-Path -Path $PSScriptRoot -ChildPath 'Paquete Lunes CSV'
    return Join-Path -Path $csvFolder -ChildPath $fileName
}

function Import-VolaReportCsv {
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path $Path)) {
        throw "No existe el informe CSV esperado: $Path"
    }

    return Import-Csv -Path $Path -Delimiter ';'
}

function Export-PaqueteLunesWorkbookFromCsv {
    param (
        [Parameter(Mandatory = $true)]
        [string] $WorkbookPath,

        [Parameter(Mandatory = $true)]
        [hashtable] $SheetMap
    )

    $sheetData = @{}
    foreach ($sheetName in $SheetMap.Keys) {
        $config = $SheetMap[$sheetName]
        if (-not $config -or -not $config.ContainsKey('NombreDeFicheroBase') -or -not $config.NombreDeFicheroBase) {
            throw "La configuración de la hoja '$sheetName' no contiene NombreDeFicheroBase válido."
        }

        $csvPath = Get-PaqueteLunesCsvFilePath -NombreDeFicheroBase $config.NombreDeFicheroBase -FechaInicio $config.FechaInicio -FechaFin $config.FechaFin
        try {
            $sheetData[$sheetName] = Import-VolaReportCsv -Path $csvPath
        }
        catch {
            throw "Error al importar la hoja '$sheetName' desde CSV '$csvPath': $($_.Exception.Message)"
        }
    }

    Export-VolaWorkbook -Path $WorkbookPath -SheetData $sheetData -AutoSize -BoldTopRow
}

function Export-PaqueteLunesLatamWorkbookFromCsv {
    param (
        [Parameter(Mandatory = $true)]
        [string] $WorkbookPath,

        [Parameter(Mandatory = $true)]
        [hashtable] $SheetMap
    )

    $sheetData = @{}
    foreach ($sheetName in $SheetMap.Keys) {
        $config = $SheetMap[$sheetName]
        if (-not $config -or -not $config.ContainsKey('NombreDeFicheroBase') -or -not $config.NombreDeFicheroBase) {
            throw "La configuración de la hoja '$sheetName' no contiene NombreDeFicheroBase válido."
        }

        $csvPath = Get-PaqueteLunesCsvFilePath -NombreDeFicheroBase $config.NombreDeFicheroBase -FechaInicio $config.FechaInicio -FechaFin $config.FechaFin -Latam
        try {
            $sheetData[$sheetName] = Import-VolaReportCsv -Path $csvPath
        }
        catch {
            throw "Error al importar la hoja '$sheetName' desde CSV '$csvPath': $($_.Exception.Message)"
        }
    }

    Export-VolaWorkbookLatam -Path $WorkbookPath -SheetData $sheetData -AutoSize -BoldTopRow
}

function Export-PaqueteLunesWorkbookFromData {
    param (
        [Parameter(Mandatory = $true)]
        [string] $WorkbookPath,

        [Parameter(Mandatory = $true)]
        [hashtable] $SheetData
    )

    Export-VolaWorkbook -Path $WorkbookPath -SheetData $SheetData -AutoSize -BoldTopRow
}

function Export-PaqueteLunesLatamWorkbookFromData {
    param (
        [Parameter(Mandatory = $true)]
        [string] $WorkbookPath,

        [Parameter(Mandatory = $true)]
        [hashtable] $SheetData
    )

    Export-VolaWorkbookLatam -Path $WorkbookPath -SheetData $SheetData -AutoSize -BoldTopRow
}

$hoy = Get-Date
$diaSemana = $hoy.DayOfWeek
$fechaInicioStr = ""

if ($diaSemana -eq "Monday") {
    $defectoInicio = $hoy.ToString("yyyy-MM-dd")
    $inputInicio = Read-Host "Introduce la fecha de inicio (yyyy-MM-dd) [Por defecto (Lunes actual): $defectoInicio]"

    if ([string]::IsNullOrWhiteSpace($inputInicio)) {
        $fechaInicioStr = $defectoInicio
    }
    else {
        $fechaInicioStr = $inputInicio
        while (-not (Test-EsLunesValido $fechaInicioStr)) {
            Write-Host "Error: La fecha introducida no existe o no es un LUNES." -ForegroundColor Red
            $fechaInicioStr = Read-Host "Introduce una fecha de inicio que sea LUNES (yyyy-MM-dd)"
        }
    }
}
else {
    Write-Host "Hoy no es lunes. Debes introducir la fecha de inicio manualmente." -ForegroundColor Yellow
    while (-not (Test-EsLunesValido $fechaInicioStr)) {
        $fechaInicioStr = Read-Host "Introduce la fecha de inicio (Debe ser LUNES) (yyyy-MM-dd)"
        if (-not (Test-EsLunesValido $fechaInicioStr)) {
            Write-Host "Error: La fecha debe tener el formato yyyy-MM-dd y ser un LUNES." -ForegroundColor Red
        }
    }
}

$fechaFinSemanaActualStr = Get-FechaDeFinSemanaActual $fechaInicioStr
$fechaInicioSemanaAnteriorStr = Get-FechaSemanaAnterior $fechaInicioStr
$fechaFinSemanaAnteriorStr = $fechaInicioStr

Write-Host "`nConfiguración de fechas:" -ForegroundColor Cyan
Write-Host "  Semana actual:    $fechaInicioStr -> $fechaFinSemanaActualStr"
Write-Host "  Semana anterior:  $fechaInicioSemanaAnteriorStr -> $fechaFinSemanaAnteriorStr`n"

$esPrimerLunesDelMes = Es-PrimerLunesDelMes $fechaInicioStr
if ($esPrimerLunesDelMes) {
    $rangoMesAnterior = Get-FirstAndLastDateOfPreviousMonth $fechaInicioStr
    $fechaInicioMesAnteriorStr = $rangoMesAnterior.Start
    $fechaFinMesAnteriorStr = $rangoMesAnterior.End
    Write-Host "Este es el primer lunes del mes. También se generarán los informes mensuales para el mes anterior: $fechaInicioMesAnteriorStr -> $fechaFinMesAnteriorStr" -ForegroundColor Cyan
}
else {
    Write-Host "No es el primer lunes del mes. Solo se generarán los informes semanales." -ForegroundColor Yellow
}

& "$PSScriptRoot/VolaUtil.ps1"

Write-Host "=== Suscripciones activas ===" -ForegroundColor Cyan
$tecnicaData = (. "$PSScriptRoot/Paquete Lunes Scripts/Suscripciones activas - Tenica.ps1")

do {
    Write-Host "Ahora tienes que seleccionar el CSV de Subscriptions de PayPro (lunes actual hasta lunes de dentro de 2 semanas)" -ForegroundColor Yellow
    Read-Host "Presiona enter para continuar..."
    $subscriptionsFilePrevision = Invoke-CrossPlatformFileSelector -Title 'Selecciona el CSV del informe de Subscriptions para Previsión de bajas'
    if (-not $subscriptionsFilePrevision) {
        Write-Error "No se ha seleccionado el CSV de Subscriptions de PayPro."
    }
}
while ($null -eq $subscriptionsFilePrevision)

$previsionDeBajasData = & "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Prevision de bajas.ps1" -SubscriptionsFile $subscriptionsFilePrevision -ReturnData

do {
    Write-Host "Ahora tienes que seleccionar el CSV de Subscriptions de PayPro (rango amplio y sin filtros)" -ForegroundColor Yellow
    Read-Host "Presiona enter para continuar..."
    $subscriptionsFile = Invoke-CrossPlatformFileSelector -Title 'Selecciona el CSV del informe de Subscriptions'
    if (-not $subscriptionsFile) {
        Write-Error "No se ha seleccionado el CSV de Subscriptions de PayPro."
    }
}
while ($null -eq $subscriptionsFile)

$DbPayProData = & "$PSScriptRoot/Paquete Lunes Scripts/Suscripciones activas - DB_PayPro.ps1" -SubscriptionsFile $subscriptionsFile -TecnicaData $tecnicaData
& "$PSScriptRoot/Paquete Lunes Scripts/Suscripciones activas - DB_Vola.ps1" -DbPayProData $DbPayProData


Write-Host "`n=== Informes semanales de lunes ===" -ForegroundColor Cyan
$torneosPendientesData = & "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Torneos pendientes de disputar.ps1" -FechaInicio $fechaInicioStr -FechaFin $fechaFinSemanaActualStr -ReturnData
$torneosDisputadosData = & "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Torneos disputados.ps1" -FechaInicio $fechaInicioSemanaAnteriorStr -FechaFin $fechaFinSemanaAnteriorStr -ReturnData
$cuadrosGeneradosData = & "$PSScriptRoot/Paquete Lunes Scripts/Cuadros pagados semanal.ps1" -FechaInicio $fechaInicioSemanaAnteriorStr -FechaFin $fechaFinSemanaAnteriorStr -ReturnData
$estadosSuscripcionesData = & "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Estados de suscripciones.ps1" -FechaInicio $fechaInicioSemanaAnteriorStr -FechaFin $fechaFinSemanaAnteriorStr -SubscriptionsFile $subscriptionsFile -ReturnData
$clubesFreemiumData = & "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Clubes con fremium activado.ps1" -ReturnData
$bajaDeClubesData = & "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Baja de clubes.ps1" -FechaInicio $fechaInicioSemanaAnteriorStr -FechaFin $fechaFinSemanaAnteriorStr -ReturnData
$altaDeClubesData = & "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Alta de clubes.ps1" -FechaInicio $fechaInicioSemanaAnteriorStr -FechaFin $fechaFinSemanaAnteriorStr -ReturnData

$reportSemanalSheetData = [ordered]@{
    'altas clubes semanal' = $altaDeClubesData
    'bajas clubes semanal' = $bajaDeClubesData
    'previsón de bajas' = $previsionDeBajasData
    'torneos disputados' = $torneosDisputadosData
    'torneos pendientes' = $torneosPendientesData
    'clubes con freemium' = $clubesFreemiumData
    'estado de suscripción' = $estadosSuscripcionesData
}

$fileDatePrefix = (Get-Date $fechaInicioStr -Format 'ddMMyy')

$reportSemanalWorkbookPath = "$PSScriptRoot/Paquete Lunes Excel/${fileDatePrefix}Report semanal GLOBAL.xlsx"
$reportSemanalWorkbookLatamPath = "$PSScriptRoot/Paquete Lunes Excel/${fileDatePrefix}Report semanal LATAM.xlsx"
Export-PaqueteLunesWorkbookFromData -WorkbookPath $reportSemanalWorkbookPath -SheetData $reportSemanalSheetData
Export-PaqueteLunesLatamWorkbookFromData -WorkbookPath $reportSemanalWorkbookLatamPath -SheetData $reportSemanalSheetData
Write-Host "Workbook generado: $reportSemanalWorkbookPath" -ForegroundColor Green
Write-Host "Workbook LATAM generado: $reportSemanalWorkbookLatamPath" -ForegroundColor Green

$cuadrosWorkbookPath = "$PSScriptRoot/Paquete Lunes Excel/${fileDatePrefix}Cuadros pagados semanal.xlsx"
$cuadrosSheetData = @{
    'Cuadros generados semanal' = $cuadrosGeneradosData
}
Export-PaqueteLunesWorkbookFromData -WorkbookPath $cuadrosWorkbookPath -SheetData $cuadrosSheetData
Write-Host "Workbook generado: $cuadrosWorkbookPath" -ForegroundColor Green

if ($esPrimerLunesDelMes) {
    Write-Host "`n=== Informes mensuales de lunes ===" -ForegroundColor Cyan
    $torneosDisputadosMensualData = & "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Torneos disputados.ps1" -FechaInicio $fechaInicioMesAnteriorStr -FechaFin $fechaFinMesAnteriorStr -ReturnData
    $bajaDeClubesMensualData = & "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Baja de clubes.ps1" -FechaInicio $fechaInicioMesAnteriorStr -FechaFin $fechaFinMesAnteriorStr -ReturnData
    $altaDeClubesMensualData = & "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Alta de clubes.ps1" -FechaInicio $fechaInicioMesAnteriorStr -FechaFin $fechaFinMesAnteriorStr -ReturnData
    $clubesFreemiumMensualData = & "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Clubes con fremium activado.ps1" -ReturnData

    $monthlySemanalSheetData = [ordered]@{
        'Alta de clubes mensual' = $altaDeClubesMensualData
        'Baja de clubes mensual' = $bajaDeClubesMensualData
        'Torneos disputados' = $torneosDisputadosMensualData
        'Clubes con freemium' = $clubesFreemiumMensualData
    }

    $monthlyWorkbookPath = "$PSScriptRoot/Paquete Lunes Excel/Report mensual__$fechaInicioMesAnteriorStr-$fechaFinMesAnteriorStr.xlsx"
    $monthlyWorkbookLatamPath = "$PSScriptRoot/Paquete Lunes Excel/Report mensual__$fechaInicioMesAnteriorStr-$fechaFinMesAnteriorStr-LATAM.xlsx"
    Export-PaqueteLunesWorkbookFromData -WorkbookPath $monthlyWorkbookPath -SheetData $monthlySemanalSheetData
    Export-PaqueteLunesLatamWorkbookFromData -WorkbookPath $monthlyWorkbookLatamPath -SheetData $monthlySemanalSheetData
    Write-Host "Workbook generado: $monthlyWorkbookPath" -ForegroundColor Green
    Write-Host "Workbook LATAM generado: $monthlyWorkbookLatamPath" -ForegroundColor Green
}

Write-Host "`nTodos los informes de lunes se han generado correctamente." -ForegroundColor Green
Read-Host "Presiona Enter para cerrar..."
