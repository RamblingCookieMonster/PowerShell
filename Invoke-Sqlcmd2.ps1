function Invoke-Sqlcmd2 
{
    <# 
    .SYNOPSIS 
        Runs a T-SQL script. 

    .DESCRIPTION 
        Runs a T-SQL script. Invoke-Sqlcmd2 only returns message output, such as the output of PRINT statements when -verbose parameter is specified.
        Paramaterized queries are supported. 

        Help details below borrowed from Invoke-Sqlcmd

    .PARAMETER ServerInstance
        One or more ServerInstances to query. For default instances, only specify the computer name: "MyComputer". For named instances, use the format "ComputerName\InstanceName".

    .PARAMETER Database
        A character string specifying the name of a database. Invoke-Sqlcmd2 connects to this database in the instance that is specified in -ServerInstance.

    .PARAMETER Query
        Specifies one or more queries to be run. The queries can be Transact-SQL (? or XQuery statements, or sqlcmd commands. Multiple queries separated by a semicolon can be specified. Do not specify the sqlcmd GO separator. Escape any double quotation marks included in the string ?). Consider using bracketed identifiers such as [MyTable] instead of quoted identifiers such as "MyTable".

    .PARAMETER InputFile
        Specifies a file to be used as the query input to Invoke-Sqlcmd2. The file can contain Transact-SQL statements, (? XQuery statements, and sqlcmd commands and scripting variables ?). Specify the full path to the file.

    .PARAMETER Credential
        Specifies A PSCredential for SQL Server Authentication connection to an instance of the Database Engine.  If -Credential is not specified, Invoke-Sqlcmd attempts a Windows Authentication connection using the Windows account running the PowerShell session.
        SECURITY NOTE: If you use the -Debug switch, the connectionstring including plain text password will be sent to the debug stream.

    .PARAMETER Username
        Specifies the login ID for making a SQL Server Authentication connection to an instance of the Database Engine. The password must be specified using -Password. If -Username and -Password or -credential are not specified, Invoke-Sqlcmd attempts a Windows Authentication connection using the Windows account running the PowerShell session.
        When possible, use Windows Authentication.

    .PARAMETER Password
        Specifies the password for the SQL Server Authentication login ID that was specified in -Username. Passwords are case-sensitive. When possible, use Windows Authentication. Do not use a blank password, when possible use a strong password. For more information, see "Strong Password" in SQL Server Books Online.
        SECURITY NOTE: If you type -Password followed by your password, the password is visible to anyone who can see your monitor. If you code -Password followed by your password in a .ps1 script, anyone reading the script file will see your password. Assign the appropriate NTFS permissions to the file to prevent other users from being able to read the file.

    .PARAMETER QueryTimeout
        Specifies the number of seconds before the queries time out.

    .PARAMETER ConnectionTimeout
        Specifies the number of seconds when Invoke-Sqlcmd2 times out if it cannot successfully connect to an instance of the Database Engine. The timeout value must be an integer between 0 and 65534. If 0 is specified, connection attempts do not time out.

    .PARAMETER As
        Specifies output type - DataSet, DataTable, array of DataRow, PSObject or Single Value 

        PSObject output introduces overhead but adds flexibility for working with results: http://powershell.org/wp/forums/topic/dealing-with-dbnull/

    .PARAMETER AppendServerInstance
        If specified, append the server instance to PSObject and DataRow output

    .INPUTS 
        None 
            You cannot pipe objects to Invoke-Sqlcmd2 

    .OUTPUTS 
       System.Data.DataTable 

    .EXAMPLE 
        Invoke-Sqlcmd2 -ServerInstance "MyComputer\MyInstance" -Query "SELECT login_time AS 'StartTime' FROM sysprocesses WHERE spid = 1" 
    
        This example connects to a named instance of the Database Engine on a computer and runs a basic T-SQL query. 
        StartTime 
        ----------- 
        2010-08-12 21:21:03.593 

    .EXAMPLE 
        Invoke-Sqlcmd2 -ServerInstance "MyComputer\MyInstance" -InputFile "C:\MyFolder\tsqlscript.sql" | Out-File -filePath "C:\MyFolder\tsqlscript.rpt" 
    
        This example reads a file containing T-SQL statements, runs the file, and writes the output to another file. 

    .EXAMPLE 
        Invoke-Sqlcmd2  -ServerInstance "MyComputer\MyInstance" -Query "PRINT 'hello world'" -Verbose 

        This example uses the PowerShell -Verbose parameter to return the message output of the PRINT command. 
        VERBOSE: hello world 

    .EXAMPLE
        Invoke-Sqlcmd2 -ServerInstance MyServer\MyInstance -Query "SELECT ServerName, VCNumCPU FROM tblServerInfo" -as PSObject | ?{$_.VCNumCPU -gt 8}
        Invoke-Sqlcmd2 -ServerInstance MyServer\MyInstance -Query "SELECT ServerName, VCNumCPU FROM tblServerInfo" -as PSObject | ?{$_.VCNumCPU}

        This example uses the PSObject output type to allow more flexibility when working with results.  Using a datarow would result in errors for the first example, and would include rows where VCNumCPU has DBNull value.

    .EXAMPLE
        'Instance1', 'Server1/Instance1', 'Server2' | Invoke-Sqlcmd2 -query "Sp_databases" -as psobject -AppendServerInstance

        This example lists databases for each instance.  It includes a column for the ServerInstance in question.
            DATABASE_NAME          DATABASE_SIZE REMARKS        ServerInstance                                                     
            -------------          ------------- -------        --------------                                                     
            REDACTED                       88320                Instance1                                                      
            master                         17920                Instance1                                                      
            msdb                          161472                Instance1                                                      
            REDACTED                      158720                Instance1                                                      
            tempdb                          8704                Instance1                                                      
            REDACTED                       92416                Server1/Instance1                                                        
            master                          7744                Server1/Instance1                                                        
            msdb                          618112                Server1/Instance1                                                        
            REDACTED                    10004608                Server1/Instance1                                                        
            REDACTED                      153600                Server1/Instance1                                                        
            tempdb                        563200                Server1/Instance1                                                        
            master                          5120                Server2                                                            
            msdb                          215552                Server2                                                            
            OperationsManager           20480000                Server2                                                            
            tempdb                          8704                Server2  

    .NOTES 
        Version History 
        poshcode.org - http://poshcode.org/4967
        v1.0         - Chad Miller - Initial release 
        v1.1         - Chad Miller - Fixed Issue with connection closing 
        v1.2         - Chad Miller - Added inputfile, SQL auth support, connectiontimeout and output message handling. Updated help documentation 
        v1.3         - Chad Miller - Added As parameter to control DataSet, DataTable or array of DataRow Output type 
        v1.4         - Justin Dearing <zippy1981 _at_ gmail.com> - Added the ability to pass parameters to the query.
        v1.4.1       - Paul Bryson <atamido _at_ gmail.com> - Added fix to check for null values in parameterized queries and replace with [DBNull]
        v1.5         - Joel Bennett - add SingleValue output option
        v1.5.1       - RamblingCookieMonster - Added ParameterSets, set Query and InputFile to mandatory
        v1.5.2       - RamblingCookieMonster - Added DBNullToNull switch and code from Dave Wyatt. Added parameters to comment based help (need someone with SQL expertise to verify these)
                 
        github.com   - https://github.com/RamblingCookieMonster/PowerShell
        v1.5.3       - RamblingCookieMonster - Replaced DBNullToNull param with PSObject Output option. Added credential support. Added pipeline support for ServerInstance.  Added to GitHub
                       RamblingCookieMonster - Added AppendServerInstance switch.

    .LINK
        https://github.com/RamblingCookieMonster/PowerShell
    #>

    [CmdletBinding(
        DefaultParameterSetName='Query'
    )]

    param(
        [Parameter( Position=0,
                    Mandatory=$true,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true
        )]
        [string[]]$ServerInstance,

        [Parameter( Position=1, Mandatory=$false)]
        [string]$Database,
    
        [Parameter( Position=2,
                    Mandatory=$true,
                    ParameterSetName="Query")]
        [string]$Query,
    
        [Parameter( Position=2,
                    Mandatory=$true,
                    ParameterSetName="File")]
        [ValidateScript({test-path $_})]
        [string]$InputFile,
        
        [Parameter( ParameterSetName="File")]
        [Parameter( ParameterSetName="Query")]
        [Parameter( ParameterSetName="Credential")]
        [Parameter( Position=3, Mandatory=$false )]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter( ParameterSetName="File")]
        [Parameter( ParameterSetName="Query")]
        [Parameter( ParameterSetName="Plaintext")]
        [Parameter(Position=3, Mandatory=$false)]
        [string]$Username,

        [Parameter( ParameterSetName="File")]
        [Parameter( ParameterSetName="Query")]
        [Parameter( ParameterSetName="Plaintext")]
        [Parameter(Position=4, Mandatory=$false)]
        [string]$Password,

        [Parameter(Position=5, Mandatory=$false)]
        [Int32]$QueryTimeout=600,
    
        [Parameter(Position=6, Mandatory=$false)]
        [Int32]$ConnectionTimeout=15,
    
        [Parameter(Position=7, Mandatory=$false)]
        [ValidateSet("DataSet", "DataTable", "DataRow","PSObject","SingleValue")]
        [string]$As="DataRow",
    
        [Parameter(Position=8, Mandatory=$false)]
        [System.Collections.IDictionary]$SqlParameters,

        [switch]$AppendServerInstance
    ) 

    Begin
    {
        if ($InputFile) 
        { 
            $filePath = $(Resolve-Path $InputFile).path 
            $Query =  [System.IO.File]::ReadAllText("$filePath") 
        }

        Write-Verbose "Running Invoke-Sqlcmd2 with ParameterSet $($PSCmdlet.ParameterSetName).  Performing query '$Query'"

        If($As -eq "PSObject")
        {
            #This code scrubs DBNulls.  Props to Dave Wyatt
            $cSharp = @'
                using System;
                using System.Data;
                using System.Management.Automation;

                public class DBNullScrubber
                {
                    public static PSObject DataRowToPSObject(DataRow row)
                    {
                        PSObject psObject = new PSObject();

                        if (row != null && (row.RowState & DataRowState.Detached) != DataRowState.Detached)
                        {
                            foreach (DataColumn column in row.Table.Columns)
                            {
                                Object value = null;
                                if (!row.IsNull(column))
                                {
                                    value = row[column];
                                }

                                psObject.Properties.Add(new PSNoteProperty(column.ColumnName, value));
                            }
                        }

                        return psObject;
                    }
                }
'@

            Try
            {
                Add-Type -TypeDefinition $cSharp -ReferencedAssemblies 'System.Data','System.Xml' -ErrorAction stop
            }
            Catch
            {
                If(-not $_.ToString() -like "*The type name 'DBNullScrubber' already exists*")
                {
                    Write-Warning "Could not load DBNullScrubber.  Defaulting to DataRow output: $_"
                    $As = "Datarow"
                }
            }
        }

        $conn = New-Object System.Data.SqlClient.SQLConnection
    }
    Process
    {
        foreach($SQLInstance in $ServerInstance)
        {
            Write-Verbose "Querying ServerInstance '$SQLInstance'"

            if ($Credential) 
            {
                $ConnectionString = "Server={0};Database={1};User ID={2};Password={3};Trusted_Connection=False;Connect Timeout={4}" -f $SQLInstance,$Database,$Credential.UserName,$Credential.GetNetworkCredential().Password,$ConnectionTimeout
            }
            elseif ($Username)
            {
                $ConnectionString = "Server={0};Database={1};User ID={2};Password={3};Trusted_Connection=False;Connect Timeout={4}" -f $SQLInstance,$Database,$Username,$Password,$ConnectionTimeout 
            }
            else 
            {
                $ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f $SQLInstance,$Database,$ConnectionTimeout
            } 
            $conn.ConnectionString = $ConnectionString 
     
            Write-Debug "ConnectionString $ConnectionString"

            #Following EventHandler is used for PRINT and RAISERROR T-SQL statements. Executed when -Verbose parameter specified by caller 
            if ($PSBoundParameters.Verbose) 
            { 
                $conn.FireInfoMessageEventOnUserErrors=$true 
                $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] { Write-Verbose "$($_)" } 
                $conn.add_InfoMessage($handler) 
            } 
    
            Try
            {
                $conn.Open() 
            }
            Catch
            {
                Write-Error $_
                continue
            }

            $cmd = New-Object system.Data.SqlClient.SqlCommand($Query,$conn) 
            $cmd.CommandTimeout=$QueryTimeout

            if ($SqlParameters -ne $null)
            {
                $SqlParameters.GetEnumerator() |
                    ForEach-Object {
                        If ($_.Value -ne $null)
                        { $cmd.Parameters.AddWithValue($_.Key, $_.Value) }
                        Else
                        { $cmd.Parameters.AddWithValue($_.Key, [DBNull]::Value) }
                    } > $null
            }
    
            $ds = New-Object system.Data.DataSet 
            $da = New-Object system.Data.SqlClient.SqlDataAdapter($cmd) 
    
            [void]$da.fill($ds) 
            $conn.Close() 

            if($AppendServerInstance)
            {
                #Basics from Chad Miller
                $Column =  new-object Data.DataColumn
                $Column.ColumnName = "ServerInstance"
                $ds.Tables[0].Columns.Add($Column)
                Foreach($row in $ds.Tables[0])
                {
                    $row.ServerInstance = $SQLInstance
                }
            }

            switch ($As) 
            { 
                'DataSet' 
                {
                    $ds
                } 
                'DataTable'
                {
                    $ds.Tables
                } 
                'DataRow'
                {
                    $ds.Tables[0]
                }
                'PSObject'
                {
                    #Scrub DBNulls - Provides convenient results you can use comparisons with
                    #Introduces overhead (e.g. ~2000 rows w/ ~80 columns went from .15 Seconds to .65 Seconds - depending on your data could be much more!)
                    foreach ($row in $ds.Tables[0].Rows)
                    {
                        [DBNullScrubber]::DataRowToPSObject($row)
                    }
                }
                'SingleValue'
                {
                    $ds.Tables[0] | Select-Object -Expand $ds.Tables[0].Columns[0].ColumnName
                }
            }
        }
    }
} #Invoke-Sqlcmd2