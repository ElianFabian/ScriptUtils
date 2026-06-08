[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string] $FechaInicio,

    [Parameter(Mandatory)]
    [string] $FechaFin
)



### ALTA DE CLUBES

# Hay 2 casos:
# - Semanal: desde el lunes anterior al lunes actual
# - Mensual: todo el mes anterior (se hace en el primer lunes de cada mes)


. "$PSScriptRoot/../VolaUtil.ps1"

$sql = @"
WITH PrimerInicio AS (
    SELECT
        suh.club_id,
        MIN(suh.start_at) AS PrimerInicio
    FROM
        subscription_user_history suh
    GROUP BY
        suh.club_id
)
SELECT
    c.uuid AS ID,
    c.name AS Nombre,
    DATE_FORMAT(DATE_ADD(c.created_at, INTERVAL 2 HOUR), '%d/%m/%Y %H:%i') AS 'Fecha de creación de cuenta',
    c.vat AS VAT,
    c.phone AS Teléfono,
    c3.name AS País,
    c4.name AS Ciudad,
    suh.start_at AS 'Fecha de alta',
    suh.end_at AS 'Renovación suscripción',
    CASE
        WHEN suh.plan_id = 92372 THEN 'Basic'
        WHEN suh.plan_id = 92373 THEN 'Medium'
        WHEN suh.plan_id = 92374 THEN 'Pro'
        WHEN suh.plan_id = 102735 THEN 'Lite'
    END AS 'Tipo de suscripción',
"" AS 'Bono'
FROM
    subscription_user_history suh
JOIN
    clubs c ON c.id = suh.club_id
LEFT JOIN
    countries c3 ON c3.id = c.country_id
LEFT JOIN
    cities c4 ON c4.id = c.city_id
JOIN
    PrimerInicio pi ON pi.club_id = suh.club_id AND pi.PrimerInicio = suh.start_at
WHERE
 c.id NOT IN (1540,2895,3202,3332,3604,3605)
    AND suh.start_at >= '$FechaInicio 00:00:00'
    AND suh.start_at <= '$FechaFin 23:59:59';
"@

$data = (Get-VolaDbData -Query $sql)

Export-VolaDataAsCsv -FechaInicio $FechaInicio `
    -FechaFin $FechaFin `
    -Paquete 'Lunes' `
    -NombreDeFicheroBase 'alta-de-clubes' `
    -Data $data
