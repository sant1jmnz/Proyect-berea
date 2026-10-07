# Arquitectura y contingencia (borrador)

Cómo se conectan las piezas y qué pasa cuando algo falla. Es un borrador:
varias decisiones están marcadas como pendientes.

## Piezas

| Pieza | Dónde corre | Para qué |
|---|---|---|
| **MySQL** | VM en la nube (Oracle Cloud, Ubuntu 24.04) | Fuente de verdad: turnos, pacientes, cupones, log |
| **n8n** (instalado en la VM) | La misma VM | Envía los recordatorios y orquesta los servicios externos |
| **Bot de Telegram** | Telegram | Canal de recordatorios en desarrollo y demo |
| **WhatsApp API oficial** | Meta | Canal de recordatorios en producción |
| **Google Calendar** | Google | Turno de la paciente y del profesional |
| **Asistente de IA** | Servicio externo | Consultas de las pacientes |
| **Apartados Cliente y Gestión** | PC / terminal del instituto (Qt) | Cargar y consultar turnos |
| **Sitio web** | Hosting a definir | Reserva y cuenta de la paciente |

La VM actual es una instancia Always Free de Oracle (`VM.Standard.E2.1.Micro`:
1 OCPU, 1 GB de RAM, Ubuntu 24.04, región Santiago).

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
| Se cae o reinicia la VM | Servicios que arrancan solos (systemd o Docker con reinicio automático) y aviso de caída con un monitor gratuito |
| Se pierde información de la VM | Respaldos automáticos de la base (volcado programado), copiados fuera de la VM |

La VM está en la nube, así que un corte de luz en el instituto no la afecta;
lo que sí afecta es que las PCs del instituto no puedan alcanzarla.

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

## Límites de la VM actual

Con 1 GB de RAM, MySQL y n8n juntos quedan muy justos. Habría que agregar
memoria de intercambio (swap) y ajustar MySQL para que consuma poco. Oracle
también ofrece instancias Always Free con más memoria (arquitectura ARM),
cuando hay disponibilidad. Además, Oracle puede reclamar instancias Always
Free que quedan inactivas mucho tiempo.

## Pendiente

- Decidir si la VM sigue siendo la actual o se usa una con más memoria.
- Definir cómo se conecta la app de escritorio (API o conexión cifrada).
- Definir el alcance del modo contingencia.
- Elegir el hosting del sitio web.
