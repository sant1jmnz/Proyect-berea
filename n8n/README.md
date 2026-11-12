# Flujos de n8n

Dos flujos para importar en n8n (menú *Workflows → Import from File*). Toda la lógica está en la
base (stored procedures); n8n solo los dispara y manda los mensajes
(ver `docs/arquitectura.md` y `docs/12-contrato-sp.md`).

| Archivo | Cuándo corre | Qué hace |
|---|---|---|
| `enviar-avisos.workflow.json` | cada 5 minutos | `sp_notificaciones_pendientes` → manda cada aviso por Telegram → `sp_marcar_notificacion(..., 'enviada')` |
| `tareas-diarias.workflow.json` | todos los días a las 3:00 | `sp_vencer_evaluaciones` (evaluaciones de 6 meses) y `sp_emitir_cupones` (fidelidad) |

**Para usarlos**

1. Crear el usuario `dermalia_n8n` (`backend/08_usuarios.sql`, con otra contraseña) y una credencial *MySQL* en n8n con él.
2. Crear una credencial *Telegram* con el token del bot (BotFather).
3. En cada nodo, elegir esas credenciales y activar el flujo.

**Cómo funciona un aviso que falla.** Si el envío por Telegram da error, el nodo sigue (`continueOnFail`) y el
aviso no se marca como enviado: queda pendiente y se reintenta en la próxima vuelta. Para que la base cuente los
intentos, agregar una rama de error que llame a `sp_marcar_notificacion(id, 'fallida', 'motivo')`; al tercer
intento fallido pasa a *fallida*.

**WhatsApp.** En desarrollo los avisos de WhatsApp los manda la recepción con un enlace `wa.me` desde la
pantalla Avisos de Gestión (nodo *Aviso asistido*, que no envía nada). Con la API oficial de Meta se reemplaza
ese nodo por el de WhatsApp Business.

> **Estado:** las plantillas **no se probaron contra una instancia de n8n** (en este entorno no hay una);
> los procedimientos que llaman sí están probados (`backend/05_pruebas_sp.sql`, sección N). Al importarlas hay que
> revisar los nodos y las credenciales.
