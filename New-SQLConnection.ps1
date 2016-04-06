function New-SqlConnection
{
    <#
    .SYNOPSIS
        Creates a SQLConnection to a MS SQL Server instance

    .DESCRIPTION
        Creates a SQLConnection to a MS SQL Server instance

    .PARAMETER ServerInstance
       SQL Instance to connect to. For default instances, only specify the computer name: "MyComputer". For named instances, use the format "ComputerName\InstanceName".

    .PARAMETER Database
        A character string specifying the name of a database.

    .PARAMETER Credential
        Specifies A PSCredential for SQL Server Authentication connection to an instance of the Database Engine.

        If -Credential is not specified, New-SQLConnection attempts a Windows Authentication connection using the Windows account running the PowerShell session.

        SECURITY NOTE: If you use the -Debug switch, the connectionstring including plain text password will be sent to the debug stream.

    .PARAMETER Encrypt
        If specified, will request that the connection to the SQL is done over SSL. This requires that the SQL Server has been set up to accept SSL requests. For information regarding setting up SSL on SQL Server, visit this link: https://technet.microsoft.com/en-us/library/ms189067(v=sql.105).aspx

    .PARAMETER ConnectionTimeout
        Specifies the number of seconds when New-SQLConnection times out if it cannot successfully connect to an instance of the Database Engine. The timeout value must be an integer between 0 and 65534. If 0 is specified, connection attempts do not time out.

    .OUTPUTS
        System.Data.SqlClient.SQLConnection

    .EXAMPLE
        $Connection = New-SqlConnection -ServerInstance c-is-hyperv-1
        Invoke-SqlCmd2 -SQLConnection $Connection -query $Query

    .LINK
        https://github.com/RamblingCookieMonster/PowerShell

    .FUNCTIONALITY
        SQL

    #>
    [cmdletbinding()]
    [OutputType([System.Data.SqlClient.SQLConnection])]
    param(
        [Parameter( Position=0,
                    Mandatory=$true,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    HelpMessage='SQL Server Instance required...' )]
        [Alias( 'Instance', 'Instances', 'ComputerName', 'Server', 'Servers' )]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $ServerInstance,

        [Parameter( Position=1,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false)]
        [string]
        $Database,

        [Parameter( Position=2,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter( Position=3,
                    Mandatory=$false,
                    ValueFromRemainingArguments=$false)]
        [switch]
        $Encrypt,

        [Parameter( Position=4,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Int32]
        $ConnectionTimeout=15,

        [Parameter( Position=5,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [bool]
        $Open = $True
    )
    Process
    {
        foreach($SQLInstance in $ServerInstance)
        {
            Write-Verbose "Querying ServerInstance '$SQLInstance'"

            if ($Credential)
            {
                $ConnectionString = "Server={0};Database={1};User ID={2};Password={3};Trusted_Connection=False;Connect Timeout={4};Encrypt={5}" -f $SQLInstance,$Database,$Credential.UserName,$Credential.GetNetworkCredential().Password,$ConnectionTimeout,$Encrypt
            }
            else
            {
                $ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2};Encrypt={3}" -f $SQLInstance,$Database,$ConnectionTimeout,$Encrypt
            }

            $conn = New-Object System.Data.SqlClient.SQLConnection
            $conn.ConnectionString = $ConnectionString
            Write-Debug "ConnectionString $ConnectionString"

            #Following EventHandler is used for PRINT and RAISERROR T-SQL statements. Executed when -Verbose parameter specified by caller
            if ($PSBoundParameters.Verbose)
            {
                $conn.FireInfoMessageEventOnUserErrors=$true
                $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] { Write-Verbose "$($_)" }
                $conn.add_InfoMessage($handler)
            }

            if($Open)
            {
                Try
                {
                    $conn.Open()
                }
                Catch
                {
                    Write-Error $_
                    continue
                }
            }

            write-Verbose "Created SQLConnection:`n$($Conn | Out-String)"

            $Conn
        }
    }
}