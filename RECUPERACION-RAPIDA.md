# Recuperación rápida — Auri-Orion (Windows / túnel / Orion)
**Revisión:** 2026-10-27. Ejecutar cada bloque **en el equipo indicado**. Los reinicios solo se hacen si falla el paso de diagnóstico de esa capa.

## 0. Identificar la avería (sin modificar nada)

**Windows VM102 — PowerShell:**
```powershell
hostname
Get-Service Tailscale -ErrorAction SilentlyContinue | Select-Object Name,Status,StartType
Get-ScheduledTask -TaskName 'AO12-Tunnel','Orion-Abrir-Chrome' -ErrorAction SilentlyContinue | Select-Object TaskName,State
Get-ScheduledTaskInfo -TaskName 'AO12-Tunnel' -ErrorAction SilentlyContinue | Select-Object LastRunTime,LastTaskResult,NextRunTime
Get-NetTCPConnection -LocalPort 9777 -State Listen -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess
Test-NetConnection 127.0.0.1 -Port 9777
Get-Process chrome,ssh -ErrorAction SilentlyContinue | Select-Object ProcessName,Id
```
Si `Test-NetConnection` devuelve `TcpTestSucceeded=True` **solo confirma conexión TCP local**; aún falta validar Chrome y la extensión.

## 1. Windows VM102 — túnel y Chrome

**A. Tailscale / SSH**: verificar primero la red. No cambiar VPN, DNS, firewall ni llaves.
```powershell
Get-Service Tailscale -ErrorAction SilentlyContinue
& "$env:ProgramFiles\Tailscale\tailscale.exe" status
Get-ScheduledTask -TaskName 'AO12-Tunnel' | Format-List TaskName,State,TaskPath
Get-ScheduledTaskInfo -TaskName 'AO12-Tunnel' | Format-List
```
Si Tailscale está detenido y la instalación/ruta son las esperadas:
```powershell
Start-Service Tailscale   # requiere PowerShell elevado
Get-Service Tailscale
```
Si **AO12-Tunnel** está detenido o sin forward activo:
```powershell
Start-ScheduledTask -TaskName 'AO12-Tunnel'
Start-Sleep -Seconds 5
Get-ScheduledTaskInfo -TaskName 'AO12-Tunnel'
Test-NetConnection 127.0.0.1 -Port 9777
```
Si sigue fallando, comprobar sin exponer credenciales la acción configurada y el log:
```powershell
(Get-ScheduledTask -TaskName 'AO12-Tunnel').Actions | Format-List Execute,Arguments,WorkingDirectory
Get-Content 'C:\ProgramData\AuriOrionNode\tunnel.log' -Tail 50 -ErrorAction SilentlyContinue
```
**No crear un túnel adicional** sobre el mismo puerto si la tarea ya está activa. Tampoco reinstalar OpenSSH Server en Windows: es una conexión SSH **saliente** que usa un cliente.

**B. Chrome / extensión en VM102**:
```powershell
Get-ScheduledTask -TaskName 'Orion-Abrir-Chrome' -ErrorAction SilentlyContinue | Select-Object TaskName,State
Get-Process chrome -ErrorAction SilentlyContinue | Select-Object Id,ProcessName
```
Si no está abierto Chrome en la sesión interactiva:
```powershell
Start-ScheduledTask -TaskName 'Orion-Abrir-Chrome'
Start-Sleep -Seconds 5
Get-Process chrome -ErrorAction SilentlyContinue | Select-Object Id,ProcessName
```
Verificar en **Chrome de VM102**, perfil `Default`, extensión **Browser Session MCP v0.5.0** habilitada y conectada a `ws://127.0.0.1:9777`. Una tarea `Ready` es normal si ya terminó el arranque; revisar `LastTaskResult` y proceso real.

## 2. VM100 — OrionHub

**Consola Linux de VM100, como usuario `orion` (sin `sudo systemctl`):**
```bash
systemctl --user is-active orion-hub-ubuntu.service
systemctl --user status orion-hub-ubuntu.service --no-pager
journalctl --user -u orion-hub-ubuntu.service -n 60 --no-pager
curl --max-time 5 -sS http://127.0.0.1:8770/api/tools | head -c 500
ss -ltnp | grep -E ':8770|:9777' || true
```
Si el **hub** está caído:
```bash
systemctl --user restart orion-hub-ubuntu.service
systemctl --user is-active orion-hub-ubuntu.service
journalctl --user -u orion-hub-ubuntu.service -n 30 --no-pager
```
El MCP `mcp-server/index.js` y el adaptador `mcp_browser.py` **se gestionan desde Orion**; no iniciar manualmente otro Node en 9777. Si ese puerto aparece ocupado y hay conflicto, identificar el PID y su servicio antes de tocarlo:
```bash
ss -ltnp '( sport = :9777 )'
ps -ef | grep -E 'mcp-server/index.js|mcp_browser.py' | grep -v grep
```
No usar `fuser -k 9777/tcp` a ciegas.

## 3. Prueba de extremo a extremo

Con **CONTROL** en el estado autorizado por el propietario (no alterar el interruptor durante diagnóstico), usar la herramienta de **solo lectura** `ao12.browser.tabs_list` a través de Orion. Por ejemplo, desde VM100:
```bash
curl -sS --max-time 20 -X POST http://127.0.0.1:8770/api/run \
  -H 'Content-Type: application/json' \
  -d '{"tool":"ao12.browser.tabs_list","params":{}}'
```
**Éxito funcional:** respuesta OK con pestañas de **VM102** (comprobar `clientId`/navegador) y, si disponible, `event_id`. `403`/denegación CONTROL **no es fallo del túnel**. Un puerto abierto tampoco confirma que la extensión esté conectada. No ejecutar escrituras/clics de prueba sobre pestañas desconocidas.

## 4. Reinicio de Windows y fallos frecuentes

- **VM102 apagada/sesión no iniciada:** verificar encendido, inicio de sesión y el autoinicio real. Según el cierre 25/10, `Orion-Abrir-Chrome` abre Chrome unos 30 s después del login. No reiniciar Windows por un problema de túnel sin comprobar antes las capas.
- **Tailscale sin conexión:** comprobar servicio y estado `tailscale status` antes de reiniciar tareas.
- **Puerto 9777 abierto, pestañas vacías:** comprobar extensión, perfil `Default`, cliente/browser seleccionado y compatibilidad v0.5.0.
- **Orion responde pero el agente de Windows no:** distinguir Browser Bridge AO-12 de otros agentes Windows; consultar su nombre real de servicio/tarea, que no está demostrado en esta guía. No asumir que reiniciar `AO12-Tunnel` repara cualquier agente Windows.
- **Acceso SSH fallido:** conservar `known_hosts`, `StrictHostKeyChecking=yes`, y cuenta SYSTEM con sus claves existentes. No copiar claves de otro equipo.
- **Errores 502/503 del panel:** el panel `192.168.160.1:18900` es distinto del hub `127.0.0.1:8770`; diagnosticar por separado.

## 5. Información útil para escalar

Compartir **solo salida redactada** (sin secretos):
```powershell
Get-ScheduledTaskInfo AO12-Tunnel
Get-NetTCPConnection -LocalPort 9777 -State Listen -ErrorAction SilentlyContinue
Get-Service Tailscale
```
```bash
systemctl --user status orion-hub-ubuntu.service --no-pager
journalctl --user -u orion-hub-ubuntu.service -n 50 --no-pager
ss -ltnp | grep -E ':8770|:9777'
```

## Fuentes
- [Runbook AO-12](https://github.com/noralemilenio/auri-orion-browser-bridge/blob/main/docs/AO12-RUNBOOK.md)
- [Guía túneles Windows](https://github.com/noralemilenio/auri-orion-browser-bridge/blob/main/docs/AO12-GUIA-PORTATIL-ALE-Y-PC-NORMI.md)
- [Ficha infraestructura](https://github.com/noralemilenio/auri-orion-infrastructure/blob/main/docs/PROYECTOS/AO-12-BROWSER-BRIDGE-CIERRE-2026-10-17.md)
