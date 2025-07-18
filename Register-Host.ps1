<# param(
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
 #>

param(
    [string] $registrationToken
)

$agentInstallerPath = "C:\Temp\AVDAgent.msi"
$bootLoaderInstallerPath = "C:\Temp\AVDBootLoader.msi"

Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2310011" -OutFile $agentInstallerPath
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2311028" -OutFile $bootLoaderInstallerPath

Start-Process msiexec.exe -Wait -ArgumentList "/I $agentInstallerPath /quiet /qn /norestart REGISTRATIONTOKEN=$registrationToken"
Start-Process msiexec.exe -Wait -ArgumentList "/I $bootLoaderInstallerPath /quiet /qn /norestart"
