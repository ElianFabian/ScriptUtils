# Función para validar si una cadena es una fecha válida en formato yyyy-MM-dd y si es Lunes
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

. "$PSScriptRoot/VolaUtil.ps1"

Write-Host "=== Suscripciones activas ===" -ForegroundColor Cyan
$tecnicaData = (. "$PSScriptRoot/Paquete Lunes Scripts/Suscripciones activas - Tenica.ps1")

Write-Host "Ahora tienes que seleccionar el CSV de Subscriptions de PayPro (rango amplio y sin filtros)" -ForegroundColor Yellow
Read-Host "Presiona enter para continuar..."
$subscriptionsFile = Invoke-CrossPlatformFileSelector -Title 'Selecciona el CSV del informe de Subscriptions'
if (-not $subscriptionsFile) {
    throw "No se ha seleccionado el CSV de Subscriptions de PayPro."
}

$DbPayProData = . "$PSScriptRoot/Paquete Lunes Scripts/Suscripciones activas - DB_PayPro.ps1" -SubscriptionsFile $subscriptionsFile -TecnicaData $tecnicaData
$DbVolaData = . "$PSScriptRoot/Paquete Lunes Scripts/Suscripciones activas - DB_Vola.ps1" -DbPayProData $DbPayProData

Write-Host "`n=== Informes semanales de lunes ===" -ForegroundColor Cyan
. "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Torneos pendientes de disputar.ps1" -FechaInicio $fechaInicioStr -FechaFin $fechaFinSemanaActualStr
. "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Torneos disputados.ps1" -FechaInicio $fechaInicioSemanaAnteriorStr -FechaFin $fechaFinSemanaAnteriorStr
. "$PSScriptRoot/Paquete Lunes Scripts/Cuadros pagados semanal.ps1" -FechaInicio $fechaInicioSemanaAnteriorStr -FechaFin $fechaFinSemanaAnteriorStr
. "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Estados de suscripciones.ps1" -FechaInicio $fechaInicioSemanaAnteriorStr -FechaFin $fechaFinSemanaAnteriorStr -SubscriptionsFile $subscriptionsFile
. "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Clubes con fremium activado.ps1"
. "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Baja de clubes.ps1" -FechaInicio $fechaInicioSemanaAnteriorStr -FechaFin $fechaFinSemanaAnteriorStr
. "$PSScriptRoot/Paquete Lunes Scripts/Report semanal - Alta de clubes.ps1" -FechaInicio $fechaInicioSemanaAnteriorStr -FechaFin $fechaFinSemanaAnteriorStr

Write-Host "`nTodos los informes de lunes se han generado correctamente." -ForegroundColor Green
Read-Host "Presiona Enter para cerrar..."
