<#

SKUs:

2012-R2-Datacenter
2016-Datacenter
2019-Datacenter


VMSizes:

Standard_A2
Standard_B2s

#>

# Params
    param (
        [Parameter(Mandatory=$true)]
        [string] 
        $VmName,

        [Parameter(Mandatory=$true)]
        [string] 
        $RGName,          
        
        [Parameter(Mandatory=$true)]
        [string] 
        $VMSize,

        [Parameter(Mandatory=$true)]
        [string] 
        $VMSKU
          )

# login to Azure
$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Create Resource Group
New-AzureRmResourceGroup -ResourceGroupName $RGName -Location EastUS

# Create Subnet
$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name PSSubnet -AddressPrefix 172.100.1.0/24
Write-Output "Creating Subnet..."

# Create Vnet
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $RGName -Location EastUS -Name PSVnet -AddressPrefix 172.100.0.0/16 -Subnet $subnetConfig
Write-Output "Creating Vnet..."

# Create PIP
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $RGName -Location EastUS -AllocationMethod Static -Name PSPIP
Write-Output "Creating PIP..."

# Create NIC
$nic = New-AzureRmNetworkInterface -ResourceGroupName $RGName -Location EastUS -Name PSNic -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id
Write-Output "Creating NIC..."

# Create NSG Rule
$nsgRule = New-AzureRmNetworkSecurityRuleConfig -Name PSNSGRuleRDP -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
$nsgRule1 = New-AzureRmNetworkSecurityRuleConfig -Name PSNSGRuleAny -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange * -Access Allow
Write-Output "Creating NSG Rules..."

# Create NSG
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RGName -Location EastUS -Name PSNSG -SecurityRules $nsgRule,$nsgRule1
Write-Output "Creating NSG..."

# Assign NSG to Subnet
Set-AzureRmVirtualNetworkSubnetConfig -Name PSSubnet -VirtualNetwork $vnet -NetworkSecurityGroup $nsg -AddressPrefix 172.100.1.0/24
Write-Output "Assign NSG to Subnet..."

#Update subnet with NSG
Set-AzureRmVirtualNetwork -VirtualNetwork $vnet
Write-Output "Update subnet with NSG..."

#Set Cred for VM
$UserName = "helpdesk"
$PlainPassword = "#Dkns**449561"
$SecurePassword = $PlainPassword | ConvertTo-SecureString -AsPlainText -Force 
$cred = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword

#Set Vm config, name and Size
$vmconfig = New-AzureRmVMConfig -VMName $VmName -VMSize $VMSize | Set-AzureRmVMOperatingSystem -Windows -ComputerName $VmName -Credential $cred | Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus $VMSKU -Version latest | Add-AzureRmVMNetworkInterface -Id $nic.Id
Write-Output "Seting Vm config, name and Size..."

Write-Output "Creating VM..."

#Create VM
New-AzureRmVM -ResourceGroupName $RGName -Location EastUS -VM $vmconfig

Write-Output "VM Created!"