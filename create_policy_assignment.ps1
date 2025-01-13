function Login($clientId, $clientSecret, $tenantId) {
    $securePassword = ConvertTo-SecureString $clientSecret -AsPlainText -Force
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $clientId, $securePassword
    Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant $tenantId
}

function Get-RequestHeader {
    $token = (Get-AzAccessToken).token    
    return @{   
        'Authorization' = "Bearer $token"
    }
}

function Create-PolicyAssignment {
    param (
        [string] $filePath,
        [string] $scope,
        [string] $policyDefinitionScope,
        [object] $headers
    )

    $policyAssignment = Get-Content -Raw -Path $filePath | ConvertFrom-Json
    $apiVersion = $policyAssignment.apiVersion

    # pre process
    $policyAssignment.PSObject.Properties.Remove("apiVersion")
    $policyAssignment.PSObject.Properties.Remove("dependsOn")
    $policyAssignment.location = "uaenorth"

    $policyAssignment.properties.scope = $scope
    $policyAssignment.properties.policyDefinitionId = $policyAssignment.properties.policyDefinitionId.Replace("/providers/Microsoft.Management/managementGroups/placeholder", $policyDefinitionScope)

    Deploy-PolicyAssignment -scope $scope -policyAssignment $policyAssignment -apiVersion $apiVersion -headers $headers
}

function Deploy-PolicyAssignment {
    param(
        [string] $scope,
        [object] $policyAssignment,
        [string] $apiVersion,
        [object] $headers
    )

    
    Write-Host $policyAssignment.properties.policyDefinitionId
    Write-Host $scope

    $policyAssignmentName = $policyAssignment.name
    $policyAssignment = $policyAssignment | ConvertTo-Json -Depth 10
    Write-Host "Deploying Policy Assignment: $policyAssignmentName"
    $url = "https://management.azure.com$scope/providers/Microsoft.Authorization/policyAssignments/"+$policyAssignmentName+"?api-version=$apiVersion"
    try {
        Invoke-WebRequest -Method Put -Uri $url -Headers $headers -Body $policyAssignment -ContentType "application/json"
    }
    catch {
        Write-Error "Failed to deploy policy assignment: $policyAssignmentName"
        Write-Error $_
    }
    # Write-Host $url
    # Write-Host $policyAssignment.properties.policyDefinitionId
    # Write-Host $scope
    # Write-Host $policyAssignment.GetType()
}

function Invoke-MainFunction {
    # Import Inputs
    $jsonInputsPath = ".\input.json" | Resolve-Path
    $jsonInputs = Get-Content -Raw -Path $jsonInputsPath | ConvertFrom-Json

    $policyAssignmentMapPath = ".\policyAssignmentMap.json" | Resolve-Path
    $policyAssignmentMap = Get-Content -Raw -Path $policyAssignmentMapPath | ConvertFrom-Json

    #Login
    Login -clientId $jsonInputs.SPN.client_id -clientSecret $jsonInputs.SPN.client_secret -tenantId $jsonInputs.tenant_id

    $policyDefinitionScope = "/providers/Microsoft.Management/managementGroups/"+$jsonInputs.management_group_id

    $headers = Get-RequestHeader
    # Iterate over every management group
    foreach ($archeType in $policyAssignmentMap.archeTypeMGMap) {
        $scope = $archeType.managementGroupId
        $archeTypeList = $archeType.archetypes
        Write-Host "Processing Management Group: $scope"
        
        # Iterate over every archeType in the management group
        foreach($innerArcheType in $archeTypeList) {
            Write-Host "Processing ArcheType: $innerArcheType"
            $assignmentList = $policyAssignmentMap.archeTypePolicyAssignmentMap.$innerArcheType
            
            # Iterate over every policy assignment in the archeType
            foreach($archeTypeName in $assignmentList) {
                $policyAssignmentFilePath = ".\policyAssignments\$($archeTypeName).alz_policy_assignment.json" | Resolve-Path
                Create-PolicyAssignment -filePath $policyAssignmentFilePath -scope $scope -headers $headers -policyDefinitionScope $policyDefinitionScope
            }
        }
    }
    
}

Invoke-MainFunction