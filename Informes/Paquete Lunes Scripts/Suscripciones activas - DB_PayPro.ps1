[CmdletBinding()]
param (
    [string] $SubscriptionsFile,

    [Parameter(Mandatory)]
    [PSCustomObject[]] $TecnicaData
)

# SUSCRIPCIONES ACTIVAS - DB_PAYPRO

. "$PSScriptRoot/../VolaUtil.ps1" > $null

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

$fechaActual = Get-Date -Format 'yyyy-MM-dd'


$data = Import-Csv -Path $subscriptionsReportFromPayProFile -Delimiter ';' | Select-Object @(
    @{ Name = 'Vola Id'; Expression = { <# To set later, this must be the first column #> } }
    @{ Name = 'Subscription ID'; Expression = { $_.'Subscription ID' } },
    @{ Name = 'Name'; Expression = { $_.'Subscription Name' } },
    @{ Name = 'Initial order ID'; Expression = { $_.'Initial Order ID' } },
    @{ Name = 'Number of processed billing cycles'; Expression = { $_.'Billing Cycle' } },
    @{ Name = 'Current subscription status'; Expression = { $_.'Subscription Status' } },
    @{ Name = 'Type of renewal'; Expression = { $_.'Renewal Type' } },
    @{ Name = 'Next charge amount'; Expression = { $_.'Next Charge Amount' } },
    @{ Name = 'Last charge date'; Expression = { Convert-PayProDateFormat ($_.'Last Charge Date (UTC)') } },
    @{ Name = 'Next charge date'; Expression = { Convert-PayProDateFormat ($_.'Next Charge Date (UTC)') } },
    @{ Name = 'Product Id'; Expression = { $_.'Product ID' } },
    @{ Name = 'Customer first name'; Expression = { $_."Customer's First Name" } },
    @{ Name = 'Customer last name'; Expression = { $_."Customer's Last Name" } },
    @{ Name = 'Customer e-mail'; Expression = { $_."Customer's Email" } },
    @{ Name = 'Company name'; Expression = { $_.'Company Name' } },
    @{ Name = 'Customer country'; Expression = { $_."Billing Country Name" } },
    @{ Name = 'Customer state'; Expression = { $_.'Billing State Name' } },
    @{ Name = 'Customer language'; Expression = { $_.'Language Name' } },
    @{ Name = 'Quantity'; Expression = { $_.'Quantity' } },
    @{ Name = 'Max billing cycles'; Expression = { $_.'Max Billing Cycles' } },
    @{ Name = 'Failed attempts'; Expression = { $_.'Failed Attempts' } },
    @{ Name = 'Billing initial price'; Expression = { $_.'Initial Order Billing Total Price' } },
    @{ Name = 'Billing total price'; Expression = { $_.'Recurring Billing Total Price' } },
    @{ Name = 'Billing currency'; Expression = { $_.'Billing Currency Code' } },
    @{ Name = 'SKU'; Expression = { $_.'SKU' } },
    @{ Name = 'Test mode'; Expression = { $_.'Test mode' } },
    @{ Name = 'Affiliate'; Expression = { $_.'Trial Ends (UTC)' } }, # I guess this is the column for 'Affiliate'
    @{ Name = 'Created at'; Expression = { Convert-PayProDateFormat ($_.'Date/Time (UTC)') } }, # I guess this is the column for 'Created at'
    @{ Name = 'Scheduled payment at'; Expression = { Convert-PayProDateFormat ($_.'Scheduled Payment At (UTC)') } },
    @{ Name = 'Has trial period'; Expression = { $_.'On trial' } },
    @{ Name = 'Billing period'; Expression = { $_.'Billing period' } },
    @{ Name = 'Grace period'; Expression = { $_.'Grace period' } }
)

# paypro date format: 05/29/2026 15:07:29
# desired format: 2024-09-23 20:24

$clubIdByOrderId = @{}
foreach ($row in $TecnicaData) {
    $clubIdByOrderId[$row.'Order ID'] = $row.'Vola Id'
}

foreach ($row in $data) {
    $row.'Vola Id' = $clubIdByOrderId[$row.'Initial order ID']
}


New-Item -Path "$PSScriptRoot/../Paquete Lunes CSV" -ItemType Directory -Force > $null
$data | Export-Csv -LiteralPath "$PSScriptRoot/../Paquete Lunes CSV/suscripciones-activas_db-paypro__$fechaActual.csv" -UseQuotes Never -Delimiter ';' > $null

return $data
