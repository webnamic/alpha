[datetime]$time_start = Get-Date
#$timestamp = Get-Date -Format 'yyyy-MM-dd-HH-mm-ss'
Write-Output "Deployment started at [$time_start]"

$rgName ='sacRG'
$location = 'West Europe'
$vnetName = 'vnet-mg-sp-t2-weu-05'
$vnetRGName = 'rg-mg-sp-t2-weu-vnet-05'
$subnetname = 'xxxx'
$vmSize = 'Standard_DS2_v2'
$osSKU = 'RS2-Pro'
$vmName = 'vmsactestfour'
$storaccName = $vmName + 'stor'
# Usernames and passwords
$username = 'sacadmin'
$password = 'Bananaman01#'
$passwordsec = convertto-securestring $password -asplaintext -force 
$creds = New-Object System.Management.Automation.PSCredential($username, $passwordsec)

$DJ1 = '{
    "Name": "XXXX.com",
    "OUPath": "OU=Clients,OU=Machines,DC=abc,DC=def,DC=com",
    "User": "XXXXXX",
    "Restart": "true",
    "Options": "3"
        }'

$DJ2 = '{ "Password": "XXXXXX" }'

$Connection = Get-AutomationConnection -Name sacTestConnection
Add-AzureRMAccount -ServicePrincipal -Tenant $Connection.TenantID -ApplicationID $Connection.ApplicationID -CertificateThumbprint $Connection.CertificateThumbprint 

Set-AzureRmContext -SubscriptionName "sub-mg-sp-t2-05"

if (Get-AzureRmResourceGroup -Name $rgName -Location $location)
{
    #RG already exists
    Write-Output "RG already exists."
}
else
{
    Write-Output "Creating RG."
    New-AzureRmResourceGroup -Name $rgName -Location $location
}
 
if (Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName)
{
    Write-Output "VM already exists"
}
else
{
    Write-Output "Creating VM."
    $storacct = New-AzureRmStorageAccount -Name $storaccName -ResourceGroupName $rgName –Type 'Standard_LRS' -Location $location
    #$storacct = Get-AzureRmStorageAccount -ResourceGroupName $rgName –StorageAccountName $storaccName 
    $disknameOS = $vmname + 'diskOS' 
    $vhduri = $storacct.PrimaryEndpoints.Blob.OriginalString + 'vhds/${disknameOS}.vhd'
    $images = Get-AzureRmVMImage -Location $location -PublisherName 'MicrosoftWindowsDesktop' -Offer 'Windows-10' -Skus $osSKU | Sort-Object -Descending -Property PublishedDate
    $vnet = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $vnetRGName
    $nic = New-AzureRmNetworkInterface -Name "${vmname}nic01" -Location $location -ResourceGroupName $rgName -SubnetId $vnet.Subnets[1].Id
    #$nic = Get-AzureRmNetworkInterface -Name "${vmname}nic1" -ResourceGroupName $rgName
    $newVM = New-AzureRmVMConfig -Name $vmName -VMSize $vmSize 
    $newVM = Add-AzureRmVMNetworkInterface -VM $newVM -Id $nic.Id
    $newVM = Set-AzureRmVMOperatingSystem -Windows -VM $newVM -ProvisionVMAgent -EnableAutoUpdate -Credential $creds -ComputerName $vmname -TimeZone "GMT Standard Time"
    $newVM = Set-AzureRmVMSourceImage -VM $newVM -PublisherName $images[0].PublisherName -Offer $images[0].Offer -Skus $images[0].Skus -Version $images[0].Version 
    $newVM = Set-AzureRmVMOSDisk -VM $newVM -Name $disknameOS -Caching ReadWrite -CreateOption fromImage
    
    New-AzureRmVM -ResourceGroupName $rgName -Location $location -VM $newVM

    Set-AzureRMVMExtension -ResourceGroupName $rgName -ExtensionType "JsonADDomainExtension" -Name "joindomain" -Publisher "Microsoft.Compute" -TypeHandlerVersion "1.0" -VMName $vmName -Location $location -SettingString $DJ1 -ProtectedSettingString $DJ2
}
 

[datetime]$time_end = Get-Date
Write-Output "Deployment ended at [$time_end]"
