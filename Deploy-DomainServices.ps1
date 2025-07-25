Configuration Deploy-DomainServices
{
    Param
    (
        [Parameter(Mandatory)]
        [String] $domainFQDN,
        [String] $domainSuffix,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential] $adminCredential
    )

    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'ActiveDirectoryDsc'
    Import-DscResource -ModuleName 'ComputerManagementDsc'
    Import-DscResource -ModuleName 'NetworkingDsc'

    # Erstelle NetBIOS-Name und Domain-Credentials basierend auf $domainFQDN
    $domainCredential = New-Object System.Management.Automation.PSCredential(
        "$($adminCredential.GetNetworkCredential().Username)@$domainFQDN",
        $adminCredential.Password
    )

    # Wähle Netzwerk-Adapter für IP-Konfiguration
    $interface = Get-NetAdapter | Where-Object Name -Like 'Network' | Select-Object -First 1
    if (-not $interface) {
        $interface = Get-NetAdapter | Where-Object Name -Like 'Ethernet' | Select-Object -First 1
    }
    $interfaceAlias = $interface.Name

    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode     = 'ApplyOnly'
            RebootNodeIfNeeded    = $true
        }

        WindowsFeature InstallDNS
        {
            Ensure = 'Present'
            Name   = 'DNS'
        }

        WindowsFeature InstallDNSTools
        {
            Ensure    = 'Present'
            Name      = 'RSAT-DNS-Server'
            DependsOn = '[WindowsFeature]InstallDNS'
        }

        DnsServerAddress SetDNS
        {
            Address = '127.0.0.1'
        }

        # ============================================================
        # OU-Struktur für EntraSync
        # ============================================================
        ADOrganizationalUnit OU_EntraSync
        {
            Name       = 'EntraSync'
            Path       = "DC=$domainSuffix,DC=local"
            Ensure     = 'Present'
            Credential = $domainCredential
            DependsOn  = '[WaitForADDomain]WaitForDomainController'
        }

        ADOrganizationalUnit OU_Users
        {
            Name       = 'Users'
            Path       = "OU=EntraSync,DC=$domainSuffix,DC=local"
            Ensure     = 'Present'
            Credential = $domainCredential
            DependsOn  = '[ADOrganizationalUnit]OU_EntraSync'
        }

        ADOrganizationalUnit OU_Groups
        {
            Name       = 'Groups'
            Path       = "OU=EntraSync,DC=$domainSuffix,DC=local"
            Ensure     = 'Present'
            Credential = $domainCredential
            DependsOn  = '[ADOrganizationalUnit]OU_EntraSync'
        }

        # ============================================================
        # Neue OU-Struktur für NotSynced
        # ============================================================
        ADOrganizationalUnit OU_NotSynced
        {
            Name       = 'NotSynced'
            Path       = "DC=$domainSuffix,DC=local"
            Ensure     = 'Present'
            Credential = $domainCredential
            DependsOn  = '[ADOrganizationalUnit]OU_EntraSync'
        }

        ADOrganizationalUnit OU_NotSynced_Users
        {
            Name       = 'Users'
            Path       = "OU=NotSynced,DC=$domainSuffix,DC=local"
            Ensure     = 'Present'
            Credential = $domainCredential
            DependsOn  = '[ADOrganizationalUnit]OU_NotSynced'
        }

        ADOrganizationalUnit OU_NotSynced_Groups
        {
            Name       = 'Groups'
            Path       = "OU=NotSynced,DC=$domainSuffix,DC=local"
            Ensure     = 'Present'
            Credential = $domainCredential
            DependsOn  = '[ADOrganizationalUnit]OU_NotSynced'
        }

        # ============================================================
        # Gruppen in EntraSync\Groups
        # ============================================================
        ADGroup AVD_Access
        {
            GroupName  = 'AVD-Access'
            Path       = "OU=Groups,OU=EntraSync,DC=$domainSuffix,DC=local"
            GroupScope = 'Global'
            Ensure     = 'Present'
            Credential = $domainCredential
            DependsOn  = '[ADOrganizationalUnit]OU_Groups'
        }

        ADGroup AVD_ProfileAccess
        {
            GroupName  = 'AVD-ProfileAccess'
            Path       = "OU=Groups,OU=EntraSync,DC=$domainSuffix,DC=local"
            GroupScope = 'Global'
            Ensure     = 'Present'
            Credential = $domainCredential
            DependsOn  = '[ADOrganizationalUnit]OU_Groups'
        }

        # ============================================================
        # Benutzer MaxMustermann in EntraSync\Users
        # ============================================================
        ADUser MaxMustermann
        {
            UserName        = 'MaxMustermann'
            SamAccountName  = 'MaxMustermann'
            GivenName       = 'Max'
            Surname         = 'Mustermann'
            DisplayName     = 'Max Mustermann'
            Path            = "OU=Users,OU=EntraSync,DC=$domainSuffix,DC=local"
            AccountPassword = (ConvertTo-SecureString 'Passw0rd!' -AsPlainText -Force) 
            Enabled         = $true
            Ensure          = 'Present'
            Credential      = $domainCredential
            DependsOn       = '[ADOrganizationalUnit]OU_EntraSync_Users'
        }

        # ============================================================
        # Mitgliedschaften
        # ============================================================
        ADGroupMember AVD_Access_Member
        {
            Group      = 'AVD-Access'
            Members    = @('MaxMustermann')
            Ensure     = 'Present'
            Credential = $domainCredential
            DependsOn  = '[ADUser]MaxMustermann'
        }

        ADGroupMember AVD_ProfileAccess_Member
        {
            Group      = 'AVD-ProfileAccess'
            Members    = @('MaxMustermann')
            Ensure     = 'Present'
            Credential = $domainCredential
            DependsOn  = '[ADUser]MaxMustermann'
        }
    }
}

# Hilfsfunktion für NetBIOS-Name
function Get-NetBIOSName {
    [OutputType([string])]
    param(
        [string] $domainFQDN
    )

    if ($domainFQDN.Contains('.')) {
        $length = $domainFQDN.IndexOf('.')
        if ($length -ge 16) { $length = 15 }
        return $domainFQDN.Substring(0, $length)
    }
    else {
        if ($domainFQDN.Length -gt 15) {
            return $domainFQDN.Substring(0, 15)
        }
        else {
            return $domainFQDN
        }
    }
}
