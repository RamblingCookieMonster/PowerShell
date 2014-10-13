function New-IPRange {
<#
.SYNOPSIS
    Returns an array of IP Addresses based on a start and end address

.DESCRIPTION
    Returns an array of IP Addresses based on a start and end address

.PARAMETER Start
    Starting IP Address

.PARAMETER End
    Ending IP Address

.PARAMETER Exclude
    Exclude addresses with this final octet

    Default excludes 0, 1, and 255

    e.g. 5 excludes *.*.*.5

.EXAMPLE
    New-IPRange -Start 192.168.1.5 -End 192.168.20.254

    Create an array from 192.168.1.5 to 192.168.20.254, excluding *.*.*.[0,1,255] (default exclusion)

.NOTES
    Source: Dr. Tobias Weltner, http://powershell.com/cs/media/p/9437.aspx

.FUNCTIONALITY
    Network
#>
[cmdletbinding()]
param (
    [parameter( Mandatory = $true,
                Position = 0 )]
    [System.Net.IPAddress]$Start,

    [parameter( Mandatory = $true,
                Position = 1)]
    [System.Net.IPAddress]$End,

    [int[]]$Exclude = @( 0, 1, 255 )
)
    
    #Provide verbose output.  Some oddities behind casting certain strings to IP.
    #Example: [ipaddress]"192.168.20500"
    Write-Verbose "Parsed Start as '$Start', End as '$End'"
    
    $ip1 = $start.GetAddressBytes()
    [Array]::Reverse($ip1)
    $ip1 = ([System.Net.IPAddress]($ip1 -join '.')).Address

    $ip2 = ($end).GetAddressBytes()
    [Array]::Reverse($ip2)
    $ip2 = ([System.Net.IPAddress]($ip2 -join '.')).Address

    for ($x=$ip1; $x -le $ip2; $x++)
    {
        $ip = ([System.Net.IPAddress]$x).GetAddressBytes()
        [Array]::Reverse($ip)
        if($Exclude -notcontains $ip[3])
        {
            $ip -join '.'
        }
    }
}