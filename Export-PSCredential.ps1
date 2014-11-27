function Export-PSCredential { 
    <#
    .SYNOPSIS
       Export credentials to a file

    .DESCRIPTION
       Export credentials to a file
       For use with Import-PSCredential
       A credential can only be decrypted by the user who encryped it, on the computer where the command was invoked.

    .PARAMETER Credential
        Credential to export

    .PARAMETER Path
        File to export to.  Parent folder must exist

    .PARAMETER Passthru
        Return FileInfo object for the credential file

    .EXAMPLE
   
       #Creates a credential, saves it to disk
           $Credential = Get-Credential
           Export-PSCredential -path C:\File.xml -credential $Credential
    
        #Later on, import the credential!
            $ImportedCred = Import-PSCredential -path C:\File.xml

    .NOTES
        Author: 	Hal Rottenberg <hal@halr9000.com>, butchered by ramblingcookiemonster
        Purpose:	These functions allow one to easily save network credentials to disk in a relatively
			        secure manner.  The resulting on-disk credential file can only [1] be decrypted
			        by the same user account which performed the encryption.  For more details, see
			        the help files for ConvertFrom-SecureString and ConvertTo-SecureString as well as
			        MSDN pages about Windows Data Protection API.
			        [1]: So far as I know today.  Next week I'm sure a script kiddie will break it.

    .FUNCTIONALITY
        General Command
    #>
    [cmdletbinding()]
	param (
        [parameter(Mandatory=$true)]
        [pscredential]$Credential = (Get-Credential),
        
        [parameter()]
        [Alias("FullName")]
        [validatescript({
            Test-Path -Path (Split-Path -Path $_ -Parent)
        })]
        [string]$Path = "credentials.$env:COMPUTERNAME.xml",

        [switch]$Passthru
    )
	
	# Create temporary object to be serialized to disk
	$export = New-Object -TypeName PSObject -Property @{
        UserName = $Credential.Username
        EncryptedPassword = $Credential.Password | ConvertFrom-SecureString
    }
	
	# Export using the Export-Clixml cmdlet
	Try
    {
        $export | Export-Clixml -Path $Path -ErrorAction Stop
        Write-Verbose "Saved credentials for $($export.Username) to $Path"

	    if($Passthru)
        {
            # Return FileInfo object referring to saved credentials
	        Get-Item $Path -ErrorAction Stop
        }
    }
    Catch
    {
	    Write-Error "Error saving credentials to '$Path': $_"
    }
}