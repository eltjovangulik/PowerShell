<#
.SYNOPSIS
   Opvragen Netscaler versie info
.DESCRIPTION
   Opvragen Netscaler versie info en vergelijkt deze tegen  https://support.citrix.com/article/CTX227928 en https://support.citrix.com/article/CTX230238
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
    Retouneerd de versie van de Netscaler met NSIP ip adres 192.168.1.1 , en de status van de versie en build met betrekking tot CTX227928 en CTX230238
    
.Example
    .\nscheckversion.ps1 -nsip nsip.domein.local -adminaccount adm-gebruiker -adminpassword adpassword
    Retouneerd de netscaler versie van de Netscaler waarvan het NSIP nsip.domain.local is met behulp van het in de Netscaler geconfigureerde adm-gebruiker account
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
    #$build = $version.Substring(24,5)
    <#
     if ($majorversion -match 12) {
        return "is versie 12"
    }
    #>
    return $majorversion
}
function check-build {
    $info = Invoke-RestMethod -uri "$hostname/nitro/v1/config/nsversion" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    $version = $info.nsversion.version
    #$majorversion = $version.Substring(12,4)
    $build = $version.Substring(24,5)
    return $build
<#
    if ($build -match 53.13){
        return "is 53.13"
    }
    #>
}
function check-CTX227928 {
    $info = Invoke-RestMethod -uri "$hostname/nitro/v1/config/nsversion" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    $version = $info.nsversion.version
    $majorversion = $version.Substring(12,4)
    $build = $version.Substring(24,5)
    # https://support.citrix.com/article/CTX227928
    if (($majorversion -match 12.0) -and ($build -match 41.24)){
        return "Versie is 12.0 en build is 41.24 dus niet kwetsbaar"
    }

    if (($majorversion -match 12.0) -and ($build -lt 53.13)) {
        return "versie 12.0 en lager dan 53.13, dus kwetsbaar"
    }
    elseif (($majorversion -match 12.0) -and ($build -ge 53.13)){
        return "versie 12.0 en build 53.13 of hoger dus niet kwetsbaar"
    }
      if (($majorversion -match 11.1) -and ($build -lt 55.13)){
        return "versie 11.1 en lager dan 55.13, dus kwetsbaar"
    }
    elseif (($majorversion -match 11.1) -and ($build -lt 55.13)){
        return "versie 11.1 en hoger dan 55.13, dus niet kwetsbaar"
    }
    if (($majorversion -match 11.0) -and ($build -lt 70.16)){
        return "versie 11.0 en lager dan 70.16 dus kwetsbaar"
    }
    elseif (($majorversion -match 11.0)-and ($build -ge 70.16)){
        return "versie 11.0 en build hoger dan 70.16 dus niet kwetsbaar"
    }
    if (($majorversion -match 10.5) -and ($build -lt 66.9)){
        return "versie 10.5 en lager dan 70.16 dus kwetsbaar"
    }
    if ($majorversion -lt 10.5){
        return "versie is lager dan 10.5. Deze versies zijn vanaf 18 april 2018 EOL"
    }
 }
function check-CTX230238 {
    $info = Invoke-RestMethod -uri "$hostname/nitro/v1/config/nsversion" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    $version = $info.nsversion.version
    $majorversion = $version.Substring(12,4)
    $build = $version.Substring(24,5)
    #https://support.citrix.com/article/CTX230238
    <#
    if (($majorversion -lt 12.0) -and ($build -lt 53.22)) {
        return "vulnerable voor CTX230238"
    }
    else {
        return "niet vulnerable voor CTX230238"
    }
#>
    if (($majorversion -match 12.0) -and ($build -lt 53.22)) {
        return "versie 12 en lager dan 53.22, dus kwetsbaar"
    }
    elseif (($majorversion -match 12.0) -and ($build -ge 53.22)){
        return "versie 12.0 en build hoger dan 53.22 dus niet kwetsbaar"
    }
    if (($majorversion -match 11.1) -and ($build -lt 56.19)){
        return "versie 11.1 en lager dan 56.19, dus kwetsbaar"
    }
    elseif (($majorversion -match 11.1) -and ($build -ge 56.19)){
        return "versie 11.1 en build hoger dan 56.19, dus niet kwetsbaar"
    }

    if (($majorversion -match 11.0) -and ($build -lt 71.22)){
        return "versie 11.0 en lager dan 71.22, dus kwetsbaar"
    }
    elseif (($majorversion -match 11.0) -and ($build -ge 71.22)){
        return "versie 11.0 en build hoger dan 71.22, dus niet kwetsbaar"
    }

    if (($majorversion -match 10.5) -and ($build -lt 67.13)){
        return "versie 10.5 en lager dan 67.13, dus kwetsbaar"
    }
    elseif (($majorversion -match 10.5) -and ($build -ge 67.13)){
        return "versie 10.5 en build hoger dan 67.13, dus niet kwetsbaar"
    }
    if ($majorversion -lt 10.5){
        return "versie is lager dan 10.5. Deze versies zijn vanaf 18 april 2018 EOL"
    }


   <# 
    if (($majorversion -match 11.0) -and ($build -lt 71.22)){
        return "versie 11.0 en lager dan 71.22 dus vulenerable"
    }
    elseif (($majorversion -match 11.0)-and ($build -ge 71.22)){
        return "versie 11.0 en build hoger dan 71.22 dus niet vulnerable"
    }
    #>
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
    $nsversion|add-member -NotePropertyName "Majorversion" -NotePropertyValue(check-majorversion)
    $nsversion|add-member -NotePropertyName "Build" -NotePropertyValue(check-build)
    $nsversion|add-member -NotePropertyName "CTX227928" -NotePropertyValue(check-CTX227928)
    $nsversion|add-member -NotePropertyName "CTX230238" -NotePropertyValue(check-CTX230238)

    return $nsversion

     
    Logout-ns
}