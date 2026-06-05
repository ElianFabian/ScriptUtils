[CmdletBinding()]
param ()

### CLUBES CON ALGÚN FREEMIUM ACTIVADO (SEMANAL)

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
  c2.phone AS "Teléfono",
  c2.contact_email AS "Correo de Contacto",
  ctr.name AS "País",
  c4.name AS "Ciudad",
  MAX(CASE
      WHEN cp2.product_id = 1 AND cp2.expiration > NOW() AND cp2.deleted_at IS NULL THEN
          CONCAT('Sí (', DATE_FORMAT(DATE_ADD(cp2.created_at, INTERVAL 2 HOUR), '%d/%m/%Y %H:%i'), IFNULL(CONCAT(' - ', u.email), ''), ')')
      ELSE 'No'
  END) AS 'Torneo',
  MAX(CASE
      WHEN cp2.product_id = 2 AND cp2.expiration > NOW() AND cp2.deleted_at IS NULL THEN
          CONCAT('Sí (', DATE_FORMAT(DATE_ADD(cp2.created_at, INTERVAL 2 HOUR), '%d/%m/%Y %H:%i'), IFNULL(CONCAT(' - ', u.email), ''), ')')
      ELSE 'No'
  END) AS 'Torneo express',
  MAX(CASE
      WHEN cp2.product_id = 4 AND cp2.expiration > NOW() AND cp2.deleted_at IS NULL THEN
          CONCAT('Sí (', DATE_FORMAT(DATE_ADD(cp2.created_at, INTERVAL 2 HOUR), '%d/%m/%Y %H:%i'), IFNULL(CONCAT(' - ', u.email), ''), ')')
      ELSE 'No'
  END) AS 'Generar cuadros',
  MAX(CASE
      WHEN cp2.product_id = 5 AND cp2.expiration > NOW() AND cp2.deleted_at IS NULL THEN
          CONCAT('Sí (', DATE_FORMAT(DATE_ADD(cp2.created_at, INTERVAL 2 HOUR), '%d/%m/%Y %H:%i'), IFNULL(CONCAT(' - ', u.email), ''), ')')
      ELSE 'No'
  END) AS 'Publicar calendario ligas',
  MAX(CASE
      WHEN cp2.product_id = 6 AND cp2.expiration > NOW() AND cp2.deleted_at IS NULL THEN
          CONCAT('Sí (', DATE_FORMAT(DATE_ADD(cp2.created_at, INTERVAL 2 HOUR), '%d/%m/%Y %H:%i'), IFNULL(CONCAT(' - ', u.email), ''), ')')
      ELSE 'No'
  END) AS 'Publicar calendario ligas equipos',
  MAX(CASE
      WHEN cp2.product_id = 12 AND cp2.expiration > NOW() AND cp2.deleted_at IS NULL THEN
          CONCAT('Sí (', DATE_FORMAT(DATE_ADD(cp2.created_at, INTERVAL 2 HOUR), '%d/%m/%Y %H:%i'), IFNULL(CONCAT(' - ', u.email), ''), ')')
      ELSE 'No'
  END) AS 'Pistas ilimitadas',
  COALESCE(i.TotalInscripciones, 0) AS "Inscripciones Ultimos 30 Dias",
  COALESCE(r.TotalReservas, 0) AS "Reservas Ultimos 30 Dias",
"" AS `Bono`,
  "" AS "Notas"
FROM
  clubs AS c2
LEFT JOIN
  club_premiums cp2 ON c2.id = cp2.club_id
LEFT JOIN
  users u ON cp2.user_id = u.id
LEFT JOIN
  countries AS ctr ON ctr.id = c2.country_id
LEFT JOIN
  cities AS c4 ON c4.id = c2.city_id
LEFT JOIN
  InscripcionesUltimos30Dias i ON i.club_id = c2.id
LEFT JOIN
  ReservasUltimos30Dias r ON r.club_id = c2.id
WHERE
  c2.id != 1540
  AND cp2.expiration > NOW()
  AND cp2.deleted_at IS NULL
GROUP BY
  c2.id,
  c2.uuid,
  c2.name,
  c2.phone,
  c2.contact_email,
  ctr.name,
  c4.name,
  i.TotalInscripciones,
  r.TotalReservas
ORDER BY
  c2.name ASC;
"@

Export-VolaDataAsCsv -FechaInicio $FechaInicio `
    -FechaFin $FechaFin `
    -Paquete 'Lunes' `
    -NombreDeFicheroBase 'clubes-con-fremium-activado' `
    -Data (Get-VolaDbData -Query $sql)