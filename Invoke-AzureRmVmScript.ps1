# WARNING: THIS HAS MINIMAL TESTING AND SHOULD BE CONSIDERED EXPERIMENTAL
#          Use at your own risk, and read through the code before using it
function Invoke-AzureRmVmScript {
<#
    .SYNOPSIS
        Invoke an ad hoc PowerShell script on an AzureRM VM
    
    .DESCRIPTION
        Invoke an ad hoc PowerShell script on an AzureRM VM

        Prerequisites:
            * You have the AzureRM module
            * You're authenticated and have appropriate privileges
            * You're running PowerShell 3 or later (tested on 5, YMMV)

    .PARAMETER ResourceGroupName
        Resource group for the specified VMs

    .PARAMETER VMName
        One or more VM names to run against

    .PARAMETER StorageAccountName
        Storage account to store the script we invoke

    .PARAMETER StorageAccountKey
        Optional storage account key to generate StorageContext

        If not specified, we look one up via Get-AzureRmStorageAccountKey

        Note that this is a string. Beware, given the sensitivity of this key

    .PARAMETER StorageContext
        Optional Azure storage context to use.  We build one if not provided
    
    .PARAMETER StorageContainer
        Optional StorageContainer to use.  Defaults to 'scripts'
    
    .PARAMETER Filename
        Optional Filename to use.  Defaults to CustomScriptExtension.ps1

    .PARAMETER ExtensionName
        Optional arbitrary name for the extension we add.  Defaults to CustomScriptExtension
    
    .PARAMETER ForceExtension
        If specified and a CustomScriptExtension already exists on a VM, we will remove it

    .PARAMETER ForceBlob
        If specified and a blob exists with the same Filename and StorageContainer used here, we overwrite it 

    .PARAMETER Force
        If specified, we trigger both ForceExtension and ForceBlob

    .PARAMETER ScriptBlock
        Scriptblock to invoke.  It appears we can collect output from StdOut and StdErr.  Keep in mind these will be in string form.

    .EXAMPLE

    $params = @{
        ResourceGroupName = 'My-Resource-Group'
        VMName = 'VM-22'
        StorageAccountName = 'storageaccountname'
    }
    Invoke-AzureRmVmScript @params -ScriptBlock {
        "Hello world! Running on $(hostname)"
        Write-Error "This is an error"
        Write-Warning "This is a warning"
        Write-Verbose "This is verbose!"
    }

        # ResourceGroupName : My-Resource-Group
        # VMName            : VM-22
        # Substatuses       : {Microsoft.Azure.Management.Compute.Models.InstanceViewStatus,
        #                      Microsoft.Azure.Management.Compute.Models.InstanceViewStatus}
        # StdOut_succeeded  : Hello world! Running on VM-22\nWARNING: This is a warning
        # StdErr_succeeded  : C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.
        #                     8\Downloads\0\Cus\ntomScriptExtension.ps1 : This is an 
        #                     error\n    + CategoryInfo          : NotSpecified: (:) 
        #                     [Write-Error], WriteErrorExcep \n   tion\n    + 
        #                     FullyQualifiedErrorId : 
        #                     Microsoft.PowerShell.Commands.WriteErrorExceptio \n   
        #                     n,CustomScriptExtension.ps1\n 

    # This example runs a simple hello world script on VM-22
    # The force parameter removed an existing CustomScriptExtension,
    #     and overwrote a matching container/file in my azure storage account

    .FUNCTIONALITY
        Azure
#>
    [cmdletbinding()]
    param(
        # todo: add various parameter niceties
        [Parameter(Mandatory = $True,
                   Position = 0,
                   ValueFromPipelineByPropertyName = $True)]
        [string[]]$ResourceGroupName,
        
        [Parameter(Mandatory = $True,
                   Position = 1,
                   ValueFromPipelineByPropertyName = $True)]
        [string[]]$VMName,
        
        [Parameter(Mandatory = $True,
                   Position = 2)]
        [scriptblock]$ScriptBlock, #todo: add file support.
        
        [Parameter(Mandatory = $True,
                   Position = 3)]
        [string]$StorageAccountName,

        [string]$StorageAccountKey, #Maybe don't use string...

        $StorageContext,
        
        [string]$StorageContainer = 'scripts',
        
        [string]$Filename, # Auto defined if not specified...
        
        [string]$ExtensionName, # Auto defined if not specified

        [switch]$ForceExtension,
        [switch]$ForceBlob,
        [switch]$Force
    )
    begin
    {
        if($Force)
        {
            $ForceExtension = $True
            $ForceBlob = $True
        }
    }
    process
    {
        Foreach($ResourceGroup in $ResourceGroupName)
        {
            Foreach($VM in $VMName)
            {
                if(-not $Filename)
                {
                    $GUID = [GUID]::NewGuid().Guid -replace "-", "_"
                    $FileName = "$GUID.ps1"
                }
                if(-not $ExtensionName)
                {
                    $ExtensionName = $Filename -replace '.ps1', ''
                }

                $CommonParams = @{
                    ResourceGroupName = $ResourceGroup
                    VMName = $VM
                }

                Write-Verbose "Working with ResourceGroup $ResourceGroup, VM $VM"
                # Why would Get-AzureRMVmCustomScriptExtension support listing extensions regardless of name? /grumble
                Try
                {
                    $AzureRmVM = Get-AzureRmVM @CommonParams -ErrorAction Stop
                    $AzureRmVMExtended = Get-AzureRmVM @CommonParams -Status -ErrorAction Stop
                }
                Catch
                {
                    Write-Error $_
                    Write-Error "Failed to retrieve existing extension data for $VM"
                    continue
                }

                # Handle existing extensions
                Write-Verbose "Checking for existing extensions on VM '$VM' in resource group '$ResourceGroup'"
                $Extensions = $null
                $Extensions = @( $AzureRmVMExtended.Extensions | Where {$_.Type -like 'Microsoft.Compute.CustomScriptExtension'} )
                if($Extensions.count -gt 0)
                {
                    Write-Verbose "Found extensions on $VM`:`n$($Extensions | Format-List | Out-String)"
                    if(-not $ForceExtension)
                    {
                        Write-Warning "Found CustomScriptExtension '$($Extensions.Name)' on VM '$VM' in Resource Group '$ResourceGroup'.`n Use -ForceExtension or -Force to remove this"
                        continue
                    }
                    Try
                    {
                        # Theoretically can only be one, so... no looping, just remove.
                        $Output = Remove-AzureRmVMCustomScriptExtension @CommonParams -Name $Extensions.Name -Force -ErrorAction Stop
                        if($Output.StatusCode -notlike 'OK')
                        {
                            Throw "Remove-AzureRmVMCustomScriptExtension output seems off:`n$($Output | Format-List | Out-String)"
                        }
                    }
                    Catch
                    {
                        Write-Error $_
                        Write-Error "Failed to remove existing extension $($Extensions.Name) for VM '$VM' in ResourceGroup '$ResourceGroup'"
                        continue
                    }
                }

                # Upload the script
                Write-Verbose "Uploading script to storage account $StorageAccountName"
                if(-not $StorageContainer)
                {
                    $StorageContainer = 'scripts'
                }
                if(-not $Filename)
                {
                    $Filename = 'CustomScriptExtension.ps1'
                }
                if(-not $StorageContext)
                {
                    if(-not $StorageAccountKey)
                    {
                        Try
                        {
                            $StorageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroup -Name $storageAccountName -ErrorAction Stop)[0].value
                        }
                        Catch
                        {
                            Write-Error $_
                            Write-Error "Failed to obtain Storage Account Key for storage account '$StorageAccountName' in Resource Group '$ResourceGroup' for VM '$VM'"
                            continue
                        }
                    }
                    Try
                    {
                        $StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
                    }
                    Catch
                    {
                        Write-Error $_
                        Write-Error "Failed to generate storage context for storage account '$StorageAccountName' in Resource Group '$ResourceGroup' for VM '$VM'"
                        continue
                    }
                }
        
                Try
                {
                    $Script = $ScriptBlock.ToString()
                    $LocalFile = [System.IO.Path]::GetTempFileName()
                    Start-Sleep -Milliseconds 500 #This might not be needed
                    Set-Content $LocalFile -Value $Script -ErrorAction Stop
            
                    $params = @{
                        Container = $StorageContainer
                        Context = $StorageContext
                    }

                    $Existing = $Null
                    $Existing = @( Get-AzureStorageBlob @params -ErrorAction Stop )

                    if($Existing.Name -contains $Filename -and -not $ForceBlob)
                    {
                        Write-Warning "Found blob '$FileName' in container '$StorageContainer'.`n Use -ForceBlob or -Force to overwrite this"
                        continue
                    }
                    $Output = Set-AzureStorageBlobContent @params -File $Localfile -Blob $Filename -ErrorAction Stop -Force
                    if($Output.Name -notlike $Filename)
                    {
                        Throw "Set-AzureStorageBlobContent output seems off:`n$($Output | Format-List | Out-String)"
                    }
                }
                Catch
                {
                    Write-Error $_
                    Write-Error "Failed to generate or upload local script for VM '$VM' in Resource Group '$ResourceGroup'"
                    continue
                }

                # We have a script in place, set up an extension!
                Write-Verbose "Adding CustomScriptExtension to VM '$VM' in resource group '$ResourceGroup'"
                Try
                {
                    $Output = Set-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroup `
                                                                 -VMName $VM `
                                                                 -Location $AzureRmVM.Location `
                                                                 -FileName $Filename `
                                                                 -ContainerName $StorageContainer `
                                                                 -StorageAccountName $StorageAccountName `
                                                                 -StorageAccountKey $StorageAccountKey `
                                                                 -Name $ExtensionName `
                                                                 -TypeHandlerVersion 1.1 `
                                                                 -ErrorAction Stop

                    if($Output.StatusCode -notlike 'OK')
                    {
                        Throw "Set-AzureRmVMCustomScriptExtension output seems off:`n$($Output | Format-List | Out-String)"
                    }
                }
                Catch
                {
                    Write-Error $_
                    Write-Error "Failed to set CustomScriptExtension for VM '$VM' in resource group $ResourceGroup"
                    continue
                }

                # collect the output!
                Try
                {
                    $AzureRmVmOutput = $null
                    $AzureRmVmOutput = Get-AzureRmVM @CommonParams -Status -ErrorAction Stop
                    $SubStatuses = ($AzureRmVmOutput.Extensions | Where {$_.name -like $ExtensionName} ).substatuses
                }
                Catch
                {
                    Write-Error $_
                    Write-Error "Failed to retrieve script output data for $VM"
                    continue
                }

                $Output = [ordered]@{
                    ResourceGroupName = $ResourceGroup
                    VMName = $VM
                    Substatuses = $SubStatuses
                }

                foreach($Substatus in $SubStatuses)
                {
                    $ThisCode = $Substatus.Code -replace 'ComponentStatus/', '' -replace '/', '_'
                    $Output.add($ThisCode, $Substatus.Message)
                }

                [pscustomobject]$Output
            }
        }
    }
}

# TODO:
    # Parameters could be nicer
    # Allow parallelization. Default unspecified Filename should be unique
    # Should we clean up script in Azure after running it?
    # Should we allow running an existing script?
    # Should we clean up the temp file?
    # Other stuff, this was a super quick implementation