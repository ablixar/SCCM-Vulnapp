# Define your SQL Server connection details
$SqlServer = "SQL_Server"
$Database = "Database"
# API Endpoint
$APIEndpoint = 'API_Endpoint'

# Bearer Token for authentication
$BearerToken = 'Bearer_Token'

$SQLQuery = @"
SELECT DISTINCT
    SYS.Name0,
    IP.IP_Addresses0 AS 'IP Address',
    ARP.DisplayName0 AS program,
    ARP.Version0 AS version
FROM
    v_Add_Remove_Programs ARP
    JOIN v_R_System SYS ON ARP.ResourceID = SYS.ResourceID
    JOIN dbo.v_RA_System_IPAddresses IP ON SYS.ResourceID = IP.ResourceID
WHERE
    CHARINDEX(':', IP.IP_Addresses0) = 0 -- Filter for IPv4 addresses only
ORDER BY
    SYS.Name0
"@

# Execute the SQL query using Invoke-Sqlcmd
$results = Invoke-Sqlcmd -ServerInstance $SqlServer -Database $Database -Query $SQLQuery

# Create an array to store JSON objects
$jsonDataArray = @()

# Populate the array with custom objects, skipping objects where both program and version are null
$results | ForEach-Object {
    if ($_.Name0 -ne $null -and ($_.program -ne $null -or $_.version -ne $null)) {
        $jsonObject = [PSCustomObject]@{
            computer_name = $_.Name0
            ip_address = $_.'IP Address'
            program = $_.program
            version = $_.version
        }
        $jsonDataArray += $jsonObject
    }
}

# Convert the array to JSON format
$jsonResults = $jsonDataArray | ConvertTo-Json

Write-Host $jsonResults
# Send JSON data to the API endpoint in a loop
while ($true) {
    try {
        $response = Invoke-RestMethod -Uri $APIEndpoint -Method Post -Body $jsonResults -ContentType 'application/json' -Headers @{ Authorization = "Bearer $BearerToken" }
        Write-Host "Request successful. Response:"
        Write-Host $response
    } catch {
        Write-Host "Request failed with status code: $($_.Exception.Response.StatusCode.value__)"
        Write-Host $_.Exception.Response.Content
    }

    # Sleep for 5 minutes
    Start-Sleep -Seconds (5 * 60)
}
