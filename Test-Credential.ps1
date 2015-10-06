function Test-Credential { 
    <#
    .SYNOPSIS
        Takes a PSCredential object and validates it

    .DESCRIPTION
        Takes a PSCredential object and validates it against a domain or local machine

        Borrows from a variety of sources online, don't recall which - apologies!

    .PARAMETER Credential
        A PScredential object with the username/password you wish to test. Typically this is generated using the Get-Credential cmdlet. Accepts pipeline input.

    .PARAMETER Context
        An optional parameter specifying what type of credential this is. Possible values are 'Domain','Machine',and 'ApplicationDirectory.' The default is 'Domain.'

    .PARAMETER ComputerName
        If Context is machine, test local credential against this computer.

    .PARAMETER Domain
        If context is domain (default), test local credential against this domain. Default is current user's

    .OUTPUTS
        A boolean, indicating whether the credentials were successfully validated.

    .EXAMPLE
        #I provide my AD account credentials
        $cred = get-credential

        #Test credential for an active directory account
        Test-Credential $cred

    .EXAMPLE
        #I provide local credentials here
        $cred = get-credential

        #Test credential for a local account
        Test-Credential -ComputerName SomeComputer -Credential $cred

    .EXAMPLE
        #I provide my AD account credentials for domain2
        $cred = get-credential

        #Test credential for an active directory account
        Test-Credential -Credential $cred -Domain domain2.com

    .FUNCTIONALITY
        Active Directory

    #>
    [cmdletbinding(DefaultParameterSetName = 'Domain')]
    param(
        [parameter(ValueFromPipeline=$true)]
        [System.Management.Automation.PSCredential]$Credential = $( Get-Credential -Message "Please provide credentials to test" ),

        [validateset('Domain','Machine', 'ApplicationDirectory')]
        [string]$Context = 'Domain',
        
        [parameter(ParameterSetName = 'Machine')]
        [string]$ComputerName,

        [parameter(ParameterSetName = 'Domain')]
        [string]$Domain = $null
    )
    Begin
    {
        Write-Verbose "ParameterSetName: $($PSCmdlet.ParameterSetName)`nPSBoundParameters: $($PSBoundParameters | Out-String)"
        Try
        {
            Add-Type -AssemblyName System.DirectoryServices.AccountManagement
        }
        Catch
        {
            Throw "Could not load assembly: $_"
        }
        
        #create principal context with appropriate context from param. If either comp or domain is null, thread's user's domain or local machine are used
        if ($Context -eq 'ApplicationDirectory' )
        {
            #Name=$null works for machine/domain, not applicationdirectory
            $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::$Context)
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Domain')
        {
            $Context = $PSCmdlet.ParameterSetName
            $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::$Context, $Domain)
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Machine')
        {
            $Context = $PSCmdlet.ParameterSetName
            $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::$Context, $ComputerName)
        }

    }
    Process
    {
        #Validate provided credential
        $DS.ValidateCredentials($Credential.UserName, $Credential.GetNetworkCredential().password)
    }
    End
    {
        $DS.Dispose()
    }
}