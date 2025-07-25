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

    # Create the NetBIOS name and domain credentials based on the domain FQDN
    [String] $domainNetBIOSName = (Get-NetBIOSName -DomainFQDN $domainFQDN)
    [System.Management.Automation.PSCredential] $domainCredential = New-Object System.Management.Automation.PSCredential ("${domainNetBIOSName}\$($adminCredential.UserName)", $adminCredential.Password)

    $interface = Get-NetAdapter | Where-Object Name -Like 'Network' | Select-Object -First 1
        if (-not $interface) {
    $interface = Get-NetAdapter | Where-Object Name -Like 'Ethernet' | Select-Object -First 1
}
    $interfaceAlias = $($interface.Name)

    Node localhost
    {
        LocalConfigurationManager 
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        WindowsFeature InstallDNS 
        { 
            Ensure = 'Present'
            Name = 'DNS'
        }

        WindowsFeature InstallDNSTools
        {
            Ensure = 'Present'
            Name = 'RSAT-DNS-Server'
            DependsOn = '[WindowsFeature]InstallDNS'
        }

        DnsServerAddress SetDNS
        { 
            Address = '127.0.0.1'
            InterfaceAlias = $interfaceAlias
            AddressFamily = 'IPv4'
            DependsOn = '[WindowsFeature]InstallDNS'
        }

        WindowsFeature InstallADDS
        {
            Ensure = 'Present'
            Name = 'AD-Domain-Services'
            DependsOn = '[WindowsFeature]InstallDNS'
        }

        WindowsFeature InstallADDSTools
        {
            Ensure = 'Present'
            Name = 'RSAT-ADDS-Tools'
            DependsOn = '[WindowsFeature]InstallADDS'
        }

        ADDomain CreateADForest
        {
            DomainName = $domainFQDN
            Credential = $domainCredential
            SafemodeAdministratorPassword = $domainCredential
            ForestMode = 'WinThreshold'
            DatabasePath = 'C:\NTDS'
            LogPath = 'C:\NTDS'
            SysvolPath = 'C:\SYSVOL'
            DependsOn = '[DnsServerAddress]SetDNS', '[WindowsFeature]InstallADDS'
        }

        PendingReboot RebootAfterCreatingADForest
        {
            Name = 'RebootAfterCreatingADForest'
            DependsOn = "[ADDomain]CreateADForest"
        }
        WaitForADDomain WaitForDomainController
        {
            DomainName = $domainFQDN
            WaitTimeout = 600
            RestartCount = 3
            Credential = $domainCredential
            WaitForValidCredentials = $true
            DependsOn = "[PendingReboot]RebootAfterCreatingADForest"
        }
# Start neuer Block mit OUs
        ADOrganizationalUnit OU_EntraSync {
            Name        = 'EntraSync'
            Path        = "DC=$domainSuffix,DC=local" # Domain anpassen
            Ensure      = 'Present'
            Credential  = $domainCredential
            DependsOn   = '[WaitForADDomain]WaitForDomainController'
        }

        ADOrganizationalUnit OU_Users {
            Name        = 'Users'
            Path        = "OU=EntraSync,DC=$domainSuffix,DC=local" # Domain anpassen
            Ensure      = 'Present'
            Credential  = $domainCredential
            DependsOn   = '[ADOrganizationalUnit]OU_EntraSync'
        }

        ADOrganizationalUnit OU_Groups {
            Name        = 'Groups'
            Path        = "OU=EntraSync,DC=$domainSuffix,DC=local" # Domain anpassen
            Ensure      = 'Present'
            Credential  = $domainCredential
            DependsOn   = '[ADOrganizationalUnit]OU_EntraSync'
        }
# neuer Block mit OU's ENDE        
    }
}

function Get-NetBIOSName {
    [OutputType([string])]
    param(
        [string] $domainFQDN
    )

    if ($domainFQDN.Contains('.')) {
        $length = $domainFQDN.IndexOf('.')
        if ( $length -ge 16) {
            $length = 15
        }
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