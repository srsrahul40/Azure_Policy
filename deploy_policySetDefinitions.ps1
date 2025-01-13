function Login($clientId, $clientSecret, $tenantId) {
    $securePassword = ConvertTo-SecureString $clientSecret -AsPlainText -Force
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $clientId, $securePassword
    Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant $tenantId

}

function Generate-PolicySetTemplateFiles {
    param (
        [string]$inputDirectory,
        [string]$managementGroupId,
        [string]$outputDirectory
    )
    $inputDirectoryPath = $inputDirectory | Resolve-Path
    $outputDirectoryPath = "." | Resolve-Path
    $outputDirectoryPath = Join-Path -Path $outputDirectoryPath -ChildPath $outputDirectory
    
    if (-not (Test-Path $outputDirectoryPath)) {
        New-Item -ItemType Directory -Path $outputDirectoryPath
    }

    Get-ChildItem -Path $inputDirectoryPath -File | ForEach-Object {
        $policySetDefinition = Get-Content -Raw -Path $_.FullName
        $policySetDefinitionJson = $policySetDefinition | ConvertFrom-Json
        for($i=0; $i -lt $policySetDefinitionJson.resources[0].properties.policyDefinitions.Count; $i++) {
            # Write-Host $policySetDefinitionJson.resources[0].properties.policyDefinitions[$i].policyDefinitionId
            $policySetDefinitionJson.resources[0].properties.policyDefinitions[$i].policyDefinitionId = $policySetDefinitionJson.resources[0].properties.policyDefinitions[$i].policyDefinitionId.Replace("/providers/Microsoft.Management/managementGroups/contoso", "/providers/Microsoft.Management/managementGroups/$managementGroupId")
        }
        $policySetDefinitionJson | ConvertTo-Json -Depth 100 | Set-Content -Path (Join-Path -Path $outputDirectoryPath -ChildPath $_.Name)
    }
}

function Invoke-MainFunction {
    # Import Inputs
    $jsonInputs = Get-Content -Raw -Path './input.json' | ConvertFrom-Json
    
    #Login
    Login -clientId $jsonInputs.SPN.client_id -clientSecret $jsonInputs.SPN.client_secret -tenantId $jsonInputs.tenant_id

    Generate-PolicySetTemplateFiles -inputDirectory ".\policySetDefinitions" -managementGroupId $jsonInputs.management_group_id -outputDirectory "policySetDefinitionsOutput"

    $directoryPath = ".\policySetDefinitionsOutput" | Resolve-Path

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