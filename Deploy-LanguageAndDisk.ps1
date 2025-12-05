Configuration Deploy-LanguageAndDisk
{

    Node localhost
    {
        LocalConfigurationManager 
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        Script ConfigureGermanLanguage
        {
            SetScript = {

                # OS-Disk vergrößern
                $partition     = Get-Partition -DriveLetter C
                $sizeRemaining = Get-PartitionSupportedSize -DriveLetter C
                Resize-Partition -DriveLetter C -Size $sizeRemaining.SizeMax


                # DataDisk vergrößern
                $disk = Get-Disk -Number 1
                Initialize-Disk -Number 1 -PartitionStyle GPT -PassThru |
                    New-Partition -UseMaximumSize -DriveLetter F |
                    Format-Volume -FileSystem NTFS -NewFileSystemLabel "DataDisk" -Confirm:$false


                # Sprachpaket-ISO herunterladen
                New-Item -ItemType Directory -Path "C:\Temp" -Force | Out-Null
                Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?linkid=2195333" -OutFile "C:\Temp\lang.iso"

                # ISO mounten
                Mount-DiskImage -ImagePath "C:\Temp\lang.iso"

                # WAIT UNTIL ISO IS MOUNTED
                $timeout = (Get-Date).AddMinutes(5)
                do {
                    $isoDrive = (Get-Volume | Where-Object FileSystemLabel -like '*SERVER*' | Select-Object -First 1).DriveLetter
                    Start-Sleep -Seconds 2
                } until ($isoDrive -or (Get-Date) -gt $timeout)

                if (-not $isoDrive) { throw "ISO wurde nicht erfolgreich gemountet." }

                $langPath = "$isoDrive`:\LanguagesAndOptionalFeatures\"


                # LPKSETUP
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c lpksetup /i de-DE /p `"$langPath`" /s" -Wait -NoNewWindow

                # WARTEN BIS LPKSetup seine Registry-Werte geschrieben hat
#                $timeout = (Get-Date).AddMinutes(5)
#                do {
#                    $installed = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages\Microsoft-Windows-Server-Language-Pack*de-de*"
#                    Start-Sleep -Seconds 2
#                } until ($installed -or (Get-Date) -gt $timeout)
#
#                if (-not $installed) { throw "Sprachpaket wurde von LPKSetup nicht korrekt installiert." }


                # DISM
                $cabPath = Join-Path $langPath "Microsoft-Windows-Server-Language-Pack_x64_de-de.cab"
                Start-Process -FilePath "dism.exe" -ArgumentList "/online /Add-Package /PackagePath:`"$cabPath`"" -Wait -NoNewWindow

                # WARTEN BIS DISM fertig ist (CBS-Flag)
                $timeout = (Get-Date).AddMinutes(5)
                do {
                    $pending = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
                    Start-Sleep -Seconds 2
                } until (-not $pending -or (Get-Date) -gt $timeout)

                # Wenn DISM einen Reboot benötigt → das ist normal, Script läuft trotzdem weiter
                # Du kannst bei Bedarf hier abbrechen:
                # if ($pending) { throw "DISM hat einen RebootPending-Status." }


                # Sprache/Region/Zeit einstellen
                $lang = "de-DE"
                Set-WinUILanguageOverride -Language $lang
                Set-WinSystemLocale $lang
                Set-WinUserLanguageList -LanguageList $lang -Force
                Set-Culture -CultureInfo $lang
                Set-WinHomeLocation -GeoId 94
                Set-TimeZone -Id "W. Europe Standard Time"
                $ll = New-WinUserLanguageList $lang
                Set-WinUserLanguageList $ll -Force
            }

            TestScript = {
                $cultureOk   = (Get-Culture).Name -eq 'de-DE'
                $sysLocaleOk = (Get-WinSystemLocale).Name -eq 'de-DE'
                return ($cultureOk -and $sysLocaleOk)
            }

            GetScript = {
                $culture = (Get-Culture).Name
                $sysLoc  = (Get-WinSystemLocale).Name
                $uiLangs = (Get-WinUserLanguageList).LanguageTag -join ','
                @{ Result = "Culture=$culture;SystemLocale=$sysLoc;UILang=$uiLangs" }
            }
        }

        PendingReboot ConfigureGermanLanguage
        {
            Name = 'ConfigureGermanLanguage'
            DependsOn = "[Script]ConfigureGermanLanguage"
        }
    }
}
