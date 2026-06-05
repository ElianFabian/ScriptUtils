# Función para validar si una cadena es una fecha válida en formato yyyy-MM-dd y si es Lunes
function Test-EsLunesValido {
    param (
        [string] $fechaStr
    )

    if ([DateTime]::TryParseExact($fechaStr, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$null)) {
        $date = [DateTime]::ParseExact($fechaStr, "yyyy-MM-dd", $null)
        return $date.DayOfWeek -eq "Monday"
    }
    return $false
}

# Función para calcular la fecha fin (Domingo de la semana que está a 2 semanas del Lunes de inicio)
# Si el inicio es Lunes, sumamos 14 días para llegar al lunes de dentro de 2 semanas, y 6 días más para llegar al domingo (+20 días en total).
function Get-FechaFin {
    param (
        [string] $fechaInicioStr
    )

    $dateInicio = [DateTime]::ParseExact($fechaInicioStr, "yyyy-MM-dd", $null)
    return $dateInicio.AddDays(7).ToString("yyyy-MM-dd")
}

$hoy = Get-Date
$diaSemana = $hoy.DayOfWeek
$fechaInicioStr = ""
$fechaFinStr = ""

# Comprobar si hoy es viernes
$esViernes = ($diaSemana -eq "Friday")

if ($esViernes) {
    # Si hoy es viernes, el lunes por defecto es el próximo lunes (hoy + 10 días)
    $defectoInicio = $hoy.AddDays(10).ToString("yyyy-MM-dd")

    $inputInicio = Read-Host "Introduce la fecha de inicio (yyyy-MM-dd) [Por defecto (Lunes de dentro de 2 semanas): $defectoInicio]"

    if ([string]::IsNullOrWhiteSpace($inputInicio)) {
        $fechaInicioStr = $defectoInicio
    }
    else {
        $fechaInicioStr = $inputInicio
        # Validar que la fecha manual sea un lunes
        while (-not (Test-EsLunesValido $fechaInicioStr)) {
            Write-Host "Error: La fecha introducida no existe o no es un LUNES." -ForegroundColor Red
            $fechaInicioStr = Read-Host "Introduce una fecha de inicio que sea LUNES (yyyy-MM-dd)"
        }
    }
}
else {
    # Si no es viernes, obligar a introducir un lunes
    Write-Host "Hoy no es viernes. Debes introducir la fecha de inicio manualmente." -ForegroundColor Yellow
    while (-not (Test-EsLunesValido $fechaInicioStr)) {
        $fechaInicioStr = Read-Host "Introduce la fecha de inicio (Debe ser LUNES) (yyyy-MM-dd)"
        if (-not (Test-EsLunesValido $fechaInicioStr)) {
            Write-Host "Error: La fecha debe tener el formato yyyy-MM-dd y ser un LUNES." -ForegroundColor Red
        }
    }
}

# La fecha fin SIEMPRE se calcula automáticamente en base a la de inicio
$fechaFinStr = Get-FechaFin $fechaInicioStr

Write-Host "`nEjecutando torneo con:" -ForegroundColor Cyan
Write-Host "Fecha Inicio (Lunes): $fechaInicioStr"
Write-Host "Fecha Fin (Domingo):  $fechaFinStr`n"

# Llamada al script externo
. "$PSScriptRoot/Paquete Viernes Scripts/Torneos que se van a disputar.ps1" -FechaInicio $fechaInicioStr -FechaFin $fechaFinStr -Verbose -ErrorAction Stop

Read-Host "¡Se han generado los CSVs con éxito!"
