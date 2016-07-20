Function Get-AzureRmVmPublicIP {
<#
    .SYNOPSIS
        Correlate AzureRM VMs, NetworkInterfaces, and Public IPs
    
    .DESCRIPTION
        Correlate AzureRM VMs, NetworkInterfaces, and Public IPs

        Prerequisites:
            
            * You have the AzureRM module
            * You're authenticated
            * You're running PowerShell 4 or later

    .PARAMETER ResourceGroupName
        Query this resource group

    .PARAMETER VMName
        One or more VM names to include.  Accepts wildcards.  Defaults to all.

    .PARAMETER IncludeObjects
        If specified, include VM, NIC, and PIP (Public IP) properties on each entry

    .PARAMETER VMStatus
        If specified, the VM property from IncludeObjects will include data from Get-AzureRmVm '-Status'

        Using this switch will trigger IncludeObjects

    .EXAMPLE
        Login-AzureRmAccount
        Get-AzureRmVmPublicIP -ResourceGroupName 'my-resource-group'

            # VMName  NICName    PublicIP
            # ------  -------    --------
            # VM-2    VM-2-NIC   23.96.1.2
            # VM-3    VM-3-NIC   23.96.1.3
            # VM-4    VM-4-NIC   168.61.2.1
            # VM-16   VM-16-NIC  168.61.10.27
            # VM-17   VM-17-NIC  23.96.17.56
            # VM-18   VM-18-NIC  23.96.19.71
            # VM-1    VM-1-NIC   Not Assigned

        # List VMs, NICS, and Public IPs in 'my-resource-group'

    .EXAMPLE
        Login-AzureRmAccount
        Get-AzureRmVmPublicIP -ResourceGroupName 'my-resource-group' -VMName VM-1* -IncludeObjects

            # ...
            # VMName   : VM-18
            # NICName  : VM-18-NIC
            # PublicIP : 23.96.19.71
            # VM       : Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine
            # NIC      : Microsoft.Azure.Commands.Network.Models.PSNetworkInterface
            # PIP      : Microsoft.Azure.Commands.Network.Models.PSPublicIpAddress

            # VMName   : VM-1
            # NICName  : VM-1-NIC
            # PublicIP : Not Assigned
            # VM       : Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine
            # NIC      : Microsoft.Azure.Commands.Network.Models.PSNetworkInterface
            # PIP      : Microsoft.Azure.Commands.Network.Models.PSPublicIpAddress

        # Get VMs, NICs, and Public IPs in 'my-resource-group'
        # with name like VM-1*
        # Include the VM, Network Interface (NIC), and Public IP (PIP) objects properties

    .EXAMPLE
        $Details = Get-AzureRmVmPublicIP -ResourceGroupName 'my-resource-group' -VMStatus
        $Details[0]

            # VMName   : VM-18
            # NICName  : VM-18-NIC
            # PublicIP : 23.96.19.71
            # VM       : Microsoft.Azure.Commands.Compute.Models.PSVirtualMachineInstanceView <<<<
            # NIC      : Microsoft.Azure.Commands.Network.Models.PSNetworkInterface
            # PIP      : Microsoft.Azure.Commands.Network.Models.PSPublicIpAddress

        # All sorts of data to explore in the VM property.  Output from Get-AzureRmVm -Name <ThisVm> -Status
        $Details[0].VM.VMAgent.ExtensionHandlers

            # Type                                        TypeHandlerVersion Status                                                      
            # ----                                        ------------------ ------                                                      
            # Microsoft.Azure.Diagnostics.IaaSDiagnostics 1.7.1.0            Microsoft.Azure.Management.Compute.Models.InstanceViewStatus
            # Microsoft.Compute.BGInfo                    2.1                Microsoft.Azure.Management.Compute.Models.InstanceViewStatus
            # Microsoft.Compute.CustomScriptExtension     1.8                Microsoft.Azure.Management.Compute.Models.InstanceViewStatus

    .EXAMPLE

        Get-AzureRmVmPublicIP -ResourceGroupName $ResourceGroup -VMName VM-18 -VMStatus |
        Select -Property VMName,
                         PublicIP,
                         @{ label = "PrivateIP"; expression = {$_.NIC.IpConfigurations.PrivateIpAddress} },
                         @{ label = "VMAgentStatus"; expression = {$_.VM.VMAgent.Statuses[0].DisplayStatus} }

            # VMName PublicIP    PrivateIP    VMAgentStatus
            # ------ --------    ---------    -------------
            # VM-18  23.96.19.71 10.1.2.5     Ready       

        # Pull details from VM-18,
        # extract private IP from the NIC, and the first VMAgent status we find from the VM

    .FUNCTIONALITY
        Azure
#>
    [cmdletbinding()]
    param(
        [string[]]$ResourceGroupName,
        [string[]]$VMName,
        [switch]$IncludeObjects,
        [switch]$VMStatus
    )

    foreach($ResourceGroup in $ResourceGroupName)
    {

        # Here's an absurd snippet of code to extract all VMs, NICs, and Public IPs, and correlate them together.
        # From what I can tell, the Azure team didn't provide the usual pipeline support...
        # This method will skip public IPs that aren't bound to a NIC, or NICs that aren't bound to a VM
        Try
        {
            $AllVMs = @( Get-AzureRMVm -ResourceGroupName $ResourceGroup -ErrorAction Stop )
        }
        Catch
        {
            Write-Error $_
            Write-Error "Could not extract VMs from resource group '$ResourceGroup'"
            continue
        }
        Try
        {
            $NICS = @( Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroup -ErrorAction Stop )
        }
        Catch
        {
            Write-Error $_
            Write-Error "Could not extract network interfaces from resource group '$ResourceGroup'"
            continue
        }
        Try
        {
            $PublicIPS = @( Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroup -ErrorAction Stop)
        }
        Catch
        {
            Write-Error $_
            Write-Error "Could not extract public IPs from resource group '$ResourceGroup'"
            continue
        }

        # Allow wildcard support for each name in array... filter dupes
        $TheseVMs = foreach($VM in $AllVMs)
        {
            if($VMName)
            {
                foreach($Name in $VMName)
                {
                    if($VM.Name -like $Name)
                    {
                        $VM
                    }
                }
            }
            else
            {
                $VM
            }
        }
        $TheseVMs = @( $TheseVMs | Sort Name -Unique )

        # Correlate. Uses PS4 language.
        Foreach($nic in $nics)
        {
            $VMs = $null   
            $VMs = $TheseVMs.Where({$_.Id -eq $nic.virtualmachine.id})
            $PIPS = $null
            $PIPS = $PublicIPS.Where({$_.Id -eq $nic.IpConfigurations.publicipaddress.id})
            foreach($VM in $VMs)
            {
                if($VMStatus)
                {
                    Try
                    {
                        $VMDetail = Get-AzureRMVm -ResourceGroupName $ResourceGroup -Status -Name $VM.Name -ErrorAction stop
                    }
                    Catch
                    {
                        Write-Error $_
                        Write-Error "Could not extract '-Status' details from $($VM.Name) in resource group $ResourceGroup. Falling back to non detailed"
                        $VMDetail = $VM
                    }
                    if(-not $IncludeObjects)
                    {
                        $IncludeObjects = $True
                    }
                }
                else
                {
                    $VMDetail = $VM
                }

                foreach($PIP in $PIPS)
                {
                    # Include VM, NIC, Public IP (PIP) raw objects if desired
                    $Output = [ordered]@{
                        ResourceGroupName = $ResourceGroup
                        VMName = $VM.Name
                        NICName = $nic.Name
                        PublicIP = $PIP.IpAddress
                    }

                    if($IncludeObjects)
                    {
                        $Output.Add('VM', $VMDetail)
                        $Output.Add('NIC', $NIC)
                        $Output.Add('PIP', $PIP)
                    }

                    [pscustomobject]$Output
                }
            }
        }
    }
}