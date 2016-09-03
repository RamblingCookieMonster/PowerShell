#handle PS2
    if(-not $PSScriptRoot)
    {
        $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
    }

#Get public and private function definition files.
    $Public  = @( Get-ChildItem -Path $PSScriptRoot\*.ps1 -ErrorAction SilentlyContinue )
    $Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )
    $ModuleRoot = $PSScriptRoot

#Dot source the files
    Foreach($import in @($Public + $Private))
    {
        Try
        {
            . $import.fullname
        }
        Catch
        {
            Write-Error -Message "Failed to import function $($import.fullname): $_"
        }
    }

Export-ModuleMember -Function $Public.Basename
