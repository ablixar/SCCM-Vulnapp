# Check if the script is running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Relaunch the script with elevated privileges if not running as administrator
if (-not (Test-Administrator)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

# Prompt the user for the SQL Server, Database, API endpoint, Bearer token, and interval
$SqlServer = Read-Host -Prompt "Enter the SQL Server instance"
$Database = Read-Host -Prompt "Enter the Database name"
$APIEndpoint = Read-Host -Prompt "Enter the API endpoint"
$BearerToken = Read-Host -Prompt "Enter the Bearer token"

# Interval set to run every hour (60 minutes)
$IntervalMinutes = 60

# Define the directory and script path
$ProgramFilesPath = [System.Environment]::GetFolderPath('ProgramFiles')
$ScriptDir = Join-Path -Path $ProgramFilesPath -ChildPath "Vulnapp.ca"
$ScriptPath = Join-Path -Path $ScriptDir -ChildPath "ScheduledScript.ps1"

# Create the directory if it doesn't exist
if (-not (Test-Path -Path $ScriptDir)) {
    New-Item -ItemType Directory -Path $ScriptDir -Force
}

# Download the script
$ScriptUrl = "https://raw.githubusercontent.com/ablixar/SCCM-Vulnapp/main/ScheduledScript.ps1"
Invoke-WebRequest -Uri $ScriptUrl -OutFile $ScriptPath

# Read the downloaded script content
$ScriptContent = Get-Content -Path $ScriptPath

# Update the connection details in the script
$ScriptContent = $ScriptContent -replace 'SQL_Server', $SqlServer
$ScriptContent = $ScriptContent -replace 'Database', $Database
$ScriptContent = $ScriptContent -replace 'API_Endpoint', $APIEndpoint
$ScriptContent = $ScriptContent -replace 'Bearer_Token', $BearerToken

# Save the updated script
Set-Content -Path $ScriptPath -Value $ScriptContent

Write-Host "The script has been downloaded and updated successfully."
Write-Host "The script is located at: $ScriptPath"

# Define the scheduled task action
$actionParams = @{
    Execute = 'Powershell.exe'
    Argument = "-NoProfile -File `"$ScriptPath`""
}

$Action = New-ScheduledTaskAction @actionParams

# Define the scheduled task trigger to run every hour
$triggerParams = @{
    At = (Get-Date).AddMinutes(1)  # Start the task 1 minute from now
    Daily = $true
    DaysInterval = 1
}

$Trigger = New-ScheduledTaskTrigger @triggerParams

# Define the scheduled task settings
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

# Define the scheduled task principal
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Register the scheduled task
$TaskName = "RunScheduledScript"
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $settings -Principal $Principal

Write-Host "The scheduled task '$TaskName' has been created to run every hour."
Write-Host "Press Enter to exit."
[void][System.Console]::ReadLine()
