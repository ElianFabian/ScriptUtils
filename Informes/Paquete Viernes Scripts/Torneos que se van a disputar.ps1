[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string] $FechaInicio,

    [Parameter(Mandatory)]
    [string] $FechaFin
)


### TORNEOS QUE SE VAN A DISPUTAR DENTRO DE 2 SEMANAS - PAQUETE DEL VIERNES

# Si estamos en a viernes 10, tenemos que coger la semana del 20 al 26
# Tiene que ser tanto GLOBAL como para LATAM

. "$PSScriptRoot/../VolaUtil.ps1"

$sql = @"
SELECT
    c2.uuid AS "ID Club",
    c2.name AS "Nombre Club",
    CASE WHEN c2.private_organizer = 1 THEN 'Organizador' ELSE 'Club' END AS "Tipo Club",
    c3.name AS "País",
    c4.name AS "Ciudad",
    c.name AS "Competición",
    c.start_date AS "Inicio competición",
    c.id AS "ID Competición"
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
WHERE
    c.created_at >= "2023-10-01 00:00:00"
    AND ct.id IS NOT NULL
AND c2.id NOT IN (1540,2895,3202,3332,3604,3605)
    AND c.deleted_at IS NULL
    AND c.type = 1
    AND c.start_date >= '$FechaInicio 00:00:00'
    AND c.start_date <= '$FechaFin 23:59:59'
GROUP BY
    c.id, c2.uuid, c2.name, c3.name, c4.name, c.name, c.start_date
ORDER BY c.start_date ASC;
"@

Export-VolaDataAsCsv -FechaInicio $FechaInicio `
    -FechaFin $FechaFin `
    -Paquete 'Viernes' `
    -NombreDeFicheroBase 'torneos-que-se-van-a-disputar' `
    -Data (Get-VolaDbData -Query $sql)