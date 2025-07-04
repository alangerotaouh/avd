param(
  [string] $HostPoolId
)

# Installiere das RDInfra-Modul, falls nicht vorhanden
if (-not (Get-Module -ListAvailable -Name Microsoft.RDInfra.RDPowerShell)) {
    Install-Module -Name Microsoft.RDInfra.RDPowerShell -Force -Scope AllUsers
}

Import-Module Microsoft.RDInfra.RDPowerShell

# Hostpool-Name ermitteln und Session Host registrieren
$tenant   = Get-RdsTenant
$pool     = Get-RdsHostPool -Id $HostPoolId
$computer = $env:COMPUTERNAME

Add-RdsSessionHost -TenantName   $tenant.Name `
                   -HostPoolName $pool.Name `
                   -Name         $computer
