param (
    [Parameter(Mandatory)]
    [PSCustomObject[]] $DbPayProData
)

# SUSCRIPCIONES ACTIVAS - DB_VOLA

. "$PSScriptRoot/../VolaUtil.ps1"

$fechaActual = Get-Date -Format 'yyyy-MM-dd'

$sql = @"
SELECT
    c.uuid AS ID,
    c.name AS Nombre,
    DATE_FORMAT(DATE_ADD(c.created_at, INTERVAL 2 HOUR), '%d/%m/%Y %H:%i') AS 'Fecha de alta en Vola',
    c.vat AS VAT,
    c.phone AS Teléfono,
    c3.name AS País,
    c4.name AS Ciudad,
    suh.start_at AS 'Inicio suscripción',
    suh.end_at AS 'Fin suscripción',
    CASE
        WHEN suh.plan_id = 92372 THEN 'Basic'
        WHEN suh.plan_id = 92373 THEN 'Medium'
        WHEN suh.plan_id = 92374 THEN 'Pro'
        WHEN suh.plan_id = 102735 THEN 'Lite'
    END AS 'Tipo de suscripción'
FROM
    subscription_user_history suh
JOIN
    clubs c ON c.id = suh.club_id
LEFT JOIN
    countries c3 ON c3.id = c.country_id
LEFT JOIN
    cities c4 ON c4.id = c.city_id
WHERE
    c.id != 1540
    AND suh.start_at <= NOW()
    AND suh.end_at >= NOW();
"@

$data = Get-VolaDbData -Query $sql | ForEach-Object {
    $_ | Add-Member -MemberType NoteProperty -Name 'Estado (PP)' -Value $null -PassThru `
    | Add-Member -MemberType NoteProperty -Name 'Suscripción (PP)' -Value $null -PassThru
}

$subscriptionAndStateByClubId = @{}
foreach ($row in $DbPayProData) {
    if ($row.'Vola Id') {
        $value = [pscustomobject] @{
            'Estado (PP)'      = $row.'Current subscription status'
            'Suscripción (PP)' = $row.'Name'
        }
        $subscriptionAndStateByClubId[$row.'Vola Id'] = $value
    }
}

foreach ($row in $data) {
    if ($subscriptionAndStateByClubId[$row.'ID']) {
        $row.'Estado (PP)' = ($subscriptionAndStateByClubId[$row.'ID'].'Estado (PP)')
        $row.'Suscripción (PP)' = ($subscriptionAndStateByClubId[$row.'ID'].'Suscripción (PP)')
    }
}

New-Item -Path "$PSScriptRoot/../Paquete Lunes CSV" -ItemType Directory -Force > $null
$data | Export-Csv -LiteralPath "$PSScriptRoot/../Paquete Lunes CSV/suscripciones-activas_db-vola__$fechaActual.csv" -UseQuotes Never -Delimiter ';' > $null
