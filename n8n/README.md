# Flujos de n8n

Dos flujos para importar en n8n (*Workflows → Import from File*). Toda la lógica está en la base
(stored procedures); n8n solo los dispara y manda los mensajes (ver `docs/12-contrato-sp.md`).

| Archivo | Cuándo corre | Qué hace |
|---|---|---|
| `enviar-avisos-telegram.workflow.json` | cada minuto | `sp_notificaciones_telegram(500)` → manda cada aviso por Telegram → `sp_marcar_notificacion(id, 'enviada')`. Si Telegram da error, o el chat no es un número, `sp_marcar_notificacion(id, 'fallida', motivo)` |
| `tareas-diarias.workflow.json` | todos los días a las 3:00 | `sp_vencer_evaluaciones` (evaluaciones de 6 meses) y `sp_emitir_cupones` (fidelidad), en paralelo |

## Para usarlos

1. Crear el usuario `dermalia_n8n` (`backend/08_usuarios.sql`, con otra contraseña) y una credencial *MySQL* en n8n con él.
2. Crear una credencial *Telegram* con el token del bot (@BotFather).
3. En cada nodo MySQL y Telegram elegir esas credenciales, y activar el flujo.
4. En `web/.env` poner `TELEGRAM_ENVIOS=n8n` (la API deja de mandar los avisos y solo atiende la conversación
   del bot) y, si también corre `tareas-diarias`, `TAREAS_DIARIAS=n8n`. Sin esas variables la API hace todo sola y
   **no hay que importar nada**: estos flujos son una alternativa, no un requisito.

## Cómo se comporta (probado)

- **Aviso enviado:** queda `enviada`.
- **Telegram da error** (chat inexistente, bot bloqueado): rama de error del nodo → `fallida` con el motivo. El SP
  lo deja `pendiente` y reintenta en la próxima vuelta; al tercer intento queda `fallida` definitivo.
- **Chat inventado** (por ejemplo `abc` o los `tg00005` de los datos de prueba): no se llama a Telegram, se marca
  `fallida` con "El chat de Telegram no es válido".

## Detalles de n8n 1.x que hay que respetar

- Los parámetros del nodo MySQL son `$1`, `$2`…, no `?`. Con `?` el valor no se reemplaza.
- `queryReplacement` debe dar un texto o una lista: un número suelto da error. Por eso es `={{ [valor] }}`.
- Un `CALL` llega como `[filas, paquete OK]`: el nodo *Avisos de Telegram pendientes* (Code) aplana las filas.

## Cómo se probó

n8n 1.123 y MySQL 8.4 en Docker, con un Telegram falso (`baseUrl` de la credencial apuntando a un servidor local
que contesta 200, y 400 "chat not found" para un chat dado). Se sembraron tres avisos (chat válido, chat que
Telegram rechaza, chat `abc`) y se comprobó en `notificaciones.Notificacion` el estado de cada uno. Las tareas
diarias se corrieron con el cron cambiado a cada minuto y se vieron los dos `CALL` en el log de MySQL.
**No se probó con un bot real de Telegram.**

**WhatsApp.** Los avisos de WhatsApp los manda la recepción con un enlace `wa.me` desde la pantalla Avisos de
Gestión. Con la API oficial de Meta se reemplazaría ese paso por el nodo de WhatsApp Business.
