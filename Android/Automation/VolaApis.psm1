$ApiKey = $env:PmApiKey

$Domain = "vola.plus"

function Invoke-ApiUserExists([string] $Email) {
    try {
        $response = Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/login?email=$([uri]::EscapeDataString($Email))&password=0&api_key=$ApiKey&lang=en"
        $message = [string] $response.message
    
        switch ($message) {
            "Incorrect password" { 
                return $true
            }
            "User not found" {
                return $false
            }
            default {
                Write-Error "Something went wrong: $message"
            }
        }
    }
    catch {
        Write-Error "Something went wrong: $($_.Exception.Message)"
        throw
    }
}

function Invoke-ApiNationalities() {
    try {
        $response = Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v2/settings/nationalities?api_key=$ApiKey&lang=en"
        return $response.data
    }
    catch {
        Write-Error "Something went wrong: $($_.Exception.Message)"
        throw
    }
}

function Invoke-ApiContries() {
    try {
        $response = Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v2/settings/countries?api_key=$ApiKey&lang=en"
        return $response.data
    }
    catch {
        Write-Error "Something went wrong: $($_.Exception.Message)"
        throw
    }
}
