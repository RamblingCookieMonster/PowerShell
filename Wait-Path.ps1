Function Wait-Path {
    <#
    .SYNOPSIS
        Wait for a path to exist

    .DESCRIPTION
        Wait for a path to exist

        Default behavior will throw an error if we time out waiting for the path
        Passthru behavior will return true or false
        Behaviors above apply to the set of paths; unless all paths test successfully, we error out or return false

    .PARAMETER Path
        Path(s) to test
    
        Note
            Each path is independently verified with Test-Path.
            This means you can pass in paths from other providers.

    .PARAMETER Timeout
        Time to wait before timing out, in seconds

    .PARAMETER Interval
        Time to wait between each test, in seconds

    .PARAMETER Passthru
        When specified, return true if we see all specified paths, otherwise return false

        Note:
            If this is specified and we time out, we return false.
            If this is not specified and we time out, we throw an error.

    .EXAMPLE
        Wait-Path \\Path\To\Share -Timeout 30

        # Wait for \\Path\To\Share to exist, test every 1 second (default), time out at 30 seconds.

    .EXAMPLE
        $TempFile = [System.IO.Path]::GetTempFileName()
    
        if ( Wait-Path -Path $TempFile -Interval .5 -passthru )
        {
            Set-Content -Path $TempFile -Value "Test!"
        }
        else
        {
            Throw "Could not find $TempFile"
        }

        # Create a temp file, wait until we can see that file, testing every .5 seconds, write data to it.

    .EXAMPLE
        Wait-Path C:\Test, HKLM:\System

        # Wait until C:\Test and HKLM:\System exist

    .FUNCTIONALITY
        PowerShell Language

    #>
    [cmdletbinding()]
    param (
        [string[]]$Path,
        [int]$Timeout = 5,
        [int]$Interval = 1,
        [switch]$Passthru
    )

    $StartDate = Get-Date
    $First = $True

    Do
    {
        #Only sleep if this isn't the first run
            if($First -eq $True)
            {
                $First = $False
            }
            else
            {
                Start-Sleep -Seconds $Interval
            }

        #Test paths and collect output
            [bool[]]$Tests = foreach($PathItem in $Path)
            {
                Try
                {
                    if(Test-Path $PathItem -ErrorAction stop)
                    {
                        Write-Verbose "'$PathItem' exists"
                        $True
                    }
                    else
                    {
                        Write-Verbose "Waiting for '$PathItem'"
                        $False
                    }
                }
                Catch
                {
                    Write-Error "Error testing path '$PathItem': $_"
                    $False
                }
            }

        # Identify whether we can see everything
            $Return = $Tests -notcontains $False -and $Tests -contains $True
        
        # Poor logic, but we break the Until here
            # Did we time out?
            # Error if we are not passing through
            if ( ((Get-Date) - $StartDate).TotalSeconds -gt $Timeout)
            {
                if( $Passthru )
                {
                    $False
                    break
                }
                else
                {
                    Throw "Timed out waiting for paths $($Path -join ", ")"
                }
            }
            elseif($Return)
            {
                if( $Passthru )
                {
                    $True
                }
                break
            }
    }
    Until( $False ) # We break out above

}