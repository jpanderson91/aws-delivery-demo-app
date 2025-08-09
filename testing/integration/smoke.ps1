# Simple smoke test for the deployed API (PowerShell)
# - Reads API URL from Terraform outputs
# - GET /customers
# - POST /customers
# - GET /customers again

param(
  [string]$ApiBase
)

$ErrorActionPreference = 'Stop'

function Fail($msg) {
  Write-Error $msg
  exit 1
}

try {
  $tfDir = Resolve-Path (Join-Path $PSScriptRoot '..\..\terraform')
  Push-Location $tfDir

  $api = $ApiBase
  if ([string]::IsNullOrWhiteSpace($api)) {
    $api = terraform output -raw api_invoke_url
  }
  if ([string]::IsNullOrWhiteSpace($api)) { Fail 'api_invoke_url output is empty. Did you deploy Terraform?' }
  Write-Host "API: $api"

  # Root HTML
  $root = Invoke-WebRequest -Uri $api -Method GET -UseBasicParsing
  if ($root.StatusCode -ne 200) { Fail "Root GET returned status $($root.StatusCode)" }

  # GET /customers
  $list1 = Invoke-RestMethod -Uri ("{0}/customers?limit=1" -f $api) -Method GET
  if ($null -eq $list1.count -or $null -eq $list1.items) { Fail 'GET /customers did not return expected shape.' }
  Write-Host "Initial count: $($list1.count)"

  # POST /customers
  $ts = [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
  $body = @{ name = "Smoke Tester"; email = "smoke+$ts@example.com"; company = "Acme Smoke" } | ConvertTo-Json
  $created = Invoke-RestMethod -Uri ("{0}/customers" -f $api) -Method POST -ContentType 'application/json' -Body $body
  if ([string]::IsNullOrWhiteSpace($created.customer_id)) { Fail 'POST /customers did not return customer_id.' }
  Write-Host "Created: $($created.customer_id)"

  # GET /customers again
  $list2 = Invoke-RestMethod -Uri ("{0}/customers?limit=10" -f $api) -Method GET
  if ($null -eq $list2.count -or $null -eq $list2.items) { Fail 'Second GET /customers failed.' }
  Write-Host "Final count: $($list2.count)"

  Pop-Location
  Write-Host 'Smoke test PASSED.'
  exit 0
}
catch {
  Write-Error $_
  try { Pop-Location } catch {}
  exit 1
}
