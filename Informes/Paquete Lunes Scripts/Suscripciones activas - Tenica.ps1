# SUSCRIPCIONES ACTIVAS - TÉCNICA

. "$PSScriptRoot/../VolaUtil.ps1" > $null

do {
    Write-Host "Ahora tienes que seleccionar el CSV del informe de Sold Products de PayPro (rango amplio y sin filtros)" -ForegroundColor Yellow
    Read-Host "Presionar enter para continuar..." > $null
    $soldProductsReportFromPayProFile = Invoke-CrossPlatformFileSelector -Title 'Selecciona el CSV del informe de Sold Products'
}
while ($null -eq $soldProductsReportFromPayProFile)

$fechaActual = Get-Date -Format 'yyyy-MM-dd'


$data = Import-Csv -Path $soldProductsReportFromPayProFile -Delimiter ';' | Select-Object @(
    @{ Name = 'Order ID'; Expression = { $_.'Order ID' } }
    @{ Name = 'Order Status'; Expression = { $_.'Order Status' } }
    @{ Name = 'Order Item ID'; Expression = { $_.'Order Item ID' } }
    @{ Name = 'Order Item Type'; Expression = { $_.'Order Item Type' } }
    @{ Name = 'Date/Time (UTC)'; Expression = { $_.'Date/Time (UTC)' } }
    @{ Name = 'Product ID'; Expression = { $_.'Product ID' } }
    @{ Name = 'Product Name'; Expression = { $_.'Product Name' } }
    @{ Name = 'Quantity'; Expression = { $_.'Quantity' } }
    @{ Name = 'Billing Currency Name'; Expression = { $_.'Billing Currency Name' } }
    @{ Name = 'SKU'; Expression = { $_.'SKU' } }
    @{ Name = 'Test mode'; Expression = { $_."Test Mode" } }
    @{ Name = 'Recurring Payment'; Expression = { $_."Recurring Payment" } }
    @{ Name = 'License Key'; Expression = { $_."License Key" } }
    # @{ Name = 'Custom Data'; Expression = { $_.'Custom Data' } }
    @{ Name = 'Vola Id'; Expression = { ($_."Custom Data").SubString(5) } }
)

New-Item -Path "$PSScriptRoot/../Paquete Lunes CSV" -ItemType Directory -Force > $null
$data | Export-Csv -LiteralPath "$PSScriptRoot/../Paquete Lunes CSV/suscripciones-activas_tecnica__$fechaActual.csv" -UseQuotes Never -Delimiter ';' > $null


return $data
