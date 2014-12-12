function Import-PSCredential { 
    <#
    .SYNOPSIS
       Import credentials from a file

    .DESCRIPTION
       Export credentials to a file
       For use with Import-PSCredential
       A credential can only be decrypted by the user who encryped it, on the computer where the command was invoked.

    .PARAMETER Path
        Path to credential file

    .PARAMETER GlobalVariable
        If specified, store the imported credential in a global variable with this name

    .EXAMPLE
   
       #Creates a credential, saves it to disk
           $Credential = Get-Credential
           Export-PSCredential -path C:\File.xml -credential $Credential
    
        #Later on, import the credential!
            $ImportedCred = Import-PSCredential -path C:\File.xml

    .NOTES
        Author: 	Hal Rottenberg <hal@halr9000.com>, butchered by ramblingcookimonster
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
        [Alias("FullName")]
        [validatescript({
            Test-Path -Path $_
        })]
        [string]$Path = "credentials.$env:computername.xml",

        [string]$GlobalVariable
    )

	# Import credential file
	$import = Import-Clixml -Path $Path -ErrorAction Stop

	# Test for valid import
	if ( -not $import.UserName -or -not $import.EncryptedPassword ) {
		Throw "Input is not a valid ExportedPSCredential object."
	}

	# Build the new credential object
	$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $import.Username, $($import.EncryptedPassword | ConvertTo-SecureString)

	if ($OutVariable)
    {
		New-Variable -Name $GlobalVariable -scope Global -value $Credential -Force
	} 
    else
    {
		$Credential
	}
}