function Get-NetworkStatistics {
    <#
    .SYNOPSIS
	    Display current TCP/IP connections for local or remote system

    .FUNCTIONALITY
        Computers

    .DESCRIPTION
	    Display current TCP/IP connections for local or remote system.  Includes the process ID (PID) and process name for each connection.
	    If the port is not yet established, the port number is shown as an asterisk (*).	
	
    .PARAMETER ProcessName
	    Gets connections by the name of the process. The default value is '*'.
	
    .PARAMETER Port
	    The port number of the local computer or remote computer. The default value is '*'.

    .PARAMETER Address
	    Gets connections by the IP address of the connection, local or remote. Wildcard is supported. The default value is '*'.

    .PARAMETER Protocol
	    The name of the protocol (TCP or UDP). The default value is '*' (all)
	
    .PARAMETER State
	    Indicates the state of a TCP connection. The possible states are as follows:
		
	    Closed	 	- The TCP connection is closed. 
	    Close_Wait 	- The local endpoint of the TCP connection is waiting for a connection termination request from the local user. 
	    Closing 	- The local endpoint of the TCP connection is waiting for an acknowledgement of the connection termination request sent previously. 
	    Delete_Tcb 	- The transmission control buffer (TCB) for the TCP connection is being deleted. 
	    Established 	- The TCP handshake is complete. The connection has been established and data can be sent. 
	    Fin_Wait_1 	- The local endpoint of the TCP connection is waiting for a connection termination request from the remote endpoint or for an acknowledgement of the connection termination request sent previously. 
	    Fin_Wait_2 	- The local endpoint of the TCP connection is waiting for a connection termination request from the remote endpoint. 
	    Last_Ack 	- The local endpoint of the TCP connection is waiting for the final acknowledgement of the connection termination request sent previously. 
	    Listen	 	- The local endpoint of the TCP connection is listening for a connection request from any remote endpoint. 
	    Syn_Received 	- The local endpoint of the TCP connection has sent and received a connection request and is waiting for an acknowledgment. 
	    Syn_Sent 	- The local endpoint of the TCP connection has sent the remote endpoint a segment header with the synchronize (SYN) control bit set and is waiting for a matching connection request. 
	    Time_Wait	- The local endpoint of the TCP connection is waiting for enough time to pass to ensure that the remote endpoint received the acknowledgement of its connection termination request. 
	    Unknown		- The TCP connection state is unknown.
	
	    Values are based on the TcpState Enumeration:
	    http://msdn.microsoft.com/en-us/library/system.net.networkinformation.tcpstate%28VS.85%29.aspx
        
        Cookie Monster - modified these to match netstat output per here:
        http://support.microsoft.com/kb/137984

    .PARAMETER ComputerName
        If defined, run this command on a remote system via WMI.  \\computername\c$\netstat.txt is created on that system and the results returned here

    .PARAMETER ShowHostNames
        If specified, will attempt to resolve local and remote addresses.

    .PARAMETER tempFile
        Temporary file to store results on remote system.  Must be relative to remote system (not a file share).  Default is "C:\netstat.txt"

    .EXAMPLE
	    Get-NetworkStatistics | Format-Table

    .EXAMPLE
	    Get-NetworkStatistics iexplore -computername k-it-thin-02 -ShowHostNames | Format-Table

    .EXAMPLE
	    Get-NetworkStatistics -ProcessName md* -Protocol tcp

    .EXAMPLE
	    Get-NetworkStatistics -Address 192* -State LISTENING

    .EXAMPLE
	    Get-NetworkStatistics -State LISTENING -Protocol tcp

    .OUTPUTS
	    System.Management.Automation.PSObject

    .NOTES
	    Author: Shay Levy, code butchered by Cookie Monster
	    Shay's Blog: http://PowerShay.com
        Cookie Monster's Blog: http://ramblingcookiemonster.wordpress.com

    .LINK
        http://gallery.technet.microsoft.com/scriptcenter/Get-NetworkStatistics-66057d71
    #>	
	[OutputType('System.Management.Automation.PSObject')]
	[CmdletBinding(DefaultParameterSetName='name')]
	
	param(
		
		[Parameter(Position=0, ValueFromPipeline=$true,ParameterSetName='name')]
		[System.String]$ProcessName='*',
		
		[Parameter(Position=0, ValueFromPipeline=$true,ParameterSetName='address')]
		[System.String]$Address='*',		
		
        [Parameter(ValueFromPipeline=$true,ParameterSetName='port')]
		$Port='*',

		[Parameter()]
		[ValidateSet('*','tcp','udp')]
		[System.String]$Protocol='*',

		[Parameter()]
		[ValidateSet('*','Closed','Close_Wait','Closing','Delete_Tcb','DeleteTcb','Established','Fin_Wait_1','Fin_Wait_2','Last_Ack','Listening','Syn_Received','Syn_Sent','Time_Wait','Unknown')]
		[System.String]$State='*',
        
        [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [validatescript({test-connection -count 2 -buffersize 16 -quiet -ComputerName $_})]
        [System.String]$computername=$env:COMPUTERNAME,

        [switch]$ShowHostnames,
        
        [switch]$ShowProcessNames = $true,	

        [System.String]$tempFile = "C:\netstat.txt"

	)
    
	begin{
        #Define properties
            $properties = 'Protocol','LocalAddress','LocalPort','RemoteAddress','RemotePort','State','ProcessName','PID'
        
        #Collect processes
            if($ShowProcessNames){
                Try {
                    $processes = get-process -computername $computername -ErrorAction stop | select name, id
                }
                Catch {
                    Write-warning "Could not run Get-Process -computername $computername.  Verify permissions and connectivity.  Defaulting to no ShowProcessNames"
                    $ShowProcessNames = $false
                }
            }

        #store hostnames in array for quick lookup
            $dnsCache = @()
            
	}
	
	process{
	    
        #Handle remote systems
            if($computername -ne $env:COMPUTERNAME){

                #define command
                    [string]$cmd = "cmd /c c:\windows\system32\netstat.exe -ano >> $tempFile"
        
                #define remote file path - computername, drive, folder path
                    $remoteTempFile = "\\{0}\{1}`${2}" -f "$computername", (split-path $tempFile -qualifier).TrimEnd(":"), (Split-Path $tempFile -noqualifier)

                #delete previous results
                    Try{
                        $null = Invoke-WmiMethod -class Win32_process -name Create -ArgumentList "cmd /c del $tempFile" -ComputerName $computername -ErrorAction stop
                    }
                    Catch{
                        Write-Warning "Could not invoke create win32_process on $computername to delete $tempfile"
                    }

                #run command
                    Try{
                        $processID = (Invoke-WmiMethod -class Win32_process -name Create -ArgumentList $cmd -ComputerName $computername -ErrorAction stop).processid
                    }
                    Catch{
                        #If we didn't run netstat, break everything off
                        Throw $_
                        Break
                    }

                #wait for process to complete
                    while (
                        #This while should return true until the process completes
                            $(
                                try{
                                    get-process -id $processid -computername $computername -ErrorAction Stop
                                }
                                catch{
                                    $FALSE
                                }
                            )
                    ) {
                        start-sleep -seconds 2 
                    }
        
                #gather results
                    if(test-path $remoteTempFile){
                
                        Try {
                            $results = Get-Content $remoteTempFile | Select-String -Pattern '\s+(TCP|UDP)'
                        }
                        Catch {
                            Throw "Could not get content from $remoteTempFile for results"
                            Break
                        }

                        Remove-Item $remoteTempFile -force

                    }
                    else{
                        Throw "'$tempFile' on $computername converted to '$remoteTempFile'.  This path is not accessible from your system."
                        Break
                    }
            }
            else{
                #gather results on local PC
                    $results = netstat -ano | Select-String -Pattern '\s+(TCP|UDP)'
            }

        #initialize counter for progress
            $totalCount = $results.count
            $count = 0
    
        #Loop through each line of results    
	        foreach($result in $results) {
        
    	        $item = $result.line.split(' ',[System.StringSplitOptions]::RemoveEmptyEntries)
    
    	        if($item[1] -notmatch '^\[::'){
                
                    #parse the netstat line for local address and port
    	                if (($la = $item[1] -as [ipaddress]).AddressFamily -eq 'InterNetworkV6'){
    	                    $localAddress = $la.IPAddressToString
    	                    $localPort = $item[1].split('\]:')[-1]
    	                }
    	                else {
    	                    $localAddress = $item[1].split(':')[0]
    	                    $localPort = $item[1].split(':')[-1]
    	                } 
                
                    #parse the netstat line for remote address and port
    	                if (($ra = $item[2] -as [ipaddress]).AddressFamily -eq 'InterNetworkV6'){
    	                    $remoteAddress = $ra.IPAddressToString
    	                    $remotePort = $item[2].split('\]:')[-1]
    	                }
    	                else {
    	                    $remoteAddress = $item[2].split(':')[0]
    	                    $remotePort = $item[2].split(':')[-1]
    	                } 
    			
                    #parse the netstat line for other properties
    			        $procId = $item[-1]
    			        $proto = $item[0]
    			        $status = if($item[0] -eq 'tcp') {$item[3]} else {$null}	
                
                    #Display progress bar prior to getting process name or host name
                        Write-Progress  -Activity "Resolving host and process names"`
                            -Status "Resolving process ID $procId with remote address $remoteAddress and local address $localAddress"`
                            -PercentComplete (( $count / $totalCount ) * 100)
    			
                    #If we are running showprocessnames, get the matching name
                        if($ShowProcessNames){
                    
                            #handle case where process spun up in the time between running get-process and running netstat
                            if($procName = $processes | ?{$_.id -eq $procId} | select -ExpandProperty name ){ }
                            else {$procName = "Unknown"}

                        }
                        else{$procName = "NA"}
    							
                    #if the showhostnames switch is specified, try to map IP to hostname
                        if($showHostnames){
                            $tmpAddress = $null
                            try{
                                if($remoteAddress -eq "127.0.0.1" -or $remoteAddress -eq "0.0.0.0"){
                                    $remoteAddress = $computername
                                }
                                elseif($remoteAddress -match "\w"){
                                    
                                    #check with dns cache first
                                        if($tmpAddress = $dnsCache -match "`t$remoteAddress$"){
                                            $remoteAddress = ( $tmpAddress -split "`t" )[0]
                                            write-verbose "using cached REMOTE '$tmpADDRESS'"
                                        }
                                        else{
                                            #if address isn't in the cache, resolve it and add it
                                                $tmpAddress = $remoteAddress
                                                $remoteAddress = [System.Net.DNS]::GetHostByAddress("$remoteAddress").hostname
                                                $dnsCache += "$remoteAddress`t$tmpAddress"
                                                write-verbose "using non cached REMOTE '$remoteAddress`t$tmpAddress"
                                        }
                                }
                            }
                            catch{ }

                            try{

                                if($localAddress -eq "127.0.0.1" -or $localAddress -eq "0.0.0.0"){
                                    $localAddress = $computername
                                }
                                elseif($localAddress -match "\w"){
                                    #check with dns cache first
                                        if($tmpAddress = $dnsCache -match "`t$localAddress$"){
                                            $localAddress = ( $tmpAddress -split "`t" )[0]
                                            write-verbose "using cached LOCAL '$tmpADDRESS'"
                                        }
                                        else{
                                            #if address isn't in the cache, resolve it and add it
                                                $tmpAddress = $localAddress
                                                $localAddress = [System.Net.DNS]::GetHostByAddress("$localAddress").hostname
                                                $dnsCache += "$localAddress`t$tmpAddress"
                                                write-verbose "using non cached LOCAL '$localAddress'`t'$tmpAddress'"
                                        }
                                }
                            }
                            catch{ }
                        }
    
    			    #Define the object	
    			        $pso = New-Object -TypeName PSObject -Property @{
				            PID = $procId
				            ProcessName = $procName
				            Protocol = $proto
				            LocalAddress = $localAddress
				            LocalPort = $localPort
				            RemoteAddress =$remoteAddress
				            RemotePort = $remotePort
				            State = $status
			            } | Select-Object -Property $properties								
                
                    #Filter and display the object
    			        if($PSCmdlet.ParameterSetName -eq 'port'){
				            if($pso.RemotePort -like $Port -or $pso.LocalPort -like $Port){
				                if($pso.Protocol -like $Protocol -and $pso.State -like $State){
						            $pso
					            }
				            }
			            }
    
    			        if($PSCmdlet.ParameterSetName -eq 'address'){
				            if($pso.RemoteAddress -like $Address -or $pso.LocalAddress -like $Address){
				                if($pso.Protocol -like $Protocol -and $pso.State -like $State){
						            $pso
					            }
				            }
			            }
    				
    			        if($PSCmdlet.ParameterSetName -eq 'name'){		
				            if($pso.ProcessName -like $ProcessName){
					            if($pso.Protocol -like $Protocol -and $pso.State -like $State){
				   		            $pso
					            }
				            }
			            }
                
                    #Increment the progress counter
                        $count++
                }
            }
    }
}