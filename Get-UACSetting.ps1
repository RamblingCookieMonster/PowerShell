function Get-UACSetting {
<#
.SYNOPSIS
    Get UAC settings

.DESCRIPTION
    Get UAC settings

    For each computer specified, extract UAC settings from registry.
    For each registry value, include the value, existing data, default, and boolean for whether existing isDefault
    If specified, revert the value data to default
    
    Note:  you can change the defaults and thus specify a new 'default'

.PARAMETER computername
    Computer(s) to test

.PARAMETER RevertToDefault
    Reverts UAC settings to the default values
    Note:  you can change the defaults and thus specify a new 'default'

    Default values and further details on them can be found on Technet:
    http://technet.microsoft.com/en-us/library/dd835564(v=ws.10).aspx

.PARAMETER FilterAdministratorTokenD

    Default value used to produce 'isDefault' property and to determine new value when revertToDefault parameter is specified

.PARAMETER EnableUIADesktopToggleD

    Default value used to produce 'isDefault' property and to determine new value when revertToDefault parameter is specified

.PARAMETER ConsentPromptBehaviorAdminD

    Default value used to produce 'isDefault' property and to determine new value when revertToDefault parameter is specified

.PARAMETER ConsentPromptBehaviorUserD

    Default value used to produce 'isDefault' property and to determine new value when revertToDefault parameter is specified

.PARAMETER EnableInstallerDetectionD

    Default value used to produce 'isDefault' property and to determine new value when revertToDefault parameter is specified

.PARAMETER ValidateAdminCodeSignaturesD

    Default value used to produce 'isDefault' property and to determine new value when revertToDefault parameter is specified

.PARAMETER EnableSecureUIAPathsD

    Default value used to produce 'isDefault' property and to determine new value when revertToDefault parameter is specified

.PARAMETER EnableLUAD

    Default value used to produce 'isDefault' property and to determine new value when revertToDefault parameter is specified

.PARAMETER PromptOnSecureDesktopD

    Default value used to produce 'isDefault' property and to determine new value when revertToDefault parameter is specified

.PARAMETER EnableVirtualizationD

    Default value used to produce 'isDefault' property and to determine new value when revertToDefault parameter is specified

.EXAMPLE
    Get-UACSetting -computername computer1, computer2 | format-table -autosize

    #Return all UAC settings from computer1 and computer2.

.EXAMPLE
    Get-UACSetting -computername computer1 -reverttodefault
    
    #Reverts UAC settings on computer1 to default
    
 .EXAMPLE
    'computer1', 'computer2' | Get-UACSetting | ?{$_.isdefault -eq 0}

    #Return non-default UAC settings for computer1 and computer2

.FUNCTIONALITY
    Computers

.NOTES
    Links on UAC:
        Default values and further details on them can be found on Technet:
            http://technet.microsoft.com/en-us/library/dd835564(v=ws.10).aspx
        Inside Windows 7 User Account Control
            http://technet.microsoft.com/en-us/magazine/2009.07.uac.aspx
        Inside Windows Vista User Account Controls
            http://technet.microsoft.com/en-us/magazine/2007.06.uac.aspx
        Engineering Windows 7 – UAC  Post 1 through 4
            http://blogs.msdn.com/e7/archive/2008/10/08/user-account-control.aspx
            http://blogs.msdn.com/b/e7/archive/2009/01/15/user-account-control-uac-quick-update.aspx
            http://blogs.msdn.com/b/e7/archive/2009/02/05/update-on-uac.aspx
            http://blogs.msdn.com/b/e7/archive/2009/02/05/uac-feedback-and-follow-up.aspx
        User Account Control Technical Reference
            http://technet.microsoft.com/en-us/library/dd835546%28v=ws.10%29.aspx
#>
[CmdletBinding()]
    param(
        [Parameter( 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true, 
            ValueFromRemainingArguments=$false, 
            Position=0
        )][string[]]$ComputerName = $env:COMPUTERNAME,
        [switch]$RevertToDefault,
        [validaterange(0,1)][int]$FilterAdministratorTokenD = 0,
        [validaterange(0,1)][int]$EnableUIADesktopToggleD = 0,
        [validaterange(0,5)][int]$ConsentPromptBehaviorAdminD = 5,
        [validaterange(0,3)][int]$ConsentPromptBehaviorUserD = 3,
        [validaterange(0,1)][int]$EnableInstallerDetectionD = 1,
        [validaterange(0,1)][int]$ValidateAdminCodeSignaturesD = 0,
        [validaterange(0,1)][int]$EnableSecureUIAPathsD = 1,
        [validaterange(0,1)][int]$EnableLUAD = 1,
        [validaterange(0,1)][int]$PromptOnSecureDesktopD = 1,
        [validaterange(0,1)][int]$EnableVirtualizationD = 1
    )
    Begin {

        function quote-list {$args}

        #Define key for UAC values
        $key = "Software\Microsoft\Windows\CurrentVersion\Policies\System"
    
        #Define UAC Values
        $values = quote-list FilterAdministratorToken EnableUIADesktopToggle ConsentPromptBehaviorAdmin 
        $values += quote-list ConsentPromptBehaviorUser EnableInstallerDetection ValidateAdminCodeSignatures
        $values += quote-list EnableSecureUIAPaths EnableLUA PromptOnSecureDesktop EnableVirtualization

    }
    Process{
        #loop through computers
        foreach($computer in $ComputerName){

            #test the connection
            if(Test-connection $computer -quiet -count 2 -buffersize 16){

                #init results array
                $results = @()

                try{
                    #open the registry key on remote computer
                    $OpenRegistry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$computer)
    
                    #for each value, add value and data pair to a custom object
                    foreach($value in $values) {
        
                        #get the value
                        $subkey = $OpenRegistry.OpenSubKey($key,$true)
                        $data = $subkey.GetValue($value)
                        New-Variable -Name "$value" -Value $data -force
        
                        #Set default value or overridden default value
                        $dataD = (Get-Variable -Name "$value`D").value

                        #create object and set properties
                        $obj = "" | select ComputerName, Value, existingData, defaultData, isDefault
                        $obj.ComputerName = $computer
                        $obj.Value = "$value"
                        $obj.existingData = "$data"
                        $obj.defaultData = "$dataD"
                        $obj.isDefault = 1
        
                        #If data does not match default...
                        if($data -ne $dataD){
            
                            #indicate not default
                            $obj.isDefault = 0

                            #revert to default and set modified and newdata properties
                            if($RevertToDefault){
                                $Subkey.SetValue("$value",$dataD)
                                $obj | Add-Member -MemberType NoteProperty -name newData -Value $dataD -Force
                            }
                        }

                        #add to results array
                        $results += $obj
                    }
        
                    #define properties to return
                    $properties = quote-list ComputerName Value existingData defaultData
    
                    if($RevertToDefault){
                        #If we set revert to default, show newData property
                        $properties += "newData"    
                    } 
                    else{
                        #if we didn't call for revert to default, add the isdefault property
                        $properties += "isDefault"
                    }

                    #output the results
                    $results | select -Property $properties
                }
                Catch{
                    Write-Error "Error pulling UAC settings from $computer"
                }
            }
        }
    }
}