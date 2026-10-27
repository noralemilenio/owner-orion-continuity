#requires -Version 5.1
<#
.SYNOPSIS
 Diagnostico no destructivo del tunel AO-12 y Chrome en Windows VM102.
.DESCRIPTION
 Solo lectura. No reinicia servicios ni toca credenciales, firewall, CONTROL o VPN.
#>
$ErrorActionPreference = 'Continue'
Write-Host "=== Auri-Orion | comprobacion Windows | $(Get-Date -Format s) ==="
Write-Host "Equipo: $env:COMPUTERNAME"
Write-Host "Tailscale:"
Get-Service -Name Tailscale -ErrorAction SilentlyContinue | Select-Object Name,Status,StartType | Format-Table -AutoSize
$ts = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
if (Test-Path $ts) { & $ts status } else { Write-Warning 'No se encontro tailscale.exe en Program Files; verificar instalacion/ruta' }
foreach ($taskName in @('AO12-Tunnel','Orion-Abrir-Chrome')) {
  Write-Host "Tarea: $taskName"
  $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  if ($null -eq $task) { Write-Warning "Tarea no encontrada: $taskName"; continue }
  $task | Select-Object TaskName,State,TaskPath | Format-Table -AutoSize
  Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue |
    Select-Object LastRunTime,LastTaskResult,NextRunTime | Format-Table -AutoSize
}
Write-Host "Listener local 9777:"
Get-NetTCPConnection -LocalPort 9777 -State Listen -ErrorAction SilentlyContinue |
  Select-Object LocalAddress,LocalPort,OwningProcess | Format-Table -AutoSize
Write-Host "Prueba TCP localhost:9777:"
Test-NetConnection -ComputerName 127.0.0.1 -Port 9777 -InformationLevel Detailed |
  Select-Object ComputerName,RemotePort,TcpTestSucceeded | Format-List
Write-Host "Procesos browser/ssh:"
Get-Process chrome,ssh -ErrorAction SilentlyContinue |
  Select-Object ProcessName,Id | Format-Table -AutoSize
Write-Host "FIN. TCP OK no equivale a conexion funcional de extension. Comprobar tabs_list desde Orion."
