#Requires -Version 5
#Requires -RunAsAdministrator
#Requires -Modules ScheduledTasks
<#
.SYNOPSIS
  Google Cloud Example Agent installation script.
.DESCRIPTION
  This powershell script is used to install the Google Cloud Example Agent
  on the system and a Task Scheduler entry: google-cloud-example-agent-monitor (runs every min),
  .
#>
$ErrorActionPreference = 'Stop'
$INSTALL_DIR = 'C:\Program Files\Google\google-cloud-example-agent'
$SVC_NAME = 'google-cloud-example-agent'
$BIN_NAME_EXE = 'google-cloud-example-agent.exe'
$MONITOR_TASK = 'google-cloud-example-agent-monitor'
if ($env:ProgramData -eq $null -or $env:ProgramData -eq '') {
  $DATA_DIR = 'C:\Program Files\Google\google-cloud-example-agent'
}
else {
  $DATA_DIR = $env:ProgramData + '\Google\google-cloud-example-agent'
}
$LOGS_DIR = "$DATA_DIR\logs"
$CONF_DIR = "$INSTALL_DIR\conf"
$LOG_FILE ="$LOGS_DIR\google-cloud-example-agent-install.log"

function Log-Write {
  #.DESCRIPTION
  #  Writes to log file.
  param (
    [string] $log_message
  )
  Write-Host $log_message
  if (-not (Test-Path $LOGS_DIR)) {
    return
  }
  $time_stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $logFileSize = $(Get-Item $LOG_FILE -ErrorAction Ignore).Length/1kb
  if ($logFileSize -ge 1024) {
    Write-Host "Logfilesize: $logFileSize kb, rotating"
    Move-Item -Force $LOG_FILE "$LOG_FILE.1"
  }
  Add-Content -Value ("$time_stamp - $log_message") -path $LOG_FILE
}

function Log-Install {
  #.DESCRIPTION
  #  Invokes the service with usage logging enabled to log an install
  Start-Process $INSTALL_DIR\$BIN_NAME_EXE -ArgumentList 'logusage','-s','INSTALLED' | Wait-Process -Timeout 30
}

function CreateItem-IfNotExists {
  param (
    [string] $PathToCreate,
    [string] $TypeToCreate
  )
  if (-not (Test-Path $PathToCreate)) {
    Log-Write "Creating folder/contents: $PathToCreate"
    New-Item -ItemType $TypeToCreate -Path $PathToCreate
  }
}

function RemoveItem-IfExists {
  param (
    [string] $PathToRemove
  )
  if (Test-Path $PathToRemove) {
    Log-Write "Cleaning up prior folder/contents: $PathToRemove"
    # Left Overs, cleanup
    Remove-Item -Recurse -Force $PathToRemove
  }
}

function CreateInstall-Dirs {
  # Using -Force flag will not complain if the folder already exists.
  CreateItem-IfNotExists $INSTALL_DIR 'Directory'
  CreateItem-IfNotExists $LOGS_DIR 'Directory'
  CreateItem-IfNotExists $CONF_DIR 'Directory'
}

function ConfigureAgentWindows-Service {
  # Remove any existing service
  if ($(Get-Service -Name $SVC_NAME -ErrorAction SilentlyContinue).Length -gt 0) {
    Stop-Service $SVC_NAME
    $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='google-cloud-example-agent'"
    $service.Dispose()
    # without the ampersand PowerShell will block removal of the service for some time.
    & sc.exe delete $SVC_NAME
  }
  # Create a new service
  New-Service -Name $SVC_NAME -BinaryPathName '"C:\Program Files\Google\google-cloud-example-agent\google-cloud-example-agent.exe" winservice' -DisplayName 'Google Cloud Example Agent' -Description 'Google Cloud Example Agent' -StartupType Automatic
  Start-Service $SVC_NAME
}

function AddMonitor-Task {
  if ($(Get-ScheduledTask $MONITOR_TASK -ErrorAction Ignore).TaskName) {
     Log-Write "Scheduled task exists: $MONITOR_TASK"
     Unregister-ScheduledTask -TaskName $MONITOR_TASK -Confirm:$false
  }
  Log-Write "Adding scheduled task: $MONITOR_TASK"

  $action = New-ScheduledTaskAction `
    -Execute 'Powershell.exe' `
    -Argument "-File `"$INSTALL_DIR\google-cloud-example-agent-monitor.ps1`" -WindowStyle Hidden" `
    -WorkingDirectory $INSTALL_DIR
  $trigger = New-ScheduledTaskTrigger `
      -Once `
      -At (Get-Date) `
      -RepetitionInterval (New-TimeSpan -Minutes 1) `
      -RepetitionDuration (New-TimeSpan -Days (365 * 20))
  Register-ScheduledTask -Action $action -Trigger $trigger `
    -TaskName $MONITOR_TASK `
    -Description $MONITOR_TASK -User 'System'
  Log-Write "Added scheduled task: $MONITOR_TASK"
}

function  StopService-AndTasks {
  # Stop the service and task if they are running.
  if ($(Get-ScheduledTask $MONITOR_TASK -ErrorAction Ignore).TaskName) {
    Disable-ScheduledTask $MONITOR_TASK
  }
  if ($(Get-Service -Name $SVC_NAME -ErrorAction Ignore).Status) {
    Stop-Service $SVC_NAME
  }
}

function  StartService-AndTasks {
  Start-Service $SVC_NAME
  Enable-ScheduledTask $MONITOR_TASK
}

function MoveFiles-IntoPlace {
  if (-not (Test-Path "$INSTALL_DIR/conf/configuration.json")) {
    Move-Item -Force 'C:\Program Files\Google\google-cloud-example-agent\configuration.json' 'C:\Program Files\Google\google-cloud-example-agent\conf\configuration.json'
  }
}

$Success = $false
$Processing=$false
try {
  Log-Write 'Installing the Google Cloud Example Agent'
  CreateInstall-Dirs
  $Processing = $true;

  Log-Write 'Stopping running agent services...'
  StopService-AndTasks
  Log-Write 'Stopped running agent services'

  Log-Write 'Moving files into place...'
  MoveFiles-IntoPlace
  Log-Write 'File moves complete'

  Log-Write 'Configuring Windows service...'
  ConfigureAgentWindows-Service
  Log-Write 'Windows service configured'

  Log-Write 'Adding monitor task...'
  AddMonitor-Task
  Log-Write 'Monitor task added'

  $Success = $true
  Log-Write 'Successuflly installed the Google Cloud Example Agent'
  # log usage metrics for install
  Log-Install
}
catch {
  Log-Write $_.Exception|Format-List -force | Out-String
  break
}
Finally {
  # Try to start service and tasks again to make sure we are not leaving things inconsistent.
  try {
    if ($Processing -and !$Success) {
      StartService-AndTasks
    }
  }
  Finally {
  }
}
