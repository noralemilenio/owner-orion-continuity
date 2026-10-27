# Owner · Orion Continuity — Manual de recuperación

**Última revisión documental:** 2026-10-27. **Alcance:** procedimientos de diagnóstico y recuperación local, sin cambiar CONTROL, credenciales, ACL, puertos públicos o topología.

> 🛟 **Si no llegan los agentes de Windows:** empieza por [RECUPERACION-RAPIDA.md](RECUPERACION-RAPIDA.md). La documentación de AO-12 acredita VM102; no presupone que PC-NORMI o PORTATIL-ALE tengan despliegue idéntico.

## Acceso inmediato

| Síntoma | Dónde empezar |
| --- | --- |
| Auri no ve Chrome/Windows VM102 | [Diagnóstico y reinicio AO-12](RECUPERACION-RAPIDA.md#1-windows-vm102--túnel-y-chrome) |
| Túnel SSH caído | [Windows: tarea AO12-Tunnel](RECUPERACION-RAPIDA.md#1-windows-vm102--túnel-y-chrome) |
| OrionHub no responde | [VM100: OrionHub](RECUPERACION-RAPIDA.md#2-vm100--orionhub) |
| Hay puerto 9777, pero no pestañas | [Verificación de extremo a extremo](RECUPERACION-RAPIDA.md#3-prueba-de-extremo-a-extremo) |
| No se sabe qué componente falló | [Script PowerShell de solo lectura](scripts/Test-AuriOrion-Windows.ps1) |
| Caída tras reinicio de Windows | [Autologin/Chrome y tareas](RECUPERACION-RAPIDA.md#4-reinicio-de-windows-y-fallos-frecuentes) |

## Infraestructura documentada

- **VM100 / Orion**: OrionHub en `127.0.0.1:8770`; servicio systemd de usuario `orion-hub-ubuntu.service`; panel separado en `192.168.160.1:18900`. No confundir panel y hub.
- **Windows VM102**: tarea `AO12-Tunnel` (cuenta SYSTEM), tarea `Orion-Abrir-Chrome` tras inicio de sesión, Chrome con extensión Browser Session MCP 0.5.0.
- **Browser Bridge**: servidor MCP Node gestionado por `mcp_browser.py`, escucha Orion `127.0.0.1:9777`; Windows usa SSH **saliente** sobre Tailscale y un forward loopback `127.0.0.1:9777`.
- **CONTROL**: único interruptor maestro vigente; los demás controles de documentos antiguos son históricos. **No activarlo ni eludirlo como procedimiento de rescate**.
- **Otros nodos**: PORTATIL-ALE / PC-NORMI no tienen la misma implantación demostrada que VM102. Revisar nombres de tareas y servicios reales antes de replicar comandos.

## Política de operaciones

1. **Diagnosticar** sin cambios.
2. **Reiniciar solo el componente fallido** con comandos explícitos. No usar `taskkill` global, `fuser -k`, reinicios de VM ni reinstalaciones como primer recurso.
3. **Verificar funcionalmente** una herramienta `ao12.browser.tabs_list` autorizada y registrar resultado.
4. **Escalar** con salida de `Get-ScheduledTaskInfo`, `Get-NetTCPConnection`, `journalctl` y herramientas Orion si el error persiste.
5. Nunca subir logs con claves, tokens o cookies al repo. No modificar firewall/VPN/SSH ni comprobaciones de host keys para recuperar.

## Fuentes técnicas

- [AO-12 Runbook](https://github.com/noralemilenio/auri-orion-browser-bridge/blob/main/docs/AO12-RUNBOOK.md)
- [AO-12 guía Windows / túnel seguro](https://github.com/noralemilenio/auri-orion-browser-bridge/blob/main/docs/AO12-GUIA-PORTATIL-ALE-Y-PC-NORMI.md)
- [AO-12 ficha de infraestructura](https://github.com/noralemilenio/auri-orion-infrastructure/blob/main/docs/PROYECTOS/AO-12-BROWSER-BRIDGE-CIERRE-2026-10-17.md)

**Estado:** guía y comprobador PowerShell publicados. No se ha realizado aquí un reinicio real ni una prueba operativa de los agentes Windows: hacerlo requiere ejecutar los comandos en sus máquinas.
