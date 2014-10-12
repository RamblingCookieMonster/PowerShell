function Get-ADSIObject {  
    <#
    .SYNOPSIS
	    Get AD object (user, group, etc.) via ADSI.

    .DESCRIPTION
	    Get AD object (user, group, etc.) via ADSI.

        Invoke a specify an LDAP Query, or search based on samaccountname and/or objectcategory

    .FUNCTIONALITY
        Active Directory

    .PARAMETER samAccountName
        Specific samaccountname to filter on

    .PARAMETER ObjectCategory
        Specific objectCategory to filter on
    
    .PARAMETER Query
        LDAP filter to invoke

    .PARAMETER Path
        LDAP Path.  e.g. contoso.com, DomainController1

        LDAP:// is prepended when omitted

    .PARAMETER Property
        Specific properties to query for
 
    .PARAMETER Limit
        If specified, limit results to this size

    .PARAMETER Credential
        Credential to use for query

        If specified, the Path parameter must be specified as well.

    .PARAMETER As
        SearchResult        = results directly from DirectorySearcher
        DirectoryEntry      = Invoke GetDirectoryEntry against each DirectorySearcher object returned
        PSObject (Default)  = Create a PSObject with expected properties and types

    .EXAMPLE
        Get-ADSIObject jdoe
        # Find an AD object with the samaccountname jdoe

    .EXAMPLE
        Get-ADSIObject -Query "(&(objectCategory=Group)(samaccountname=domain admins))"
        # Find an AD object meeting the specified criteria

    .EXAMPLE
        Get-ADSIObject -Query "(objectCategory=Group)" -Path contoso.com
        # List all groups at the root of contoso.com
    
    .EXAMPLE
        Echo jdoe, cmonster | Get-ADSIObject -property mail -ObjectCategory User | Select -expandproperty mail
        # Find an AD object for a few users, extract the mail property only

    .EXAMPLE
        $DirectoryEntry = Get-ADSIObject TESTUSER -as DirectoryEntry
        $DirectoryEntry.put(‘Title’,’Test’) 
        $DirectoryEntry.setinfo()

        #Get the AD object for TESTUSER in a usable form (DirectoryEntry), set the title attribute to Test, and make the change.

    .LINK
        https://gallery.technet.microsoft.com/scriptcenter/Get-ADSIObject-Portable-ae7f9184

    #>	
    [cmdletbinding(DefaultParameterSetName='SAM')]
    Param(
        [Parameter( Position=0,
                    Mandatory = $true,
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
                Throw "Using the Credential parameter requires a valid Path parameter"
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