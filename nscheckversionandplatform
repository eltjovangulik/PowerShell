<#
.SYNOPSIS
   Opvragen Netscaler versie en platform info
.DESCRIPTION
   Opvragen Netscaler versie en platform info
   Gebaseerd op het originele script van Ryan Butler: https://github.com/ryancbutler/Citrix/blob/master/Netscaler/CTX227928.ps1
.PARAMETER nsip
   NSIP IP adres of hostname (verplicht)
.PARAMETER adminaccount
   Netscaler admin account (Default: nsroot)
.PARAMETER adminpassword
   Password voor het Netscaler admin account (Default: nsroot)
.PARAMETER https
   HTTPS gebruiken voor de communicatie
.Example
    .\nscheckversion.ps1 -nsip "192.168.1.1" -adminaccount nsroot -adminpassword nsrootwachtwoord
    Retouneerd de versie en het platform van de Netscaler met NSIP ip adres 192.168.1.1     
.Example
    .\nscheckversion.ps1 -nsip nsip.domein.local -adminaccount adm-gebruiker -adminpassword adpassword
    Retouneerd de netscaler versie en het platform van de Netscaler waarvan het NSIP nsip.domain.local is met behulp van het in de Netscaler geconfigureerde adm-gebruiker account
#>

[cmdletbinding()]
Param
(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]$nsip,
    [String]$adminaccount="nsroot",
    [String]$adminpassword="nsroot",
    [switch]$https
)

begin{
function Login-ns ($hostname) {
    # Login to NetScaler and save session to global variable
       $body = ConvertTo-JSON @{
           "login"=@{
               "username"="$adminaccount";
               "password"="$adminpassword"
               }
           }
       try {
       Invoke-RestMethod -uri "$hostname/nitro/v1/config/login" -body $body -SessionVariable NSSession `
       -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.login+json"} -Method POST|Out-Null
       $Script:NSSession = $local:NSSession
       }
       Catch
       {
       #throw $_
       throw "Kon geen verbinding met $hostname tot stand brengen met de opgegeven credentials."
       }
   }
   
function Logout-ns {
   #logs out of Netscaler
       $body = ConvertTo-JSON @{
           "logout"=@{
               }
           }
       Invoke-RestMethod -uri "$hostname/nitro/v1/config/logout" -body $body -WebSession $NSSession `
       -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.logout+json"} -Method POST|Out-Null
   }

function check-nsversion {
    $info = Invoke-RestMethod -uri "$hostname/nitro/v1/config/nsversion" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    $version = $info.nsversion.version
    return $version
}
function check-majorversion {
    $info = Invoke-RestMethod -uri "$hostname/nitro/v1/config/nsversion" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    $version = $info.nsversion.version
    $majorversion = $version.Substring(12,4)
    return $majorversion
}
function check-build {
    $info = Invoke-RestMethod -uri "$hostname/nitro/v1/config/nsversion" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    $version = $info.nsversion.version
    #$majorversion = $version.Substring(12,4)
    $build = $version.Substring(24,5)
    return $build
}



function check-platform {
    $info = Invoke-RestMethod -uri "$hostname/nitro/v1/config/nshardware" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    $platform = $info.nshardware.hwdescription
    return $platform
}




}

process{
    if ($https)
    {
        [System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        write-verbose "Connecting HTTPS"
        $hostname = "https://" + $nsip
    }
    else
    {
        write-verbose "Connecting HTTP"
        $hostname = "http://" + $nsip
    }
    login-ns $hostname
    $nsversion = New-Object PSCustomObject
    $nsversion|add-member -NotePropertyName "NSIP" -NotePropertyValue $nsip
    $nsversion|add-member -NotePropertyName "VERSION" -NotePropertyValue (check-nsversion)
    $nsversion|add-member -NotePropertyName "Platform" -NotePropertyValue (check-platform)
    $nsversion|add-member -NotePropertyName "Majorversion" -NotePropertyValue(check-majorversion)
    $nsversion|add-member -NotePropertyName "Build" -NotePropertyValue(check-build)

    return $nsversion

     
    Logout-ns
}
