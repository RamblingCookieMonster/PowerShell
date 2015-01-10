Function Get-SQLInstance {  
    <#
        .SYNOPSIS
            Retrieves SQL server information from a local or remote servers.

        .DESCRIPTION
            Retrieves SQL server information from a local or remote servers. Pulls all 
            instances from a SQL server and detects if in a cluster or not.

        .PARAMETER ComputerName
            Local or remote systems to query for SQL information.

        .PARAMETER WMI
            If specified, try to pull and correlate WMI information for SQL

            I've done limited testing in matching up the service info to registry info.
            Suggestions would be appreciated!

        .NOTES
            Name: Get-SQLInstance
            Author: Boe Prox, edited by cookie monster (to cover wow6432node, WMI tie in)
            DateCreated: 07 SEPT 2013

        .FUNCTIONALITY
            Computers

        .EXAMPLE
            Get-SQLInstance -Computername DC1

                SQLInstance   : MSSQLSERVER
                Version       : 10.0.1600.22
                isCluster     : False
                Computername  : DC1
                FullName      : DC1
                isClusterNode : False
                Edition       : Enterprise Edition
                ClusterName   : 
                ClusterNodes  : {}
                Caption       : SQL Server 2008

                SQLInstance   : MINASTIRITH
                Version       : 10.0.1600.22
                isCluster     : False
                Computername  : DC1
                FullName      : DC1\MINASTIRITH
                isClusterNode : False
                Edition       : Enterprise Edition
                ClusterName   : 
                ClusterNodes  : {}
                Caption       : SQL Server 2008

            Description
            -----------
            Retrieves the SQL information from DC1

        .EXAMPLE
            #Get SQL instances on servers 1 and 2, match them up with service information from WMI
            Get-SQLInstance -Computername Server1, Server2 -WMI

                Computername     : Server1
                SQLInstance      : MSSQLSERVER
                SQLBinRoot       : D:\MSSQL11.MSSQLSERVER\MSSQL\Binn
                Edition          : Enterprise Edition: Core-based Licensing
                Version          : 11.0.3128.0
                Caption          : SQL Server 2012
                isCluster        : False
                isClusterNode    : False
                ClusterName      : 
                ClusterNodes     : {}
                FullName         : Server1
                ServiceName      : SQL Server (MSSQLSERVER)
                ServiceState     : Running
                ServiceAccount   : domain\Server1SQL
                ServiceStartMode : Auto

                Computername     : Server2
                SQLInstance      : MSSQLSERVER
                SQLBinRoot       : D:\Program Files\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\Binn
                Edition          : Enterprise Edition
                Version          : 10.50.4000.0
                Caption          : SQL Server 2008 R2
                isCluster        : False
                isClusterNode    : False
                ClusterName      : 
                ClusterNodes     : {}
                FullName         : Server2
                ServiceName      : SQL Server (MSSQLSERVER)
                ServiceState     : Running
                ServiceAccount   : domain\Server2SQL
                ServiceStartMode : Auto


    #>
    [cmdletbinding()] 
    Param (
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [Alias('__Server','DNSHostName','IPAddress')]
        [string[]]$ComputerName = $env:COMPUTERNAME,

        [switch]$WMI
    ) 
    Begin {
        $baseKeys = "SOFTWARE\\Microsoft\\Microsoft SQL Server",
            "SOFTWARE\\Wow6432Node\\Microsoft\\Microsoft SQL Server"
    }
    Process {
        ForEach ($Computer in $Computername) {
            
            $Computer = $computer -replace '(.*?)\..+','$1'
            Write-Verbose ("Checking {0}" -f $Computer)
            
            #This is Boe's code.  He outputs it outright, I'm assigning to allInstances to correlate with WMI later
            $allInstances = foreach($baseKey in $baseKeys){
                Try {   

                    $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Computer) 
                    $regKey= $reg.OpenSubKey($baseKey)
                    
                    If ($regKey.GetSubKeyNames() -contains "Instance Names") {
                        $regKey= $reg.OpenSubKey("$baseKey\\Instance Names\\SQL" ) 
                        $instances = @($regkey.GetValueNames())
                    }
                    ElseIf ($regKey.GetValueNames() -contains 'InstalledInstances') {
                        $isCluster = $False
                        $instances = $regKey.GetValue('InstalledInstances')
                    }
                    ElseIf ($regKey.GetValueNames() -contains 'InstalledInstances') {
                        $isCluster = $False
                        $instances = $regKey.GetValue('InstalledInstances')
                    }
                    Else {
                        Continue
                    }

                    If ($instances.count -gt 0) { 
                        ForEach ($instance in $instances) {
                            $nodes = New-Object System.Collections.Arraylist
                            $clusterName = $Null
                            $isCluster = $False
                            $instanceValue = $regKey.GetValue($instance)
                            $instanceReg = $reg.OpenSubKey("$baseKey\\$instanceValue")
                            If ($instanceReg.GetSubKeyNames() -contains "Cluster") {
                                $isCluster = $True
                                $instanceRegCluster = $instanceReg.OpenSubKey('Cluster')
                                $clusterName = $instanceRegCluster.GetValue('ClusterName')
                                $clusterReg = $reg.OpenSubKey("Cluster\\Nodes")                            
                                $clusterReg.GetSubKeyNames() | ForEach {
                                    $null = $nodes.Add($clusterReg.OpenSubKey($_).GetValue('NodeName'))
                                }
                            }
                            $instanceRegSetup = $instanceReg.OpenSubKey("Setup")
                            Try {
                                $edition = $instanceRegSetup.GetValue('Edition')
                            } Catch {
                                $edition = $Null
                            }
                            Try {
                                $SQLBinRoot = $instanceRegSetup.GetValue('SQLBinRoot')
                            } Catch {
                                $SQLBinRoot = $Null
                            }
                            Try {
                                $ErrorActionPreference = 'Stop'
                                #Get from filename to determine version
                                $servicesReg = $reg.OpenSubKey("SYSTEM\\CurrentControlSet\\Services")
                                $serviceKey = $servicesReg.GetSubKeyNames() | Where {
                                    $_ -match "$instance"
                                } | Select -First 1
                                $service = $servicesReg.OpenSubKey($serviceKey).GetValue('ImagePath')
                                $file = $service -replace '^.*(\w:\\.*\\sqlservr.exe).*','$1'
                                $version = (Get-Item ("\\$Computer\$($file -replace ":","$")")).VersionInfo.ProductVersion
                            } Catch {
                                #Use potentially less accurate version from registry
                                $Version = $instanceRegSetup.GetValue('Version')
                            } Finally {
                                $ErrorActionPreference = 'Continue'
                            }
                            New-Object PSObject -Property @{
                                Computername = $Computer
                                SQLInstance = $instance
                                SQLBinRoot = $SQLBinRoot
                                Edition = $edition
                                Version = $version
                                Caption = {Switch -Regex ($version) {
                                    "^12"    {'SQL Server 2014';Break}
                                    "^11"    {'SQL Server 2012';Break}
                                    "^10\.5" {'SQL Server 2008 R2';Break}
                                    "^10"    {'SQL Server 2008';Break}
                                    "^9"     {'SQL Server 2005';Break}
                                    "^8"     {'SQL Server 2000';Break}
                                    "^7"     {'SQL Server 7.0';Break}
                                    Default {'Unknown'}
                                }}.InvokeReturnAsIs()
                                isCluster = $isCluster
                                isClusterNode = ($nodes -contains $Computer)
                                ClusterName = $clusterName
                                ClusterNodes = ($nodes -ne $Computer)
                                FullName = {
                                    If ($Instance -eq 'MSSQLSERVER') {
                                        $Computer
                                    } Else {
                                        "$($Computer)\$($instance)"
                                    }
                                }.InvokeReturnAsIs()
                            } | Select Computername, SQLInstance, SQLBinRoot, Edition, Version, Caption, isCluster, isClusterNode, ClusterName, ClusterNodes, FullName
                        }
                    }
                } Catch { 
                    Write-Warning ("{0}: {1}" -f $Computer,$_.Exception.Message)
                }
            }

            #If the wmi param was specified, get wmi info and correlate it!
            if($WMI){
                Try{

                    #Get the WMI info we care about.
                    $sqlServices = $null
                    $sqlServices = @(
                        Get-WmiObject -ComputerName $computer -query "select DisplayName, Name, PathName, StartName, StartMode, State from win32_service where Name LIKE 'MSSQL%'" -ErrorAction stop  |
                            #This regex matches MSSQLServer and MSSQL$*
                            Where-Object {$_.Name -match "^MSSQL(Server$|\$)"} |
                            select DisplayName, StartName, StartMode, State, PathName
                    )

                    #If we pulled WMI info and it wasn't empty, correlate!
                    if($sqlServices){

                        Write-Verbose "WMI Service info:`n$($sqlServices | Format-Table -AutoSize -Property * | out-string)"
                        foreach($inst in $allInstances){
                            $matchingService = $sqlServices |
                                Where {$_.pathname -like "$( $inst.SQLBinRoot )*" -or $_.pathname -like "`"$( $inst.SQLBinRoot )*"} |
                                select -First 1

                            $inst | Select -property Computername,
                                SQLInstance,
                                SQLBinRoot,
                                Edition,
                                Version,
                                Caption,
                                isCluster,
                                isClusterNode,
                                ClusterName,
                                ClusterNodes,
                                FullName,
                                @{ label = "ServiceName"; expression = {
                                    if($matchingService){
                                        $matchingService.DisplayName
                                    }
                                    else{"No WMI Match"}
                                }},
                                @{ label = "ServiceState"; expression = {
                                    if($matchingService){
                                        $matchingService.State
                                    }
                                    else{"No WMI Match"}
                                }},
                                @{ label = "ServiceAccount"; expression = {
                                    if($matchingService){
                                        $matchingService.startname
                                    }
                                    else{"No WMI Match"}
                                }},
                                @{ label = "ServiceStartMode"; expression = {
                                    if($matchingService){
                                        $matchingService.startmode
                                    }
                                    else{"No WMI Match"}
                                }}
                        }
                    }
                }
                Catch {
                    Write-Warning "Could not retrieve WMI info for '$computer':`n$_"
                    $allInstances
                }

            }
            else {
                $allInstances 
            }
        }   
    }
}