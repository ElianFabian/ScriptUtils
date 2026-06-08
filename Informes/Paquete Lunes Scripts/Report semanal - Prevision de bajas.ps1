
# PREVISIÓN DE BAJAS

# Abajo indicas los ids de suscripción obtenidos en PayPro

# Al poner esto en el EXCEl hay una columna que falta, la de "Renovación suscripción",
# esa se saca del EXCEL de PayPro en la columna "Scheduled Payment At (UTC)"


. "$PSScriptRoot/../VolaUtil.ps1"


do {
    Write-Host "Ahora tienes que seleccionar el CSV de Subscriptions de PayPro (lunes actual hasta lunes de dentro de 2 semanas)" -ForegroundColor Yellow
    Read-Host "Presiona enter para continuar..."
    $subscriptionsFile = Invoke-CrossPlatformFileSelector -Title 'Selecciona el CSV del informe de Subscriptions'
    if ($null -eq $subscriptionsFile) {
        Write-Error "No se ha seleccionado el CSV de Subscriptions de PayPro."
    }
}
while ($null -eq $subscriptionsFile)

$subscriptionsData = Import-Csv -LiteralPath $subscriptionsFile -Delimiter ';'

[long[]] $subscriptionIds = $subscriptionsData | ForEach-Object { $_.'Subscription ID' }
$subscriptionIdsStr = "($($subscriptionIds -join ','))"

$sql = @"
WITH InscripcionesUltimos30Dias AS (
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
SELECT DISTINCT
    suh.subscription_id,
    c.uuid AS 'ID Club',
    c.name AS 'Nombre Club',
    ctr.name AS 'País',
    cit.name AS 'Ciudad',
    CASE
        WHEN suh.plan_id = 92372 THEN 'Vola Plan Basic'
        WHEN suh.plan_id = 92373 THEN 'Vola Plan Medium'
        WHEN suh.plan_id = 92374 THEN 'Vola Plan Pro'
        WHEN suh.plan_id = 102735 THEN 'Lite'
    END AS 'Tipo de suscripción',
    COALESCE(i.TotalInscripciones, 0) AS 'Inscripciones Ultimos 30 Dias',
    COALESCE(r.TotalReservas, 0) AS 'Reservas Ultimos 30 Dias',
"" AS `Bono`
FROM
    subscription_user_history suh
JOIN
    clubs c ON c.id = suh.club_id
JOIN cities cit on c.city_id = cit.id
JOIN countries ctr on c.country_id = ctr.id
LEFT JOIN
    InscripcionesUltimos30Dias i ON i.club_id = c.id
LEFT JOIN
    ReservasUltimos30Dias r ON r.club_id = c.id
WHERE
    suh.subscription_id IN $subscriptionIdsStr
order by suh.subscription_id desc;
"@

$dbData = (Get-VolaDbData -Query $sql)

Write-Host $dbData -ForegroundColor Green

$outputData = $dbData | Select-Object @(
    @{ Name = 'ID Club'; Expression = { $_.'ID Club' } }
    @{ Name = 'Nombre club'; Expression = { $_.'Nombre club' } }
    @{ Name = 'País'; Expression = { $_.'País' } }
    @{ Name = 'Ciudad'; Expression = { $_.'Ciudad' } }
    @{ Name = 'Plan'; Expression = { $_.'Tipo de suscripción' } }
    @{ Name = 'Renovación suscripción'; Expression = { <# Se añade luego #> } }
    @{ Name = 'Inscripciones Últimos 30 Dias'; Expression = { $_.'Inscripciones Ultimos 30 Dias' } }
    @{ Name = 'Reservas Últimos 30 Dias'; Expression = { $_.'Reservas Ultimos 30 Dias' } }
    @{ Name = 'Bono'; Expression = { <# Vacío #> } }
)

$renovacionSuscripcion = @()
foreach ($row in $subscriptionsData) {
    $renovacionSuscripcion += $row.'Scheduled Payment At (UTC)'
}

for ($i = 0; $i -lt $outputData.Count; $i++) {
    $outputDataRow = $outputData[$i]
    $renovacionSuscripcionRow = $renovacionSuscripcion[$i]

    $outputDataRow.'Renovación suscripción' = $renovacionSuscripcionRow
}

Export-VolaDataAsCsv -FechaInicio $FechaInicio `
    -FechaFin $FechaFin `
    -Paquete 'Lunes' `
    -NombreDeFicheroBase 'prevision-de-bajas' `
    -Data $outputData
