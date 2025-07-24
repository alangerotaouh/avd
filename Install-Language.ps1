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