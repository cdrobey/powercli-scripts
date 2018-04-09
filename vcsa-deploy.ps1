# Current Author: Chris Roberson
#
# Original Author: William Lam
# Website: www.virtuallyghetto.com
# Description: PowerCLI script to deploy a fully functional vSphere 6.5 VCSA 
# Physical ESXi host or vCenter Server to deploy vSphere 6.5 lab

$VIServer = "ESX.FQDN"
$VIUsername = "root"
$VIPassword = "PASSWORD"

$VCSAInstallerPath = "E:\"

# VCSA Deployment Configuration
$VCSADeploymentSize = "tiny"
$VCSADisplayName = "COVCSAP01"
$VCSAIPAddress = "XX.X.X.X"
$VCSAHostname = "hostname.fqdn"
$VCSAPrefix = "24"
$VCSASSODomainName = "vcsa.local"
$VCSASSOSiteName = "Default"
$VCSASSOPassword = "PASSWORD"
$VCSARootPassword = "PASSWORD"
$VCSASSHEnable = "true"

# General Deployment Configuration for Nested ESXi, & VCSAVMs
$VMNetwork = "vLAN"
$VMDatastore = "vDS"
$VMNetmask = "255.255.255.0"
$VMGateway = "X.X.X.1"
$VMDNS = "X.X.X.1"
$VMNTP = "X.X.X.1"
$VMPassword = "PASSWORD"
$VMDomain = "fqdn"
$VMSyslog = "X.X.X.X"
$VMCluster = "Cluster"

# Name of new vSphere Datacenter/Cluster when VCSA is deployed
$NewVCDatacenterName = "Data Center"
$NewVCClusterName = "Cluster"

# ESXi VMs to deploy
$ESXiHostnameToIPs = @{
"esx01" = "X.X.X.X"
"esx02" = "X.X.X.X"
}
# Advanced Configurations
# Set to 1 only if you have DNS (forward/reverse) for ESXi hostnames
$addHostByDnsName = 1

#### DO NOT EDIT BEYOND HERE ####

$verboseLogFile = "vcenter-vghetto-lab-deployment.log"
$vSphereVersion = "6.5"
$deploymentType = "Standard"
$random_string = -join ((65..90) + (97..122) | Get-Random -Count 8 | % {[char]$_})
$VAppName = "vGhetto-Nested-vSphere-Lab-$vSphereVersion-$random_string"

$vcsaSize2MemoryStorageMap = @{
"tiny"=@{"cpu"="2";"mem"="10";"disk"="250"};
"small"=@{"cpu"="4";"mem"="16";"disk"="290"};
"medium"=@{"cpu"="8";"mem"="24";"disk"="425"};
"large"=@{"cpu"="16";"mem"="32";"disk"="640"};
"xlarge"=@{"cpu"="24";"mem"="48";"disk"="980"}
}

$vcsaTotalCPU = 0
$vcsaTotalMemory = 0
$vcsaTotalStorage = 0

$preCheck = 1
$confirmDeployment = 1
$deployNestedESXiVMs = 1
$deployVCSA = 1
$setupNewVC = 1
$addESXiHostsToVC = 1
$moveVMsIntovApp = 1

$StartTime = Get-Date

Function My-Logger {
    param(
    [Parameter(Mandatory=$true)]
    [String]$message
    )

    $timeStamp = Get-Date -Format "MM-dd-yyyy_hh:mm:ss"

    Write-Host -NoNewline -ForegroundColor White "[$timestamp]"
    Write-Host -ForegroundColor Green " $message"
    $logMessage = "[$timeStamp] $message"
    $logMessage | Out-File -Append -LiteralPath $verboseLogFile
}

if($preCheck -eq 1) {
    if(!(Test-Path $VCSAInstallerPath)) {
        Write-Host -ForegroundColor Red "`nUnable to find $VCSAInstallerPath ...`nexiting"
        exit
    }
}

if($confirmDeployment -eq 1) {
    Write-Host -ForegroundColor Magenta "`nPlease confirm the following configuration will be deployed:`n"

    Write-Host -ForegroundColor Yellow "---- vGhetto vCenter Server Appliance ---- "
    Write-Host -NoNewline -ForegroundColor Green "Deployment Target: "
    Write-Host -ForegroundColor White $DeploymentTarget
    Write-Host -NoNewline -ForegroundColor Green "Deployment Type: "
    Write-Host -ForegroundColor White $deploymentType
    Write-Host -NoNewline -ForegroundColor Green "VCSA Image Path: "
    Write-Host -ForegroundColor White $VCSAInstallerPath

    if($DeploymentTarget -eq "ESXI") {
        Write-Host -ForegroundColor Yellow "`n---- Physical ESXi Deployment Target Configuration ----"
        Write-Host -NoNewline -ForegroundColor Green "ESXi Address: "
    } 

    Write-Host -ForegroundColor White $VIServer
    Write-Host -NoNewline -ForegroundColor Green "Username: "
    Write-Host -ForegroundColor White $VIUsername
    Write-Host -NoNewline -ForegroundColor Green "VM Network: "
    Write-Host -ForegroundColor White $VMNetwork


    Write-Host -NoNewline -ForegroundColor Green "VM Storage: "
    Write-Host -ForegroundColor White $VMDatastore

    Write-Host -ForegroundColor Yellow "`n---- VCSA Configuration ----"
    Write-Host -NoNewline -ForegroundColor Green "Deployment Size: "
    Write-Host -ForegroundColor White $VCSADeploymentSize
    Write-Host -NoNewline -ForegroundColor Green "SSO Domain: "
    Write-Host -ForegroundColor White $VCSASSODomainName
    Write-Host -NoNewline -ForegroundColor Green "SSO Site: "
    Write-Host -ForegroundColor White $VCSASSOSiteName
    Write-Host -NoNewline -ForegroundColor Green "SSO Password: "
    Write-Host -ForegroundColor White $VCSASSOPassword
    Write-Host -NoNewline -ForegroundColor Green "Root Password: "
    Write-Host -ForegroundColor White $VCSARootPassword
    Write-Host -NoNewline -ForegroundColor Green "Enable SSH: "
    Write-Host -ForegroundColor White $VCSASSHEnable
    Write-Host -NoNewline -ForegroundColor Green "Hostname: "
    Write-Host -ForegroundColor White $VCSAHostname
    Write-Host -NoNewline -ForegroundColor Green "IP Address: "
    Write-Host -ForegroundColor White $VCSAIPAddress
    Write-Host -NoNewline -ForegroundColor Green "Netmask "
    Write-Host -ForegroundColor White $VMNetmask
    Write-Host -NoNewline -ForegroundColor Green "Gateway: "
    Write-Host -ForegroundColor White $VMGateway
    
    $vcsaTotalCPU = $vcsaSize2MemoryStorageMap.$VCSADeploymentSize.cpu
    $vcsaTotalMemory = $vcsaSize2MemoryStorageMap.$VCSADeploymentSize.mem
    $vcsaTotalStorage = $vcsaSize2MemoryStorageMap.$VCSADeploymentSize.disk

    Write-Host -ForegroundColor Yellow "`n---- Resource Requirements ----"
    Write-Host -NoNewline -ForegroundColor Green "VCSA VM CPU: "
    Write-Host -NoNewline -ForegroundColor White $vcsaTotalCPU
    Write-Host -NoNewline -ForegroundColor Green " VCSA VM Memory: "
    Write-Host -NoNewline -ForegroundColor White $vcsaTotalMemory "GB "
    Write-Host -NoNewline -ForegroundColor Green "VCSA VM Storage: "
    Write-Host -ForegroundColor White $vcsaTotalStorage "GB"

    Write-Host -ForegroundColor Magenta "`nWould you like to proceed with this deployment?`n"
    $answer = Read-Host -Prompt "Do you accept (Y or N)"
    if($answer -ne "Y" -or $answer -ne "y") {
        exit
    }
    Clear-Host
}

My-Logger "Connecting to $VIServer ..."
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false
$viConnection = Connect-VIServer $VIServer -User $VIUsername -Password $VIPassword -WarningAction SilentlyContinue

$datastore = Get-Datastore -Server $viConnection -Name $VMDatastore

# Deploy using the VCSA CLI Installer
$config = (Get-Content -Raw "$($VCSAInstallerPath)\vcsa-cli-installer\templates\install\embedded_vCSA_on_ESXi.json") | convertfrom-json
$config.'new.vcsa'.esxi.hostname = $VIServer
$config.'new.vcsa'.esxi.username = $VIUsername
$config.'new.vcsa'.esxi.password = $VIPassword
$config.'new.vcsa'.esxi.'deployment.network' = $VMNetwork
$config.'new.vcsa'.esxi.datastore = $datastore
$config.'new.vcsa'.appliance.'thin.disk.mode' = $true
$config.'new.vcsa'.appliance.'deployment.option' = $VCSADeploymentSize
$config.'new.vcsa'.appliance.name = $VCSADisplayName
$config.'new.vcsa'.network.'ip.family' = "ipv4"
$config.'new.vcsa'.network.mode = "static"
$config.'new.vcsa'.network.ip = $VCSAIPAddress
$config.'new.vcsa'.network.'dns.servers'[0] = $VMDNS
$config.'new.vcsa'.network.prefix = $VCSAPrefix
$config.'new.vcsa'.network.gateway = $VMGateway
$config.'new.vcsa'.network.'system.name' = $VCSAHostname
$config.'new.vcsa'.os.password = $VCSARootPassword
$config.'new.vcsa'.os.'ssh.enable' = $true
$config.'new.vcsa'.sso.password = $VCSASSOPassword
$config.'new.vcsa'.sso.'domain-name' = $VCSASSODomainName
$config.'new.vcsa'.sso.'site-name' = $VCSASSOSiteName

My-Logger "Creating VCSA JSON Configuration file for deployment ..."
$config | ConvertTo-Json | Set-Content -Path "$($ENV:Temp)\jsontemplate.json"

My-Logger "Deploying the VCSA ..."
Invoke-Expression "$($VCSAInstallerPath)\vcsa-cli-installer\win32\vcsa-deploy.exe install --no-esx-ssl-verify --accept-eula --acknowledge-ceip $($ENV:Temp)\jsontemplate.json"| Out-File -Append -LiteralPath $verboseLogFile

My-Logger "Disconnecting from $VIServer ..."
Disconnect-VIServer $viConnection -Confirm:$false



My-Logger "Connecting to the new VCSA ..."
$vc = Connect-VIServer $VCSAIPAddress -User "administrator@$VCSASSODomainName" -Password $VCSASSOPassword -WarningAction SilentlyContinue

My-Logger "Creating Datacenter $NewVCDatacenterName ..."
New-Datacenter -Server $vc -Name $NewVCDatacenterName -Location (Get-Folder -Type Datacenter -Server $vc) | Out-File -Append -LiteralPath $verboseLogFile
My-Logger "Creating  Cluster $NewVCClusterName ..."
New-Cluster -Server $vc -Name $NewVCClusterName -Location (Get-Datacenter -Name $NewVCDatacenterName -Server $vc) -DrsEnabled  | Out-File -Append -LiteralPath $verboseLogFile


$ESXiHostnameToIPs.GetEnumerator() | sort -Property Value | Foreach-Object {
   $VMName = $_.Key
   $VMIPAddress = $_.Value

   $targetVMHost = $VMIPAddress
   if($addHostByDnsName -eq 1) {
               $targetVMHost = $VMName
   }
   My-Logger "Adding ESXi host $targetVMHost to Cluster ..."#   Add-VMHost -Server $vc -Location (Get-Cluster -Name $NewVCClusterName) -User "root" -Password $VMPassword -Name $targetVMHost -Force | Out-File -Append -LiteralPath $verboseLogFile
   Add-VMHost -Server $vc -Location (Get-Cluster -Name $NewVCClusterName) -User "root" -Password $VMPassword -Name $targetVMHost -Force | Out-File -Append -LiteralPath $verboseLogFile

}

My-Logger "Disconnecting from new VCSA ..."
Disconnect-VIServer $vc -Confirm:$false

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)

My-Logger "vSphere $vSphereVersion Lab Deployment Complete!"
My-Logger "StartTime: $StartTime"
My-Logger "  EndTime: $EndTime"
My-Logger " Duration: $duration minutes"
