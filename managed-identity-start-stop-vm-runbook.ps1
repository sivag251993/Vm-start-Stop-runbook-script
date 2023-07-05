param(
    [Parameter(Mandatory = $true)]
    # Specify the name of the Virtual Machine, or use the asterisk symbol "*" to affect all VMs in the resource group
    $VMName,
    [Parameter(Mandatory = $true)]
    $ResourceGroupName,
    [Parameter(Mandatory = $false)]
    # Optionally specify Azure Subscription ID
    $AzureSubscriptionID,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Start", "Stop")]
    # Specify desired Action, allowed values "Start" or "Stop"
    $Action,
    [Parameter(Mandatory = $true)]
    [ValidateSet("UAI","SAI","*")]
    $Managed_Identity_Type,
    # Specify User assigned client id if UAI or * is specified
    [Parameter(Mandatory = $false)]
    $USI_Client_Id
)

Write-Output "Script started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

$errorCount = 0

# connect to Azure, suppress output
if ($Managed_Identity_Type -eq "UAI"){
    try {
        $null = Connect-AzAccount -Identity -AccountId $USI_Client_Id
    }
    catch {
        $ErrorMessage = "Error connecting to Azure: " + $_.Exception.message
        Write-Error $ErrorMessage
        throw $ErrorMessage
        exit 
    }
}elseif ($Managed_Identity_Type -eq "SAI"){
    try {
        $null = Connect-AzAccount -Identity
    }
    catch {
        $ErrorMessage = "Error connecting to Azure: " + $_.Exception.message
        Write-Error $ErrorMessage
        throw $ErrorMessage
        exit
    }

}else{
    try {
        $null = Connect-AzAccount -Identity
    }
    catch {
        $ErrorMessage = "Error connecting to Azure: " + $_.Exception.message
        Write-Error $ErrorMessage
        throw $ErrorMessage
        exit
    }
}

# select Azure subscription by ID if specified, suppress output
if ($AzureSubscriptionID) {
    try {
        $null = Select-AzSubscription -SubscriptionID $AzureSubscriptionID    
    }
    catch {
        $ErrorMessage = "Error selecting Azure Subscription ($AzureSubscriptionID): " + $_.Exception.message
        Write-Error $ErrorMessage
        throw $ErrorMessage
        exit
    }
}

# check if we are in an Azure Context
try {
    $AzContext = Get-AzContext
}
catch {
    $ErrorMessage = "Error while trying to retrieve the Azure Context: " + $_.Exception.message
    Write-Error $ErrorMessage
    throw $ErrorMessage
    exit
}
if ([string]::IsNullOrEmpty($AzContext.Subscription)) {
    $ErrorMessage = "Error. Didn't find any Azure Context. Have you assigned the permissions according to 'CustomRoleDefinition.json' to the Managed Identity?"
    Write-Error $ErrorMessage
    throw $ErrorMessage
    exit
}

if ($VMName -eq "*") {
    try {
        # if "*" was given as the VMName, get all VMs in the resource group
        $VMs = Get-AzVM -ResourceGroupName $ResourceGroupName
    }
    catch {
        $ErrorMessage = "Error getting VMs from resource group ($ResourceGroupName): " + $_.Exception.message

        Write-Error $ErrorMessage
        throw $ErrorMessage
        exit
    }
    
}
else {
    try {
        # get only the specified VM
        $VMs = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VMName
    }
    catch {
        $ErrorMessage = "Error getting VM ($VMName) from resource group ($ResourceGroupName): " + $_.Exception.message
        Write-Error $ErrorMessage
        throw $ErrorMessage
        exit
    }
    
}

# Loop through all specified VMs (if more than one). The loop only executes once if only one VM is specified.
foreach ($VM in $VMs) {
    switch ($Action) {
        "Start" {
            # Start the VM
            try {
                Write-Output "Starting VM $($VM.Name)..."
                $null = $VM | Start-AzVM -ErrorAction Stop -NoWait
            }
            catch {
                $ErrorMessage = $_.Exception.message
                Write-Error "Error starting the VM $($VM.Name): " + $ErrorMessage
                # increase error count
                $errorCount++
                Break
            }
        }
        "Stop" {
            # Stop the VM
            try {
                Write-Output "Stopping VM $($VM.Name)..."
                $null = $VM | Stop-AzVM -ErrorAction Stop -Force -NoWait
            }
            catch {
                $ErrorMessage = $_.Exception.message
                Write-Error "Error stopping the VM $($VM.Name): " + $ErrorMessage
                # increase error count
                $errorCount++
                Break
            }
        }    
    }
}

$endOfScriptText = "Script ended at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
if ($errorCount -gt 0) {
    throw "Errors occured: $errorCount `r`n$endofScriptText"
}
Write-Output $endOfScriptText
