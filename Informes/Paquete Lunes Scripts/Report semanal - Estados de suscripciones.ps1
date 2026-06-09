[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string] $FechaInicio,

    [Parameter(Mandatory)]
    [string] $FechaFin,

    [string] $SubscriptionsFile,

    [switch] $ReturnData
)

# LUNES - ESTADOS DE SUSCRIPCIONES


. "$PSScriptRoot/../VolaUtil.ps1"

$sql = @"
WITH LatestSubscription AS (
    SELECT
        suh.club_id,
        suh.subscription_id,
        suh.start_at,
        suh.end_at,
        suh.plan_id,
        ROW_NUMBER() OVER (PARTITION BY suh.club_id ORDER BY suh.subscription_id DESC) AS rn
    FROM subscription_user_history suh
    WHERE suh.start_at <= NOW()
      AND suh.end_at >= NOW()
),
PrimerRegistro AS (
    SELECT
        suh.club_id,
        MIN(suh.start_at) AS PrimerRegistro
    FROM
        subscription_user_history suh
    GROUP BY
        suh.club_id
),
InscripcionesUltimos30Dias AS (
    SELECT
        c2.id AS club_id,
        COUNT(DISTINCT ct.id) * 2 AS TotalInscripciones
    FROM
        competitions c
    LEFT JOIN
        clubs c2 ON c2.id = c.club_id
    LEFT JOIN
        competition_teams ct ON ct.competition_id = c.id
    WHERE
        c.start_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        AND c.start_date <= NOW()
        AND c.deleted_at IS NULL
        AND ct.id IS NOT NULL
        AND c.type = 1
        AND c.visible = 1
    GROUP BY
        c2.id
),
ReservasUltimos30Dias AS (
    SELECT
        c.id AS club_id,
        COUNT(DISTINCT ccb.id) AS TotalReservas
    FROM
        club_court_bookings ccb
    INNER JOIN
        club_courts cc ON ccb.club_court_id = cc.id
    INNER JOIN
        clubs c ON cc.club_id = c.id
    WHERE
        ccb.datetime_from >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        AND ccb.datetime_from <= NOW()
        AND ccb.status = 3
        AND ccb.booking_type_id = 1
        AND ccb.deleted_at IS NULL
    GROUP BY
        c.id
)
SELECT
    c.uuid AS ID,
    c.name AS Nombre,
    DATE_FORMAT(DATE_ADD(c.created_at, INTERVAL 2 HOUR), '%d/%m/%Y %H:%i') AS 'Fecha de creación de cuenta',
    c.vat AS VAT,
    c.phone AS Teléfono,
    c3.name AS País,
    c4.name AS Ciudad,
    ls.subscription_id AS 'ID suscripción',
    ls.start_at AS 'Inicio mensualidad activa',
    ls.end_at AS 'Renovación suscripción',
pr.PrimerRegistro AS 'Primera fecha de alta en Vola',
    CASE
        WHEN ls.plan_id = 92372 THEN 'Basic'
        WHEN ls.plan_id = 92373 THEN 'Medium'
        WHEN ls.plan_id = 92374 THEN 'Pro'
        WHEN ls.plan_id = 102735 THEN 'Lite'
    END AS 'Tipo suscripción',
    "" AS 'Estado suscripción',
    COALESCE(i.TotalInscripciones, 0) AS 'Total Inscripciones',
    COALESCE(r.TotalReservas, 0) AS 'Total Reservas',
"" AS 'Bono'
FROM LatestSubscription ls
JOIN clubs c ON c.id = ls.club_id
LEFT JOIN countries c3 ON c3.id = c.country_id
LEFT JOIN cities c4 ON c4.id = c.city_id
LEFT JOIN
    PrimerRegistro pr ON pr.club_id = c.id
LEFT JOIN InscripcionesUltimos30Dias 	i ON i.club_id = c.id
LEFT JOIN ReservasUltimos30Dias r ON r.club_id = c.id
WHERE c.id != 1540
AND c.id != 2895
AND c.id != 3202
AND c.id != 3203
AND c.id != 3332
  AND ls.rn = 1  -- Solo el último subscription_id por club
ORDER BY ls.subscription_id DESC;
"@


if ($SubscriptionsFile) {
    $subscriptionsReportFromPayProFile = $SubscriptionsFile
}
else {
    do {
        Write-Host "Ahora tienes que seleccionar el CSV del informe de Subscriptions de PayPro (rango amplio y sin filtros)" -ForegroundColor Yellow
        Read-Host "Presionar enter para continuar..." > $null
        $subscriptionsReportFromPayProFile = Invoke-CrossPlatformFileSelector -Title 'Selecciona el CSV del informe de Subscriptions'
    }
    while ($null -eq $subscriptionsReportFromPayProFile)
}

$subscriptionsData = Import-Csv -Path $subscriptionsReportFromPayProFile -Delimiter ';'

$subscriptionStatusBySubscriptionId = @{}
foreach ($row in $subscriptionsData) {
    $subscriptionStatusBySubscriptionId[$row.'Subscription ID'] = $row.'Subscription Status'
}

$data = Get-VolaDbData -Query $Sql

# Llenamos el campo de estado de sucripción usando el informe de PayPro
foreach ($row in $data) {
    $row.'Estado suscripción' = $subscriptionStatusBySubscriptionId[$row.'ID suscripción']
}

Export-VolaDataAsCsv -FechaInicio $FechaInicio `
    -FechaFin $FechaFin `
    -Paquete 'Lunes' `
    -NombreDeFicheroBase 'estados-de-suscripciones' `
    -Data $data `
    -ReturnData:$ReturnData
