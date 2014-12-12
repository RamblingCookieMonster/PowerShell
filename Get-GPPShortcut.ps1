Function Get-GPPShortcut {
    <#
    .SYNOPSIS     
        Find GPP Shortcut preference items in your current domain.

    .DESCRIPTION
        Find GPP Shortcut preference items in your current domain.

        If no parameter is specified, search all GPOs
        Requires GroupPolicy module.  Get it in the RSAT, enable the Windows Feature.
        The filters property will be an array of all filters

    .PARAMETER GUID
        If specified, search this GUID
    
    .PARAMETER Name
        If specified, search this Name
    
    .FUNCTIONALITY
        Group Policy
    
    .EXAMPLE
        #Get all group policy preferences with shortcut preference items
            Get-GPPShortcut
 
    .EXAMPLE
        #Explore basic info in out grid view
            Get-GPPShortcut | Select GPOName, action, TargetPath, Arguments, shortcutPath | out-gridview

    .EXAMPLE

        #Pick a date to filter shortcuts by
            $date = (get-date).adddays(-7)
        
        #Find shortcuts changed in last 7 days, explore in gridview
            Get-GPPShortcut | ?{$_.changed -gt $date} | Sort Changed -descending | out-gridview

    .EXAMPLE
        #Get all shortcut items from the 'Group policy x' GPO
            Get-GPPShortcut -Name "Group policy x"

    .NOTES
        Thanks to Johan Dahlbom for the workflow this command borrows: http://365lab.net/2013/12/31/getting-all-gpp-drive-maps-in-a-domain-with-powershell/
    #>
    [cmdletbinding(DefaultParameterSetName='Name')]
    param(
        [Parameter( Position=0,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ParameterSetName='Name'
        )]
            [string[]]$Name = $null,

        [Parameter( Position=1,
                    ParameterSetName='GUID'
        )]
            [string[]]$GUID = $null
    )
    Begin
    {

        try
        {
            Import-Module GroupPolicy -ErrorAction Stop
            If(-not (Get-Module GroupPolicy -ErrorAction SilentlyContinue))
            {
                throw "GroupPolicy module not Installed"
                break
            }
        }
        catch
        {
            throw "Error importing GroupPolicy module: $_"
            break
        }

        $xmlProps = "NamespaceURI",
            "Prefix",
            "NodeType",
            "ParentNode",
            "OwnerDocument",
            "IsEmpty",
            "Attributes",
            "HasAttributes",
            "SchemaInfo",
            "InnerXml",
            "InnerText",
            "NextSibling",
            "PreviousSibling",
            "Value",
            "ChildNodes",
            "FirstChild",
            "LastChild",
            "HasChildNodes",
            "IsReadOnly",
            "OuterXml",
            "BaseURI"

    }
    Process
    {

        #if name or guid isn't specified, get them all
        if(-not $GUID -and -not $Name)
        {
            Write-Verbose "Getting all GPOs"
            $GPO = Get-GPO -all
        }

        #If a GUID or Name is specified, get the GPOs
            if ( $Name -and $PsCmdlet.ParameterSetName -eq "Name" )
            {
                $GPO = foreach($nam in $Name)
                {
                    Get-GPO -Name $nam
                }
            }
            if( $GUID -and $PsCmdlet.ParameterSetName -eq "GUID" )
            {
                $GPO = foreach($ID in $GUID)
                {
                    Get-GPO -Guid $ID
                }
            }
    
        foreach ($Policy in $GPO){
        
            $GPOID = $Policy.Id
            $GPODom = $Policy.DomainName
            $GPODisp = $Policy.DisplayName
        
            #we want to check both user and computer configurations
            $configTypes = "User", "Machine"

            foreach($configType in $configTypes)
            {

                #Test the path in sysvol where drive maps would be...
                $path = "\\$($GPODom)\SYSVOL\$($GPODom)\Policies\{$($GPOID)}\$configType\Preferences\Shortcuts\Shortcuts.xml"

                if (Test-Path $path -ErrorAction SilentlyContinue)
                {
                    [xml]$xml = Get-Content $path
                
                    #Pull relevant data from the xml
                    foreach ( $prefItem in $xml.Shortcuts.Shortcut )
                    {

                        #Get all filters for this preference item
                        $childNodes = @( $prefItem.filters.childnodes )

                        #output the object with appropriate properties, sorted
                        New-Object PSObject -Property @{
                            GPOName = $GPODisp
                            ConfigType = $configType
                            action = $prefItem.Properties.action.Replace("U","Update").Replace("C","Create").Replace("D","Delete").Replace("R","Replace")
                            targetType = $prefItem.Properties.targetType
                            targetPath = $prefItem.Properties.targetPath
                            shortcutKey = $prefItem.Properties.shortcutKey
                            startIn = $prefItem.Properties.startIn
                            arguments = $prefItem.Properties.arguments
                            iconPath = $prefItem.Properties.iconPath
                            window = $prefItem.Properties.window
                            shortcutPath = $prefItem.Properties.shortcutPath
                            disabled = $prefItem.disabled
                            changed = $( Try { Get-Date "$( $prefItem.changed )"} Catch {"Err"} )
                            filters = $(
                                #Here we loop through each filter, only select the non-XML properties
                                foreach($filter in $childNodes){
                                    Try { $filter | select -Property * -ExcludeProperty $xmlProps }
                                    Catch { Continue }
                                }
                            )
                        } | Select GPOName, ConfigType, action, targetType, targetPath, shortcutKey, startIn, arguments, iconPath, window, shortcutPath, disabled, changed, filters
                    }
                }
            }
        }
    }
}