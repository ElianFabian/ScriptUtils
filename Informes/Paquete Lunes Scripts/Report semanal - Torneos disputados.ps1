[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string] $FechaInicio,

    [Parameter(Mandatory)]
    [string] $FechaFin,

    [switch] $ReturnData
)


### TORNEOS DISPUTADOS

# Hay 2 casos:
# - Semanal: desde el lunes anterior al lunes actual
# - Mensual: todo el mes anterior (se hace en el primer lunes de cada mes)

. "$PSScriptRoot/../VolaUtil.ps1"

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
SELECT
    c2.uuid AS "ID Club",
    c2.name AS "Nombre Club",
    CASE WHEN c2.private_organizer = 1 THEN 'Organizador' ELSE 'Club' END AS "Tipo Club",
    c3.name AS "País",
    c4.name AS "Ciudad",
    c.name AS "Competición",
    c.start_date AS "Inicio competición",
    COUNT(DISTINCT ct.id) * 2 AS "Inscritos",
    c.visible AS "Visible",
    c.id AS "ID Competición",
    CASE
    WHEN bg.id IS NOT NULL THEN ''
    ELSE TRUNCATE(
        (
            IF(
                cy.hasDecimal = 1,
                COALESCE(cp.price_cash_regular, cp.price_card_regular) / 100,
                COALESCE(cp.price_cash_regular, cp.price_card_regular)
            ) * (COUNT(DISTINCT ct.id) * 2)
        ), 0
    )
END AS "Total importe aprox",
    COALESCE(i.TotalInscripciones, 0) AS "Inscripciones Ultimos 30 Dias",
    COALESCE(r.TotalReservas, 0) AS "Reservas Ultimos 30 Dias",
    CASE
        WHEN bg.id IS NOT NULL THEN 'Sí'
        ELSE 'No'
    END AS "Pagó cuadros",
    c2.vat AS "VAT",
    CASE
    WHEN c3b.hasDecimal THEN TRUNCATE(t.amount / 100, 2)
    ELSE TRUNCATE(t.amount, 2)
END AS "Importe",

CASE
    WHEN c3b.hasDecimal THEN TRUNCATE(t.tax / 100, 2)
    ELSE TRUNCATE(t.tax, 2)
END AS "IVA",

    CASE
        WHEN bg.id IS NOT NULL THEN 'Stripe'
        ELSE ''
    END AS "Pasarela",
    "" AS `Bono`
FROM
    competitions c
LEFT JOIN
    clubs c2 ON c2.id = c.club_id
LEFT JOIN
    countries c3 ON c3.id = c2.country_id
LEFT JOIN
    cities c4 ON c4.id = c2.city_id
LEFT JOIN
    competition_teams ct ON ct.competition_id = c.id
LEFT JOIN
    competition_prices cp ON cp.inscriptions_number = 1 AND cp.competition_id = c.id
LEFT JOIN
    currencies cy ON c.currency_id = cy.id
LEFT JOIN
    InscripcionesUltimos30Dias i ON i.club_id = c2.id
LEFT JOIN
    ReservasUltimos30Dias r ON r.club_id = c2.id
LEFT JOIN
    bracket_generations bg ON bg.competition_id = c.id
LEFT JOIN
    transactions t ON t.id = bg.transaction_id
LEFT JOIN
    club_bracket_rates cbr ON cbr.id = bg.club_rate_id
LEFT JOIN
    currencies c3b ON c3b.id = cbr.currency_id
WHERE
    c.created_at >= '2023-10-01 00:00:00'
    AND ct.id IS NOT NULL
    AND c2.id NOT IN (1540, 2895, 3202, 3203, 3332,3604,3605)
    AND c.deleted_at IS NULL
    AND c.type = 1
    AND c.has_matches = 1
    AND c.start_date >= '$FechaInicio 00:00:00'
    AND c.start_date <= '$FechaFin 23:59:59'
GROUP BY
    c.id, c2.uuid, c2.name, c3.name, c4.name, c.name, c.start_date, c.visible,
    i.TotalInscripciones, r.TotalReservas, bg.id, t.amount, t.tax, c3b.hasDecimal
ORDER BY
    c.start_date;
"@


Export-VolaDataAsCsv -FechaInicio $FechaInicio `
    -FechaFin $FechaFin `
    -Paquete 'Lunes' `
    -NombreDeFicheroBase 'torneos-disputados' `
    -Data (Get-VolaDbData -Query $sql) `
    -ReturnData:$ReturnData
