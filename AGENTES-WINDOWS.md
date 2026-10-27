# Recuperación de agentes Windows de Orion (distintos de AO-12)

**Observación real 27-10-2026:** `agents.presence` devolvió **3 agentes offline**: `PC-NORMI` (hostname `NORMI-PC`), `PORTATIL-ALE` (`LT-MASENJO`) y `WINDOWS-VM102` (`NORALE-PC`). Versión declarada `1.1.0`, protocolo `orion-agent/1`. Últimos heartbeats registrados: 23/10/2026 20:07:33, 21:23:59 y 21:24:06 UTC respectivamente. OrionHub respondió `ok=true` y dispone de herramientas remotas; **no implica que los agentes estén conectados**. Evento de la consulta: `458845`.

## Primera distinción

- **Agente Windows Orion:** emite heartbeats a Orion. Evidencia de servicio: `agents.presence`.
- **AO-12 Browser Bridge:** túnel SSH `AO12-Tunnel` + extensión Chrome + servidor MCP. Evidencia: `ao12.browser.tabs_list`.
- No resolver una caída de heartbeat únicamente con reiniciar el túnel AO-12: son canales distintos.

## Comprobación inicial desde Orion

Usar herramienta READ_ONLY `agents.presence` desde el catálogo de Orion para ver si los agentes reaparecen. Si `online=false`, el acceso remoto a ese nodo puede fallar; los comandos siguientes requieren consola local, RDP o acceso autorizado al Windows afectado.

## PowerShell LOCAL de cada Windows afectado

1. Confirmar equipo, red y estado general:
```powershell
hostname
Get-Date
Get-NetIPConfiguration | Select-Object InterfaceAlias,IPv4Address,IPv4DefaultGateway
Get-Service | Where-Object { $_.Name -match 'orion|auri|tailscale' -or $_.DisplayName -match 'orion|auri|tailscale' } | Select-Object Name,DisplayName,Status,StartType
Get-ScheduledTask | Where-Object { $_.TaskName -match 'orion|auri|agent' } | Select-Object TaskName,TaskPath,State
Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'python|node|agent|orion' } | Select-Object ProcessId,Name,ExecutablePath
```
2. Ver tareas recientes sin alterar su estado:
```powershell
Get-ScheduledTask | Where-Object { $_.TaskName -match 'orion|auri|agent' } | ForEach-Object { Get-ScheduledTaskInfo -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue | Select-Object TaskName,LastRunTime,LastTaskResult }
```
3. Consultar eventos del Administrador de control de servicios:
```powershell
Get-WinEvent -FilterHashtable @{ LogName='System'; ProviderName='Service Control Manager'; StartTime=(Get-Date).AddDays(-1) } -MaxEvents 30 -ErrorAction SilentlyContinue | Select-Object TimeCreated,Id,LevelDisplayName,Message
```
4. **Solo si identificaste el nombre exacto del servicio Orion y está detenido**, arrancarlo y validar:
```powershell
# Sustituir el marcador por el nombre REAL detectado, no adivinarlo.
$serviceName = '<NOMBRE_REAL_SERVICIO_AGENTE>'
Get-Service -Name $serviceName
Start-Service -Name $serviceName
Get-Service -Name $serviceName
```
5. **Si el agente está instalado como tarea programada** y la identificación es inequívoca:
```powershell
$taskName = '<NOMBRE_REAL_TAREA_AGENTE>'
Get-ScheduledTask -TaskName $taskName
Start-ScheduledTask -TaskName $taskName
Get-ScheduledTaskInfo -TaskName $taskName
```

**No ejecutar bloques 4 o 5 con los marcadores sin sustituir.** No hay evidencia consolidada aquí del nombre exacto del proceso/servicio de los tres agentes, ni de su endpoint de heartbeat; es deliberado no inventarlo. No borrar directorios de programas, no reinstalar, no desactivar antivirus/firewall, no abrir puertos, no resetear claves ni modificar CONTROL.

## Comprobación final

Desde Orion repetir `agents.presence`: el equipo recuperado debe tener `online=true` y `last_seen` reciente. Después probar `windows.remote.info` o `windows.remote.health` como READ_ONLY seleccionando el `host_id` correcto según el contrato de la herramienta. Una entrada en catálogo o un puerto TCP abierto no demuestran recuperación del agente.

### Escalado de diagnóstico

Si todos siguen offline, comprobar **conectividad y servicio receptor/registro de heartbeats en Orion** antes de reiniciar los tres equipos por separado. Si el hub responde, ello demuestra solo su API, no el canal de presencia. Adjuntar logs *depurados* y diferenciar `offline`, error de autenticación, error DNS y denegación CONTROL.

## Documentación relacionada

- [Recuperación AO-12 y OrionHub](RECUPERACION-RAPIDA.md)
- [Runbook Browser Bridge](https://github.com/noralemilenio/auri-orion-browser-bridge/blob/main/docs/AO12-RUNBOOK.md)
