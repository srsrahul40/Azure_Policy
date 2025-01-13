function Login($clientId, $clientSecret, $tenantId) {
    $securePassword = ConvertTo-SecureString $clientSecret -AsPlainText -Force
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $clientId, $securePassword
    Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant $tenantId

}

function Invoke-MainFunction {
    # Import Inputs
    $jsonInputs = Get-Content -Raw -Path './input.json' | ConvertFrom-Json
    
    #Login
    Login -clientId $jsonInputs.SPN.client_id -clientSecret $jsonInputs.SPN.client_secret -tenantId $jsonInputs.tenant_id

    $directoryPath = ".\policyDefinitions" | Resolve-Path

    $location = $jsonInputs.location
    $managementGroupId = $jsonInputs.management_group_id

    # Process each file directly in the pipeline
    Get-ChildItem -Path $directoryPath -File | ForEach-Object {
        Write-Host "Processing file:" $_
        # Create the Azure Policy Definition    
        # New-AzDeployment -Location $location -TemplateFile $_.FullName -verbose
        New-AzManagementGroupDeployment -ManagementGroupId $managementGroupId -Location $location -TemplateFile $_.FullName -verbose
    }
}

Invoke-MainFunction