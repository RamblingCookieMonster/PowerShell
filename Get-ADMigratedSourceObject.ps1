function Get-ADMigratedSourceObject {
    <#
    .SYNOPSIS
	    Find the source account(s) from a migrated target account

    .DESCRIPTION
	    Find the source account(s) from a migrated target account.

        If you used ADMT or another migration tool to migrate accounts,
        this function will help you map out the source accounts they came from.

        Basic workflow:
            Search Path by SamAccountName
            Extract SIDHistory
            Searches SourcePath, or enumeration of all trusted domains for the SID

    .FUNCTIONALITY
        Active Directory

    .PARAMETER samAccountName
        samAccountName from the target domain - We find any source accounts tied to this.

    .PARAMETER Path
        LDAP Path for the target domain to search:  e.g. contoso.com, DomainController1

        LDAP:// is prepended when omitted   

    .PARAMETER SourcePath
        LDAP Path for the source domain to search:  e.g. contoso.com, DomainController1

        If none is specified, we enumerate trusts of the logged on user's domain, search all of them

        LDAP:// is prepended when omitted
    
    .PARAMETER Property
        Specific properties to return from the source

    .PARAMETER SourceCredential
        If specified, Credential to use for querying the SourcePath

    .PARAMETER Credential
        If Specified, Credential to use for querying the Path

    .PARAMETER As
        Change the output object type. We default to PSObject.

        SearchResult        = Results directly from DirectorySearcher
        DirectoryEntry      = Invoke GetDirectoryEntry against each DirectorySearcher object returned
        PSObject (Default)  = Create a PSObject with expected properties and types

    .PARAMETER Simple
        If specified, show a simplified output with the following properties:

            SamAccountName       = The target account you queried for
            SourceSamAccountName = A source account the target is tied to
            ObjectClass          = Last element in objectClass (e.g. group, user)
            TrustedDomain        = The source domain name.

    .EXAMPLE

        Get-ADMigratedSourceObject -samAccountName jdoe -SourcePath contoso.com -Path contoso.org

        # Find an AD object in the target contoso.org with samaccountname jdoe.  Use this SIDHistory to find matching source accounts in the source contoso.com

    .EXAMPLE

        Get-ADMigratedSourceObject -samAccountName jkelly2

        # Search the current domain for jkelly2; if they have a SIDHistory, search all trusted domains for a matching object

    .EXAMPLE

        Get-ADMigratedSourceObject -samaccountname j* -simple
        
        # Search the current domain for any account starting with j, map out source accounts for any previously migrated objects, only show account names, type, and domain.

    #>	
    [cmdletbinding()]
    param(
        [Parameter( Position=0,
                    Mandatory = $true,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ParameterSetName='SAM')]
        [string[]]$samAccountName = "*",

        [string]$Path = $env:USERDOMAIN,

        [string]$SourcePath,

        [string]$ObjectCategory,

        [validateset("PSObject","DirectoryEntry","SearchResult")]
        [string]$As = "PSObject",

        [switch]$Simple,

        [string[]]$Property = $Null,

        [System.Management.Automation.PSCredential]$Credential,

        [System.Management.Automation.PSCredential]$SourceCredential
    )
    Begin
    {

        #Region DEPENDENCIES
        function Get-ADSIObject {
            [cmdletbinding(DefaultParameterSetName='SAM')]
            Param(
                [Parameter( Position=0,
                            ValueFromPipeline=$true,
                            ValueFromPipelineByPropertyName=$true,
                            ParameterSetName='SAM')]
                [string[]]$samAccountName = "*",

                [Parameter( Position=1,
                            ParameterSetName='SAM')]
                [string[]]$ObjectCategory = "*",

                [Parameter( ParameterSetName='Query',
                            Mandatory = $true )]
                [string]$Query = $null,

                [string]$Path = $Null,

                [string[]]$Property = $Null,

                [int]$Limit,

                [string]$SearchRoot,

                [System.Management.Automation.PSCredential]$Credential,

                [validateset("PSObject","DirectoryEntry","SearchResult")]
                [string]$As = "PSObject"
            )

            Begin 
            {
                #Define parameters for creating the object
                $Params = @{
                    TypeName = "System.DirectoryServices.DirectoryEntry"
                    ErrorAction = "Stop"
                }

                #If we have an LDAP path, add it in.
                    if($Path){

                        if($Path -notlike "^LDAP")
                        {
                            $Path = "LDAP://$Path"
                        }
            
                        $Params.ArgumentList = @($Path)

                        #if we have a credential, add it in
                        if($Credential)
                        {
                            $Params.ArgumentList += $Credential.UserName
                            $Params.ArgumentList += $Credential.GetNetworkCredential().Password
                        }
                    }
                    elseif($Credential)
                    {
                        Throw "Using the Credential parameter requires a Path parameter"
                    }

                #Create the domain entry for search root
                    Try
                    {
                        Write-Verbose "Bound parameters:`n$($PSBoundParameters | Format-List | Out-String )`nCreating DirectoryEntry with parameters:`n$($Params | Out-String)"
                        $DomainEntry = New-Object @Params
                    }
                    Catch
                    {
                        Throw "Could not establish DirectoryEntry: $_"
                    }
                    $DomainName = $DomainEntry.name

                #Set up the searcher
                    $Searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                    $Searcher.PageSize = 1000
                    $Searcher.SearchRoot = $DomainEntry
                    if($Limit)
                    {
                        $Searcher.SizeLimit = $limit
                    }
                    if($Property)
                    {
                        foreach($Prop in $Property)
                        {
                            $Searcher.PropertiesToLoad.Add($Prop) | Out-Null
                        }
                    }
                    if($SearchRoot)
                    {
                        if($SearchRoot -notlike "^LDAP")
                        {
                            $SearchRoot = "LDAP://$SearchRoot"
                        }

                        $Searcher.SearchRoot = [adsi]$SearchRoot
                    }

                #Define a function to get ADSI results from a specific query
                Function Get-ADSIResult
                {
                    [cmdletbinding()]
                    param(
                        [string[]]$Property = $Null,
                        [string]$Query,
                        [string]$As,
                        $Searcher
                    )
            
                    #Invoke the query
                        $Results = $null
                        $Searcher.Filter = $Query
                        $Results = $Searcher.FindAll()
            
                    #If SearchResult, just spit out the results.
                        if($As -eq "SearchResult")
                        {
                            $Results
                        }
                    #If DirectoryEntry, invoke GetDirectoryEntry
                        elseif($As -eq "DirectoryEntry")
                        {
                            $Results | ForEach-Object { $_.GetDirectoryEntry() }
                        }
                    #Otherwise, get properties from the object
                        else
                        {
                            $Results | ForEach-Object {
                
                                #Get the keys.  They aren't an array, so split them up, remove empty, and trim just in case I screwed something up...
                                    $object = $_
                                    #cast to array of strings or else PS2 breaks when we select down the line
                                    [string[]]$properties = ($object.properties.PropertyNames) -split "`r|`n" | Where-Object { $_ } | ForEach-Object { $_.Trim() }
            
                                #Filter properties if desired
                                    if($Property)
                                    {
                                        $properties = $properties | Where-Object {$Property -Contains $_}
                                    }
            
                                #Build up an object to output.  Loop through each property, extract from ResultPropertyValueCollection
                                    #Create the object, PS2 compatibility.  can't just pipe to select, props need to exist
                                        $hash = @{}
                                        foreach($prop in $properties)
                                        {
                                            $hash.$prop = $null
                                        }
                                        $Temp = New-Object -TypeName PSObject -Property $hash | Select -Property $properties
                        
                                    foreach($Prop in $properties)
                                    {
                                        Try
                                        {
                                            $Temp.$Prop = foreach($item in $object.properties.$prop)
                                            {
                                                $item
                                            }
                                        }
                                        Catch
                                        {
                                            Write-Warning "Could not get property '$Prop': $_"
                                        }   
                                    }
                                    $Temp
                            }
                        }
                }
            }
            Process
            {
                #Set up the query as defined, or look for a samaccountname.  Probably a cleaner way to do this...
                    if($PsCmdlet.ParameterSetName -eq 'Query'){
                        Write-Verbose "Working on Query '$Query'"
                        Get-ADSIResult -Searcher $Searcher -Property $Property -Query $Query -As $As
                    }
                    else
                    {
                        foreach($AccountName in $samAccountName)
                        {
                            #Build up the LDAP query...
                                $QueryArray = @( "(samAccountName=$AccountName)" )
                                if($ObjectCategory)
                                {
                                    [string]$TempString = ( $ObjectCategory | ForEach-Object {"(objectCategory=$_)"} ) -join ""
                                    $QueryArray += "(|$TempString)"
                                }
                                $Query = "(&$($QueryArray -join ''))"
                            Write-Verbose "Working on built Query '$Query'"
                            Get-ADSIResult -Searcher $Searcher -Property $Property -Query $Query -As $As
                        }
                    }
            }
            End
            {
                $Searcher = $null
                $DomainEntry = $null
            }
        }

        #endregion DEPENDENCIES
        
        if(-not $SourcePath)
        {

            $DomainsToQueryObjects = Get-ADSIObject -Query "(ObjectClass=trustedDomain)" -Property trustpartner, securityIdentifier -as DirectoryEntry
            $DomainsToQuery = $DomainsToQueryObjects | Select -ExpandProperty trustPartner
            $DomainsHash = @{}
            foreach($Domain in $DomainsToQueryObjects)
            {
                Try
                {
                    $TrustPartner = $null
                    $TrustPartner = $Domain.trustPartner.value

                    $SID = $null
                    $SID = (New-Object System.Security.Principal.SecurityIdentifier($Domain.securityIdentifier[0],0) -ErrorAction Stop).Value

                    $DomainsHash.Add($TrustPartner, $SID)
                }
                Catch
                {
                    Write-Error "Could not find SID for trustPartner $TrustPartner"
                }
            }
            Write-Verbose "Found trusts: $DomainsToQuery"
        }
        else
        {
            $DomainsToQuery = @($SourcePath)
        }

        #Source search, Output params
            $OldParams = @{} 
            if($SourceCredential)
            {
                $OldParams.Credential = $SourceCredential
            }
            if($as)
            {
                $OldParams.As = $As
            }
            if($Property)
            {
                $OldParams.Property = $Property
                if($Simple)
                {
                    $OldParams.Property += "SamAccountName"
                    $OldParams.Property += "ObjectClass"
                }
            }

        #Target search params
            $NewParams = @{} 
            if($Credential)
            {
                $NewParams.add('Credential', $Credential)
            }
            if($ObjectCategory)
            {
                $NewParams.add('ObjectCategory',$ObjectCategory)
            } 
    }
    Process
    {
        foreach($account in $samAccountName)
        {
            #Get the legacy object as a directory entry.
            Try
            {
                $newADSIObject = $null
                $newADSIObject = @( Get-ADSIObject -samaccountname $account -Path $Path -Property samaccountname, objectSID, SIDHistory -as DirectoryEntry @NewParams -ErrorAction Stop )
                if(-not $newADSIObject)
                {
                    Write-Warning "No target object found for account $account on path $Path"
                    continue
                }
            }
            Catch
            {
                Write-Error "Error obtaining account $account on path $Path`: $_"
                continue
            }

            foreach($ADSIObject in $newADSIObject)
            {
                #Convert byte array to string sid
                    $OldSID = $Null
                    $AllSids = @(
                        foreach($Sid in @($ADSIObject.SIDHistory))
                        {
                            Try
                            {
                                $OldSID = (New-Object System.Security.Principal.SecurityIdentifier($Sid,0)).Value
                                Write-Verbose "Found SID '$OldSid'"
                                $OldSID
                            }
                            Catch
                            {
                                Write-Error "Error obtaining SID from account $account on path $Path with sid $($sid | out-string)"
                                Continue
                            }
                        }
                    )

                #Get the new object with matching SID
                    foreach($sid in $AllSids)
                    {
                        foreach($Domain in $DomainsToQuery)
                        {
                            if($sid -match $DomainsHash.$Domain)
                            {
                                Write-Verbose "Checking '$Domain' for '$sid':"
                                Try
                                {
                                    $Raw = Get-ADSIObject -Path $Domain -Query "(objectSID=$sid)" @OldParams -ErrorAction stop
                                    if($Raw)
                                    {
                                        if($Simple)
                                        {
                                            $Props = @(
                                                @{ label = "SamAccountName"; expression = {$ADSIObject.sAMAccountName.Value} },
                                                @{ label = "SourceSamAccountName"; expression = {$Raw.samaccountname} },
                                                @{ label = "ObjectClass"; expression = {$Raw.ObjectClass[-1]}}
                                                @{ label = "TrustedDomain"; expression = {$Domain} }
                                            )
                                            if($Property)
                                            {
                                                $Props += @($Property | ?{$_ -ne 'SamAccountName'})
                                            }
                                            
                                            $Raw | Select -property $Props
                                        }
                                        else
                                        {
                                            $Raw
                                        }
                                    }
                                }
                                Catch
                                {
                                    Write-Error "Error obtaining sid $sid on path $SourcePath`: $_"
                                    Continue
                                }
                            }
                            else
                            {
                                Write-Verbose "Skipping domain $Domain, sid '$sid' does not match domain sid '$($DomainsHash.$domain)'"
                            }
                        }
                    }
            }
        }
    }
}