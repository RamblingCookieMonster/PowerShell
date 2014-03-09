function Get-InstalledSoftware {
<#
.SYNOPSIS
    Pull software details from registry on one or more computers

.DESCRIPTION
    Pull software details from registry on one or more computers.  Details:
        -This avoids the performance impact and potential danger of using the WMI Win32_Product class
        -The computer name, display name, publisher, version, uninstall string and install date are included in the results
        -Remote registry must be enabled on the computer(s) you query
        -This command must run with privileges to query the registry of the remote system(s)
        -Running this in a 32 bit PowerShell session on a 64 bit computer will limit your results to 32 bit software and result in double entries in the results

.PARAMETER ComputerName
    One or more computers to pull software list from.

.PARAMETER DisplayName
    If specified, return only software with DisplayNames that match this parameter (uses -match operator)

.PARAMETER Publisher
    If specified, return only software with Publishers that match this parameter (uses -match operator)

.EXAMPLE
    #Pull all software from c-is-ts-91, c-is-ts-92, format in a table
        Get-InstalledSoftware c-is-ts-91, c-is-ts-92 | Format-Table -AutoSize

.EXAMPLE
    #pull software with publisher matching microsoft and displayname matching lync from c-is-ts-91
        "c-is-ts-91" | Get-InstalledSoftware -DisplayName lync -Publisher microsoft | Format-Table -AutoSize

.LINK
    http://gallery.technet.microsoft.com/scriptcenter/Get-InstalledSoftware-Get-5607a465

.FUNCTIONALITY
    Computers
#>
    param (
        [Parameter(
            Position = 0,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true, 
            ValueFromRemainingArguments=$false
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('CN','__SERVER','Server','Computer')]
            [string[]]$ComputerName = $env:computername,
        
            [string]$DisplayName = $null,
        
            [string]$Publisher = $null
    )

    Begin
    {
        
        #define uninstall keys to cover 32 and 64 bit operating systems.
        #This will yeild only 32 bit software and double entries on 64 bit systems running 32 bit PowerShell
            $UninstallKeys = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
                "SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall"

    }

    Process
    {

        #Loop through each provided computer.  Provide a label for error handling to continue with the next computer.
        :computerLoop foreach($computer in $computername)
        {
            
            Try
            {
                #Attempt to connect to the localmachine hive of the specified computer
                $reg=[microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',$computer)
            }
            Catch
            {
                #Skip to the next computer if we can't talk to this one
                Write-Error "Error:  Could not open LocalMachine hive on $computer`: $_"
                Write-Verbose "Check Connectivity, permissions, and Remote Registry service for '$computer'"
                Continue
            }

            #Loop through the 32 bit and 64 bit registry keys
            foreach($uninstallKey in $UninstallKeys)
            {
            
                Try
                {
                    #Open the Uninstall key
                        $regkey = $null
                        $regkey = $reg.OpenSubKey($UninstallKey)

                    #If the reg key exists...
                    if($regkey)
                    {    
                                        
                        #Retrieve an array of strings containing all the subkey names
                            $subkeys = $regkey.GetSubKeyNames()

                        #Open each Subkey and use GetValue Method to return the required values for each
                            foreach($key in $subkeys)
                            {

                                #Build the full path to the key for this software
                                    $thisKey = $UninstallKey+"\\"+$key 
                            
                                #Open the subkey for this software
                                    $thisSubKey = $null
                                    $thisSubKey=$reg.OpenSubKey($thisKey)
                            
                                #If the subkey exists
                                if($thisSubKey){
                                    try
                                    {
                            
                                        #Get the display name.  If this is not empty we know there is information to show
                                            $dispName = $thisSubKey.GetValue("DisplayName")
                                
                                        #Get the publisher name ahead of time to allow filtering using Publisher parameter
                                            $pubName = $thisSubKey.GetValue("Publisher")

                                        #Collect subset of values from the key if there is a displayname
                                        #Filter by displayname and publisher if specified
                                        if( $dispName -and
                                            (-not $DisplayName -or $dispName -match $DisplayName ) -and
                                            (-not $Publisher -or $pubName -match $Publisher )
                                        )
                                        {

                                            #Display the output object, compatible with PowerShell 2
                                            New-Object PSObject -Property @{
                                                ComputerName = $computer
                                                DisplayName = $dispname
                                                Publisher = $pubName
                                                Version = $thisSubKey.GetValue("DisplayVersion")
                                                UninstallString = $thisSubKey.GetValue("UninstallString") 
                                                InstallDate = $thisSubKey.GetValue("InstallDate")
                                            } | select ComputerName, DisplayName, Publisher, Version, UninstallString, InstallDate
                                        }
                                    }
                                    Catch
                                    {
                                        #Error with one specific subkey, continue to the next
                                        Write-Error "Unknown error: $_"
                                        Continue
                                    }
                                }
                            }
                    }
                }
                Catch
                {

                    #Write verbose output if we couldn't open the uninstall key
                    Write-Verbose "Could not open key '$uninstallkey' on computer '$computer': $_"

                    #If we see an access denied message, let the user know and provide details, continue to the next computer
                    if($_ -match "Requested registry access is not allowed"){
                        Write-Error "Registry access to $computer denied.  Check your permissions.  Details: $_"
                        continue computerLoop
                    }
                    
                }
            }
        }
    }
}