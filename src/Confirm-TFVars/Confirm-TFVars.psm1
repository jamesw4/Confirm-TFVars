function Confirm-TFVars {
    <#
    .SYNOPSIS
     Uses terraform console to verify a tfvars file against variable definition.
    .DESCRIPTION
     Uses terraform console to verify a tfvars file against variable definition.
    .PARAMETER VarFile
     Optionally specify the tfvars file name to validate, if commited all tfvars in current directory will be validated.
    .PARAMETER VariableDefinitionFile
     Specify the terraform file that contains the variable definitions, if ommited defaults to variables.tf.
    .LINK
     https://github.com/jamesw4/confirm-tfvars
    .INPUTS
     None
    .OUTPUTS
     None
    .EXAMPLE
     Confirm-TFVars
     Attempts validation assuming the variable defintion is in variables.tf and validates any .tfvars files in current directory.
    .EXAMPLE
     Confirm-TFVars -VarFile dev.tfvars
     Attempts validation assuming the variable defintion is in variables.tf and validates dev.tfvars in current directory.
    .EXAMPLE
     Confirm-TFVars -VarFile dev.tfvars -VariableDefinitionFile vars.tf
     Attempts validation using vars.tf as the defintion and validates dev.tfvars in current directory.
    #>

    param (
        [string]$VarFile = "*.tfvars",
        [string]$VariableDefinitionFile = "variables.tf"
    )


    # Some sanity checks
    $tfvars = Get-ChildItem $VarFile -ErrorAction SilentlyContinue

    If (-not(Get-Command("terraform") -ErrorAction SilentlyContinue)) {
        Write-Error "Terraform CLI is required, but could not be found."
        return
    }

    If ($(Get-ChildItem *.tf).count -eq 0) {
        Write-Error "No terraform files found in current directory, rerun from a directory containing terraform configuration."
        return
    }

    If (-not(Test-Path $VariableDefinitionFile)) {
        Write-Error "Variable definition file ""$VariableDefinitionFile"" could not be found."
        return
    }

    If ($($tfvars).count -eq 0) {
        Write-Error "No vars files found matching name ""$varfile""."
        return
    }

    # Copy variable defintion to a temp folder so we can target it in isolation
    $Folder = New-Item -ItemType Directory -Name "Confirm-TFVars-Sandbox" -Path $([System.IO.Path]::GetTempPath()) -Force
    Copy-Item $VariableDefinitionFile $Folder
    
    # Ensure we can output the special chars returned by terraform correctly
    $consoleOutputEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $errorCount = 0

    # Loop through the tfvars and validate
    foreach ($tfvar in $tfvars) {
        $result = "exit" | terraform -chdir="$Folder" console --var-file=$tfvar 2>&1
        If ($null -ne $result) {
            $filename = $tfvar.name
            Write-Error "Validation of $filename failed."
            $result | Where-Object { $($_.GetType()).name -eq "ErrorRecord" }
            $errorCount++
        }
    }

    If ($errorCount -eq 0) {
        Write-Host "Success!" -ForegroundColor Green -NoNewline; Write-Host " The variables are valid."
    }

    # Tidy up
    Remove-Item $Folder -Recurse
    [Console]::OutputEncoding = $consoleOutputEncoding
}