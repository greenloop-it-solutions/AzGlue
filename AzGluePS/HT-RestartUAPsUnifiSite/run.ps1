using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

#Wait-Debugger
$siteCode = $TriggerMetadata.siteid

$UniFiFqdn = "unifi.glsol.com"
$UnifiBaseUri = "https://" + $UniFiFqdn + ":8443/api"
$UnifiCredentials = @{
    username = 'GreenLoop'
    password = $ENV:UniFi_GreenLoop_Password
    remember = $true
} | ConvertTo-Json

#may be necessary to negotiate to TLS1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#login to UniFi to start a session
Invoke-RestMethod -Uri "$UnifiBaseUri/login" -Method POST -Body $UnifiCredentials -SessionVariable websession

function Get-UniFiUAPDevices ($siteCode) {
    $request_uri = $UnifiBaseUri + "/s/$($siteCode)/stat/device-basic"

    $devices = (Invoke-RestMethod -Uri $request_uri -Method Get -WebSession $websession).data

    $uap_devices = $devices | ? {$_.type -eq "uap" -and $_.adopted -eq $true -and $_.disabled -eq $false}
    return $uap_devices
}

function Restart-UniFiDevice ($siteCode, $mac) {
    $request_uri = $UnifiBaseUri + "/s/$($siteCode)/cmd/devmgr"

    $body = @{
            "mac" = $mac
            "reboot-type" = "soft"
            "cmd" = "restart"
        }  | ConvertTo-Json
         
    $devices = (Invoke-RestMethod -Uri $request_uri -Method POST -Body $body -WebSession $websession).data
}

$uap_devices = Get-UniFiUAPDevices -siteCode $siteCode

foreach ($uap in $uap_devices) {
    $uapmac = $uap.mac
    Restart-UniFiDevice -siteCode $siteCode -mac $uapmac
    Start-Sleep -Seconds 30
}