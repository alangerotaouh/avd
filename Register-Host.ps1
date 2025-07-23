param(
    [string] $registrationToken,
    [string] $storageAccountName
)

$targetPath = 'C:\Temp'

# Zielordner anlegen, falls er fehlt
if (-not (Test-Path $targetPath)) {
    New-Item -Path $targetPath -ItemType Directory | Out-Null
}

# Download-URLs → Zielfilennamen
$downloadMap = @{
    'https://go.microsoft.com/fwlink/?linkid=2310011' = 'AVDAgent.msi'
    'https://go.microsoft.com/fwlink/?linkid=2311028' = 'AVDBootLoader.msi'
}

foreach ($kvp in $downloadMap.GetEnumerator()) {
  $uri      = $kvp.Key
  $fileName = $kvp.Value
  $outFile  = Join-Path $targetPath $fileName

  Invoke-WebRequest -Uri $uri -OutFile $outFile
  Unblock-File    -Path   $outFile
}

# Silent-Installation aus C:\Temp
msiexec /i "$targetPath\AVDAgent.msi" /qn /quiet /norestart REGISTRATIONTOKEN=$registrationToken "/l*v" "$targetPath\AVDAgentInstall.log"
Start-Sleep -Seconds 30
msiexec /i "$targetPath\AVDBootLoader.msi" /qn /quiet /norestart "/l*v" "$targetPath\AVDBootLoader.log"

Start-Sleep -Seconds 30

#setfslogix
$registryPath = "HKLM:\SOFTWARE\FSLogix\Profiles"
New-ItemProperty -Path $registryPath -Name "Enabled" -Value 1 -PropertyType DWORD -Force
$multiSzValue = "\\$storageAccountName.file.core.windows.net\profiles"
New-ItemProperty -Path $registryPath -Name "VHDLocations" -Value $multiSzValue -PropertyType MultiString -Force

Start-Sleep -Seconds 30

#installlanguage
Install-Language de-DE
Set-SystemPreferredUILanguage -Language de-DE
Set-WinSystemLocale de-DE
set-WinUserLanguageList -LanguageList de-DE -Force
Set-WinHomeLocation -GeoId 94
Set-TimeZone -id 'W. Europe Standard Time'
Set-Culture -CultureInfo de-DE
Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
Set-WinUILanguageOverride -Language de-DE
set-WinUserLanguageList -LanguageList de-DE -force
Restart-Computer -Force



