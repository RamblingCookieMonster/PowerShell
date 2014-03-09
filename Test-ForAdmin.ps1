function Test-ForAdmin {
<#
.SYNOPSIS
    Test whether a specified user is in the administrator role

.DESCRIPTION
    Test whether a specified user is in the administrator role

    Note:  Requires .NET 3.5 or later

.PARAMETER username
    One or more usernames to test.  Defaults to the current PowerShell user ($env:username)

.EXAMPLE
    If(Test-ForAdmin){
        "The current user is running with the administrator role"
    }
    Else{
        "The current user is not running with the administrator role"
    }

.EXAMPLE
    #Test whether JohnDoe is an admin on this computer
    Test-ForAdmin -username JohnDoe

.FUNCTIONALITY
    Computers

#>
    [cmdletbinding()]
    param(
        [Parameter( 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true, 
            ValueFromRemainingArguments=$false, 
            Position=0
        )][string[]]$username =$env:username

    )
    
    Process{
    
        foreach($user in $username){

            #If username matches, don't query AD
            if($user -eq $env:username){
                write-verbose "Username parameter value matches username environment variable:  Don't check AD"
        
                $wid = [System.Security.Principal.WindowsIdentity]::GetCurrent()
                $prp = New-Object System.Security.Principal.WindowsPrincipal($wid)
                $adm = [System.Security.Principal.WindowsBuiltInRole]::Administrator
                $prp.IsInRole($adm)
            }

            else{
                #At this point, the username is not $env:username.  Work with AD.
                Write-Verbose "Username parameter value does not match username environment variable:  Check AD"

                #Add the .net type
                    $type = 'System.DirectoryServices.AccountManagement'
                    Try{
                        Add-Type -AssemblyName $type -ErrorAction Stop
                    }
                    Catch {
                        Throw "Could not load $type`: Confirm .NET 3.5 or later is installed"
                        Break
                    }

                #Look up user to get UPN
                    Try{
                        $ct = [System.DirectoryServices.AccountManagement.ContextType]::Domain
                        $upn = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($ct,$user) | select -ExpandProperty UserPrincipalName
                    }
                    Catch{
                        Throw "Could not find user '$user': $_"
                    }

                #Build WindowsIdentity with UPN
                    $wid = New-Object System.Security.Principal.WindowsIdentity($upn)

                #Verify whether the account is an admin on the local machine
                    $prp = New-Object System.Security.Principal.WindowsPrincipal($wid)
                    $adm = [System.Security.Principal.WindowsBuiltInRole]::Administrator
                    $prp.IsInRole($adm)
            }
        }
    }
}