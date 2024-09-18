$ApiKey = $env:PmApiKey


$script:Environment = "Production"

function Set-VolaEnvironment {

    param (
        [Parameter(Mandatory)]
        [ValidateSet("Production", "Test")]
        [string] $Environment
    )

    $script:Environment = $Environment
}

function Get-VolaEnvironment {
    return $script:Environment
}

function GetVolaDomain {
    switch ($script:Environment) {
        "Production" {
            return "vola.plus"
        }
        "Test" {
            return "test.vola.plus"
        }
        default {
            Write-Error "Unknown environment: $script:Environment"
        }
    }
}

function Invoke-ApiUserExists([string] $Email) {
    try {
        $domain = GetVolaDomain
        $response = Invoke-RestMethod -Method Get -Uri "https://$domain/api/v1/login?email=$([uri]::EscapeDataString($Email))&password=0&api_key=$ApiKey&lang=en"
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
        $domain = GetVolaDomain
        $response = Invoke-RestMethod -Method Get -Uri "https://$domain/api/v2/settings/nationalities?api_key=$ApiKey&lang=en"
        return $response.data
    }
    catch {
        Write-Error "Something went wrong: $($_.Exception.Message)"
        throw
    }
}

function Invoke-ApiContries() {
    try {
        $domain = GetVolaDomain
        $response = Invoke-RestMethod -Method Get -Uri "https://$domain/api/v2/settings/countries?api_key=$ApiKey&lang=en"
        return $response.data
    }
    catch {
        Write-Error "Something went wrong: $($_.Exception.Message)"
        throw
    }
}
