function Open-ISEFunction {
     <#
     .SYNOPSIS
         Open a function in ISE
     .DESCRIPTION
         Open a function in ISE.  Any function that can be obtained by (get-command <command>).definition.  Pretty much anything that isn't compiled in a DLL or obfuscated in some other manner.
     .FUNCTIONALITY
         General Command
    #>
    [cmdletbinding()]
    param(
    
    #In the validation block, check if input is a function and get the definition
    [ValidateScript({ Get-Command -commandtype function -name $_ })]
        [string[]]$function
    )

    foreach($fn in $function){
        
        #Get the definition
        $definition = (Get-Command -commandtype function -name $fn).definition
        
        #If the definition exists, add a new tab with the contents.
        if($definition){
            
            #Definition won't include function keyword.  Add it.
            $definition = "function $fn { $definition }"
            
            #Add the file and definition content
            $tab = $psise.CurrentPowerShellTab.files.Add()
            $tab.editor.text = $definition

            #set the caret to column 1 line 1
            $tab.editor.SetCaretPosition(1,1)

            #Sleep a few milliseconds.  Not sure why but omitting this has caused issues for me.
            start-sleep -Milliseconds 200
        }
    }
}