[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string] $FechaInicio,

    [Parameter(Mandatory)]
    [string] $FechaFin,

    [switch] $ReturnData
)

### CUADROS GENERADOS/PAGADOS SEMANAL


# Desde el lunes de la semana pasada hasta este lunes

. "$PSScriptRoot/../VolaUtil.ps1"

$sql = @"
SELECT
    c.uuid AS "ID Club",
    c.name AS "Nombre Club",
    c4.name AS "País",
    c5.name AS "Ciudad",
    c2.name AS "Competición",
    c2.start_date AS "Inicio competición",
    bg.total_players * 1 AS "Inscritos",
    c2.visible AS "Visible",
    c2.id AS "ID Competición",
    c.vat AS "VAT",

    CASE
    WHEN c3.hasDecimal THEN TRUNCATE(t.amount / 100, 2)
    ELSE TRUNCATE(t.amount, 2)
END AS "Importe",

CASE
    WHEN c3.hasDecimal THEN TRUNCATE(t.tax / 100, 2)
    ELSE TRUNCATE(t.tax, 2)
END AS "IVA",

    c3.code_iso AS "Moneda",
    CASE
        WHEN bg.id IS NOT NULL THEN 'Stripe'
        ELSE ''
    END AS "Pasarela",
    DATE_ADD(t.created_at, INTERVAL 1 HOUR) AS "Fecha pago",
    "" AS `Bono`
FROM
    bracket_generations bg
LEFT JOIN clubs c ON c.id = bg.club_id
LEFT JOIN cities c5 ON c.city_id = c5.id
LEFT JOIN competitions c2 ON c2.id = bg.competition_id
LEFT JOIN club_bracket_rates cbr ON cbr.id = bg.club_rate_id
LEFT JOIN transactions t ON t.id = bg.transaction_id
LEFT JOIN currencies c3 ON c3.id = cbr.currency_id
LEFT JOIN orders o ON o.`order` = t.`order`
LEFT JOIN countries c4 ON c4.id = c.billing_country_id
WHERE bg.created_at > '$FechaInicio 00:00:00'
AND bg.created_at < '$FechaFin 23:59:59'
ORDER BY bg.id DESC
"@

Export-VolaDataAsCsv -FechaInicio $FechaInicio `
    -FechaFin $FechaFin `
    -Paquete 'Lunes' `
    -NombreDeFicheroBase 'cuadros-generados-semanal' `
    -Data (Get-VolaDbData -Query $sql) `
    -ReturnData:$ReturnData
