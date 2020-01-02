<# 
 .Synopsis 
 Validates an ipaddress is in a given subnet based on CIDR notation 
.DESCRIPTION 
Clone to the c# code given in http://social.msdn.microsoft.com/Forums/en-US/29313991-8b16-4c53-8b5d-d625c3a861e1/ip-address-validation-using-cidr?forum=netfxnetcom 
.EXAMPLE 
IS-InSubnet -ipaddress 10.20.20.0 -Cidr 10.20.20.0/16 
 .Author 
Srinivasa Rao Tumarada 
#> 
 
Function IS-InSubnet() { 
    [CmdletBinding()] 
    [OutputType([bool])] 
    Param( 
        [Parameter(Mandatory=$true, 
            ValueFromPipelineByPropertyName=$true, 
            Position=0)] 
        [validatescript({([System.Net.IPAddress]$_).AddressFamily -match 'InterNetwork'})] 
        [string]$ipaddress="", 
        [Parameter(Mandatory=$true, 
            ValueFromPipelineByPropertyName=$true, 
            Position=1)] 
        [validatescript({(([system.net.ipaddress]($_ -split '/'|select -first 1)).AddressFamily -match 'InterNetwork') -and (0..32 -contains ([int]($_ -split '/'|select -last 1) )) })] 
        [string]$Cidr="" 
    ) 
    Begin{ 
        [int]$BaseAddress=[System.BitConverter]::ToInt32((([System.Net.IPAddress]::Parse(($cidr -split '/'|select -first 1))).GetAddressBytes()),0) 
        [int]$Address=[System.BitConverter]::ToInt32(([System.Net.IPAddress]::Parse($ipaddress).GetAddressBytes()),0) 
        [int]$mask=[System.Net.IPAddress]::HostToNetworkOrder(-1 -shl (32 - [int]($cidr -split '/' |select -last 1))) 
    } 
    Process{ 
        if( ($BaseAddress -band $mask) -eq ($Address -band $mask)) { 
            $status=$True 
        }else { 
            $status=$False 
        } 
    } 
    end { Write-output $status } 
}

# Dynamic NLS Sites

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$DebugPreference = "Continue"
Import-Module .\nls.psm1 -Force
$clientId = "clientID"
$clientSecret = "clientSecret"
$customer = "customerID"

#define variables
$internalConnectivity=$false
$externalConnectivity=$false
$internalBeacon="cloudconnector.internal.local"
$globalNLSSites = @("HeadOffice")

#test is we can reach the beacon to determine if we have internal network connection
if((Test-NetConnection $internalBeacon).PingSucceeded -eq $true){
    Write-Debug "Internal beacon reachable"
    $internalConnectivity=$true
}

try{
    #if externalConnectivity
    #retrieve the external IP address
    $externalIP=(Invoke-WebRequest -uri "http://ifconfig.me/ip").Content;
    Write-Debug $externalIP
    #retrieve additional information 
    $externalIPInfo=Invoke-RestMethod -Uri ('http://ipinfo.io/'+(Invoke-WebRequest -uri "http://ifconfig.me/ip").Content)
    Write-Debug $externalIPInfo

    # Connect to NLS
    Connect-NLS -clientId $clientId -clientSecret $clientSecret -customer $customer

    # If InternalConnectivity and NOT in current NLS scope create custom NLS
    If($internalConnectivity) {
        # Get all NLS Sites and check if there is an existing entry for this IP
        $allNLSSites = Get-NLSSite

        $nlsExists = $false

        # Iterate through all sites and check if current IP is included in existing NLS Sites
        foreach($nlsSite in $allNLSSites) {
            $ipv4Ranges = $nlsSite.ipv4Ranges
    
            foreach($ipv4Range in $ipv4Ranges) {
                if((IS-InSubnet -ipaddress $externalIP -Cidr $ipv4Range)){
                    $nlsExists = $true
                }
            }
        }

        # If current IP is not included in current NLS Site, create NLS Site for this specific IP
        if(-not $nlsExists){
            New-NLSSite -name "$($externalIP)" -tags @("CustomNLS") -timezone "$($externalIPInfo.timezone)" -ipv4Ranges @("$($externalIP)/32") -longitude $externalIPInfo.loc.Split(",")[1] -latitude $externalIPInfo.loc.Split(",")[0]
        }
    }

    # If NOT InternalConnectivity check if NLS Site for current IP exists and delete site if not in pre-defined NLS Site list
    if(-not $internalConnectivity) {
        # Get all NLS Sites (excluding global NLS Sites) and check if there is an existing entry for this IP
        $allNLSSites = Get-NLSSite | Where-Object {$globalNLSSites -notcontains $_.name}

        # Iterate through all sites and check if current IP is included in existing NLS Sites
        foreach($nlsSite in $allNLSSites) {
            $ipv4Ranges = $nlsSite.ipv4Ranges
    
            foreach($ipv4Range in $ipv4Ranges) {
                # If current IP is included in existing NLS Site, remove NLS Site
                if((IS-InSubnet -ipaddress $externalIP -Cidr $ipv4Range)){
                    (Get-NLSSite | Where-Object { $_.name -eq $nlsSite.name }) | Remove-NLSSite
                }
            }
        }
    }
} catch [System.Net.WebException] {
    $_.Exception.Message
} catch [System.Management.Automation.ParameterBindingException] {
    $_.Exception.Message
} 
