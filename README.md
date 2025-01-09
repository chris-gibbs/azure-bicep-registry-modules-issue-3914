# README - bicep-registry-modules/issues/3914 Sample

## Summary

Sample Bicep deployment for triggering bug referenced in [https://github.com/Azure/bicep-registry-modules/issues/3914](https://github.com/Azure/bicep-registry-modules/issues/3914)

## Deployment

```Powershell
az login
az account set subscription --name "__UPDATE__"

az deployment sub create --location 'australiaeast' --name 'deploy_synapse' --template-file .\lz.bicep
```

## Test Version

PS Z:\code\azure-bicep-registry-modules-issue-3914> az version
{
  "azure-cli": "2.51.0",
  "azure-cli-core": "2.51.0",
  "azure-cli-telemetry": "1.1.0",
  "extensions": {
    "databricks": "0.9.0",
    "datafactory": "0.7.0",
    "ml": "2.32.1",
    "notification-hub": "0.2.0",
    "resource-graph": "2.1.0"
  }
}

PS Z:\code\azure-bicep-registry-modules-issue-3914> az bicep version
Bicep CLI version 0.32.4 (b326faa456)
