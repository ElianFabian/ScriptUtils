[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string] $FechaInicio,

    [Parameter(Mandatory)]
    [string] $FechaFin,

    [switch] $ReturnData
)


### BAJA DE CLUBES

# Hay 2 casos:
# - Semanal: desde el lunes anterior al lunes actual
# - Mensual: todo el mes anterior (se hace en el primer lunes de cada mes)


. "$PSScriptRoot/../VolaUtil.ps1"

$sql = @"
WITH UltimoInicio AS (
    SELECT
        suh.club_id,
        MAX(suh.start_at) AS UltimoInicio
    FROM
        subscription_user_history suh
    GROUP BY
        suh.club_id
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
    suh.start_at AS 'Inicio última mensualidad',
    suh.end_at AS 'Fin suscripción',
    pr.PrimerRegistro AS 'Primera fecha de alta en Vola',
    CASE
        WHEN suh.plan_id = 92372 THEN 'Basic'
        WHEN suh.plan_id = 92373 THEN 'Medium'
        WHEN suh.plan_id = 92374 THEN 'Pro'
        WHEN suh.plan_id = 102735 THEN 'Lite'
    END AS 'Tipo de suscripción',
    COALESCE(i.TotalInscripciones, 0) AS 'Total Inscripciones',
    COALESCE(r.TotalReservas, 0) AS 'Total Reservas',
"" AS `Bono`
FROM
    subscription_user_history suh
JOIN
    clubs c ON c.id = suh.club_id
LEFT JOIN
    countries c3 ON c3.id = c.country_id
LEFT JOIN
    cities c4 ON c4.id = c.city_id
JOIN
    UltimoInicio ui ON ui.club_id = suh.club_id AND ui.UltimoInicio = suh.start_at
LEFT JOIN
    PrimerRegistro pr ON pr.club_id = c.id
LEFT JOIN
    InscripcionesUltimos30Dias i ON i.club_id = c.id
LEFT JOIN
    ReservasUltimos30Dias r ON r.club_id = c.id
WHERE
  c.id NOT IN (1540,2895,3202,3332,3604,3605)
    AND suh.end_at >= '$FechaInicio 00:00:00'
    AND suh.end_at <= '$FechaFin 23:59:59';
"@

Export-VolaDataAsCsv -FechaInicio $FechaInicio `
    -FechaFin $FechaFin `
    -Paquete 'Lunes' `
    -NombreDeFicheroBase 'baja-de-clubes' `
    -Data (Get-VolaDbData -Query $sql) `
    -ReturnData:$ReturnData
