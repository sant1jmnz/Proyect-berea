# Arquitectura y contingencia (borrador)

Cómo se conectan las piezas y qué pasa cuando algo falla. Es un borrador:
varias decisiones están marcadas como pendientes.

## Piezas

| Pieza | Dónde corre | Para qué |
|---|---|---|
| **MySQL** | **Aiven for MySQL**, plan gratuito (administrado, en la nube) | Fuente de verdad: turnos, pacientes, cupones, log |
| **n8n** | VM gratuita `e2-micro` de **Google Cloud** (región de EE. UU.) | Envía los recordatorios y orquesta los servicios externos |
| **Bot de Telegram** | Telegram | Canal de recordatorios en desarrollo y demo |
| **WhatsApp API oficial** | Meta | Canal de recordatorios en producción |
| **Google Calendar** | Google | Turno de la paciente y del profesional |
| **Asistente de IA** | Servicio externo | Consultas de las pacientes |
| **Apartados Cliente y Gestión** | PC / terminal del instituto (Qt) | Cargar y consultar turnos |
| **Sitio web** | Hosting externo gratuito | Reserva y cuenta de la paciente |

Decisión: **Aiven + Google Cloud**, sin las VMs de Oracle. La base y el
envío de recordatorios quedan en servicios distintos, así que la falla de uno
no tira al otro, y ninguna máquina queda justa de memoria.

## Recordatorios con n8n

1. Al agendar un turno, un stored procedure inserta filas en `Notificación`
   con estado *pendiente* y fecha programada.
2. n8n, con un disparador cada pocos minutos, llama a un stored procedure
   que devuelve las notificaciones pendientes cuya hora ya llegó.
3. Las envía por el canal que corresponda (Telegram, WhatsApp o Calendar).
4. Llama a otro stored procedure que las marca como *enviadas* o *fallidas*.

La lógica vive en la base (stored procedures); n8n solo la ejecuta. Cambiar de
Telegram a WhatsApp es cambiar un nodo.

### Vinculación con Telegram
Al terminar de reservar, el sistema muestra un botón o QR "Recibir
recordatorios por Telegram" que abre el bot con un código ya cargado
(`t.me/<bot>?start=<código>`). La paciente solo toca "Iniciar" y queda
vinculada. Si no lo hace, se usan los otros canales.

## Contingencia: internet, luz y caídas

Objetivo: que el instituto no deje de atender si falla algo.

| Falla | Qué se hace |
|---|---|
| Se corta la luz en el instituto | No-break (UPS) para la PC de recepción, el router y la terminal |
| Se cae el internet del instituto | Segunda conexión de respaldo (datos móviles del celular o router 4G) |
| La app no puede llegar a la base | **Modo contingencia** (ver abajo) |
| Se cae la VM de n8n o la base | n8n con reinicio automático (systemd o Docker) y aviso de caída con un monitor gratuito; Aiven mantiene sus propios respaldos |
| Se pierde información | Respaldos automáticos de Aiven, más un volcado propio programado y copiado fuera de la nube de la base |

La base y n8n están en la nube, así que un corte de luz en el instituto no
los afecta; lo que sí afecta es que las PCs del instituto no puedan
alcanzarlos.

### Modo contingencia de la app de escritorio
- La app detecta que no hay conexión y lo avisa con un cartel visible.
- Los turnos cargados mientras tanto se guardan localmente como *pendientes de
  sincronizar*.
- Al volver la conexión, se sincronizan y se vuelve a validar la
  disponibilidad; si hubo choques de horario, se avisan a recepción para
  resolverlos.
- Pendiente de decidir: cuánto de la agenda se guarda en la PC para poder
  mostrar horarios disponibles sin conexión.

## Seguridad

- La app de escritorio **no debería conectarse a MySQL abierto a internet**.
  Opciones: una pequeña API delante de la base, o una conexión cifrada (VPN o
  túnel) con el puerto de MySQL cerrado al público.
- Contraseñas y tokens fuera del repositorio.
- n8n protegido con usuario y contraseña, sin exponerlo sin autenticación.

## Servicios elegidos (gratuitos)

| Servicio | Qué ofrece el plan gratuito | Límites a tener en cuenta |
|---|---|---|
| **Aiven for MySQL** | 1 CPU, 1 GB de RAM, 1 GB de disco, respaldos incluidos; sin límite de tiempo ni tarjeta | Sin red privada ni IP fija, sin SLA; pueden apagarlo si queda sin uso |
| **Google Cloud `e2-micro`** | 1 VM siempre gratis, con 30 GB de disco | Gratis solo en 3 regiones de EE. UU.; 1 GB de tráfico saliente al mes; pide tarjeta para crear la cuenta |

Los planes gratuitos cambian: se verifican las condiciones al crear las
cuentas.

- n8n corre solo en la VM de Google, con swap, y consulta la base de Aiven
  por internet con conexión cifrada (TLS).
- Como la base está en la nube, un corte de luz o de internet en el instituto
  no frena los recordatorios.
- **Plan B** si no se puede crear la cuenta de Google (por la tarjeta): una
  tarea programada en GitHub Actions que corre un script cada 5 minutos con la
  misma consulta a los stored procedures. Es menos cómodo (no hay panel
  visual y las ejecuciones pueden demorarse), pero no necesita VM.
- **Desarrollo de la consigna de BBDD:** se hace con MySQL local; la base de
  Aiven es la de producción y demo.

## Pendiente

- Al crear la cuenta de Aiven, verificar que el usuario pueda crear stored
  procedures y eventos.
- Confirmar que se puede crear la cuenta de Google Cloud; si no, usar el plan B.
- Definir cómo se conecta la app de escritorio (API delante de la base o
  conexión cifrada con un usuario de permisos mínimos).
- Definir el alcance del modo contingencia.
- Elegir el hosting del sitio web.
