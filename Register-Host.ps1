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

$downloadMap = @{
    'https://go.microsoft.com/fwlink/?linkid=2310011' = 'AVDAgent.msi'
    'https://go.microsoft.com/fwlink/?linkid=2311028' = 'AVDBootLoader.msi'
}
$targetPath = 'C:\Temp'

if (-not (Test-Path $targetPath)) { New-Item -Path $targetPath -ItemType Directory | Out-Null }
Set-Location $targetPath

foreach ($kvp in $downloadMap.GetEnumerator()) {
    $uri        = $kvp.Key
    $fixedName  = $kvp.Value
    $expanded   = (Invoke-WebRequest -Uri $uri -MaximumRedirection 0 -ErrorAction SilentlyContinue).Headers.Location
    Invoke-WebRequest -Uri $expanded -OutFile $fixedName -UseBasicParsing
    Unblock-File -Path $fixedName
}

msiexec /i "$targetPath\AVDAgent.msi" /quiet /norestart REGISTRATIONTOKEN=$registrationToken "/l*v" "$($targetPath)\AVDAgentInstall.log"

msiexec /i "$targetPath\AVDBootLoader.msi" /quiet /norestart "/l*v" "$($targetPath)\AVDBootLoader.log"



