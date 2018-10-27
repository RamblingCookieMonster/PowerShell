function ConvertFrom-SID {
<#
.SYNOPSIS
    Convert SID to user or computer account name
.DESCRIPTION
    Convert SID to user or computer account name
.PARAMETER SID
    One or more SIDs to convert
.EXAMPLE
    ConvertFrom-SID S-1-5-21-2139171146-395215898-1246945465-2359
.EXAMPLE 
    'S-1-5-32-580' | ConvertFrom-SID
.FUNCTIONALITY
    Active Directory
.NOTES
    SID conversion for well known SIDs from http://support.microsoft.com/kb/243330
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
            [string[]]$sid
    )

    Begin{

        #well known SID to name map
        $wellKnownSIDs = @{
            'S-1-0' = 'Null Authority'
            'S-1-0-0' = 'Nobody'
            'S-1-1' = 'World Authority'
            'S-1-1-0' = 'Everyone'
            'S-1-2' = 'Local Authority'
            'S-1-2-0' = 'Local'
            'S-1-2-1' = 'Console Logon'
            'S-1-3' = 'Creator Authority'
            'S-1-3-0' = 'Creator Owner'
            'S-1-3-1' = 'Creator Group'
            'S-1-3-2' = 'Creator Owner Server'
            'S-1-3-3' = 'Creator Group Server'
            'S-1-3-4' = 'Owner Rights'
            'S-1-5-80-0' = 'All Services'
            'S-1-4' = 'Non-unique Authority'
            'S-1-5' = 'NT Authority'
            'S-1-5-1' = 'Dialup'
            'S-1-5-2' = 'Network'
            'S-1-5-3' = 'Batch'
            'S-1-5-4' = 'Interactive'
            'S-1-5-6' = 'Service'
            'S-1-5-7' = 'Anonymous'
            'S-1-5-8' = 'Proxy'
            'S-1-5-9' = 'Enterprise Domain Controllers'
            'S-1-5-10' = 'Principal Self'
            'S-1-5-11' = 'Authenticated Users'
            'S-1-5-12' = 'Restricted Code'
            'S-1-5-13' = 'Terminal Server Users'
            'S-1-5-14' = 'Remote Interactive Logon'
            'S-1-5-15' = 'This Organization'
            'S-1-5-17' = 'This Organization'
            'S-1-5-18' = 'Local System'
            'S-1-5-19' = 'NT Authority'
            'S-1-5-20' = 'NT Authority'
            'S-1-5-21-500' = 'Administrator'
            'S-1-5-21-501' = 'Guest'
            'S-1-5-21-502' = 'KRBTGT'
            'S-1-5-21-512' = 'Domain Admins'
            'S-1-5-21-513' = 'Domain Users'
            'S-1-5-21-514' = 'Domain Guests'
            'S-1-5-21-515' = 'Domain Computers'
            'S-1-5-21-516' = 'Domain Controllers'
            'S-1-5-21-517' = 'Cert Publishers'            
            'S-1-5-21-518' = 'Schema Admins'
            'S-1-5-21-519' = 'Enterprise Admins'
            'S-1-5-21-520' = 'Group Policy Creator Owners'
            'S-1-5-21-522' = 'Cloneable Domain Controllers'
            'S-1-5-21-526' = 'Key Admins'
            'S-1-5-21-527' = 'Enterprise Key Admins'
            'S-1-5-21-553' = 'RAS and IAS Servers'
            'S-1-5-21-571' = 'Allowed RODC Password Replication Group'
            'S-1-5-21-572' = 'Denied RODC Password Replication Group'
            'S-1-5-32-544' = 'Administrators'
            'S-1-5-32-545' = 'Users'
            'S-1-5-32-546' = 'Guests'
            'S-1-5-32-547' = 'Power Users'
            'S-1-5-32-548' = 'Account Operators'
            'S-1-5-32-549' = 'Server Operators'
            'S-1-5-32-550' = 'Print Operators'
            'S-1-5-32-551' = 'Backup Operators'
            'S-1-5-32-552' = 'Replicators'
            'S-1-5-64-10' = 'NTLM Authentication'
            'S-1-5-64-14' = 'SChannel Authentication'
            'S-1-5-64-21' = 'Digest Authority'
            'S-1-5-80' = 'NT Service'
            'S-1-5-83-0' = 'NT VIRTUAL MACHINE\Virtual Machines'
            'S-1-16-0' = 'Untrusted Mandatory Level'
            'S-1-16-4096' = 'Low Mandatory Level'
            'S-1-16-8192' = 'Medium Mandatory Level'
            'S-1-16-8448' = 'Medium Plus Mandatory Level'
            'S-1-16-12288' = 'High Mandatory Level'
            'S-1-16-16384' = 'System Mandatory Level'
            'S-1-16-20480' = 'Protected Process Mandatory Level'
            'S-1-16-28672' = 'Secure Process Mandatory Level'
            'S-1-5-32-554' = 'BUILTIN\Pre-Windows 2000 Compatible Access'
            'S-1-5-32-555' = 'BUILTIN\Remote Desktop Users'
            'S-1-5-32-556' = 'BUILTIN\Network Configuration Operators'
            'S-1-5-32-557' = 'BUILTIN\Incoming Forest Trust Builders'
            'S-1-5-32-558' = 'BUILTIN\Performance Monitor Users'
            'S-1-5-32-559' = 'BUILTIN\Performance Log Users'
            'S-1-5-32-560' = 'BUILTIN\Windows Authorization Access Group'
            'S-1-5-32-561' = 'BUILTIN\Terminal Server License Servers'
            'S-1-5-32-562' = 'BUILTIN\Distributed COM Users'
            'S-1-5-32-569' = 'BUILTIN\Cryptographic Operators'
            'S-1-5-32-573' = 'BUILTIN\Event Log Readers'
            'S-1-5-32-574' = 'BUILTIN\Certificate Service DCOM Access'
            'S-1-5-32-575' = 'BUILTIN\RDS Remote Access Servers'
            'S-1-5-32-576' = 'BUILTIN\RDS Endpoint Servers'
            'S-1-5-32-577' = 'BUILTIN\RDS Management Servers'
            'S-1-5-32-578' = 'BUILTIN\Hyper-V Administrators'
            'S-1-5-32-579' = 'BUILTIN\Access Control Assistance Operators'
            'S-1-5-32-580' = 'BUILTIN\Remote Management Users'
        }
    }

    Process {

        #loop through provided SIDs
        foreach($id in $sid){
            $fullsid = $id
            #Check for domain contextual SID's
            try {
                $IsDomain = $false
                if($id.Remove(8) -eq "S-1-5-21"){
                    $IsDomain = $true
                    $suffix = $id.Substring($id.Length - 4)
                    $id = $id.Remove(8) + $suffix
                }
            }
            catch {
                # String size issues
            }

            #Map name to well known sid.  If this fails, use .net to get the account
            if($name = $wellKnownSIDs[$id]){ }
            else{
                if($IsDomain){
                    $id = $fullsid
                }
                #Try to translate the SID to an account
                Try{
                    $objSID = New-Object System.Security.Principal.SecurityIdentifier($id)
                    $name = ( $objSID.Translate([System.Security.Principal.NTAccount]) ).Value
                }
                Catch{
                    $name = "Not a valid SID or could not be identified"
                    Write-Verbose "$id is not a valid SID or could not be identified"
                }
            }

            #Display the results
            New-Object -TypeName PSObject -Property @{
                SID = $fullsid
                Name = $name
            } | Select-Object SID, Name

        }
    }
}
