# Arquitectura y contingencia (borrador)

Cómo se conectan las piezas y qué pasa cuando algo falla. Es un borrador:
varias decisiones están marcadas como pendientes.

## Piezas

| Pieza | Dónde corre | Para qué |
|---|---|---|
| **MySQL** | VM 1 (Oracle Cloud, Ubuntu 24.04) | Fuente de verdad: turnos, pacientes, cupones, log |
| **n8n** | VM 2 (la otra instancia Always Free) | Envía los recordatorios y orquesta los servicios externos |
| **Bot de Telegram** | Telegram | Canal de recordatorios en desarrollo y demo |
| **WhatsApp API oficial** | Meta | Canal de recordatorios en producción |
| **Google Calendar** | Google | Turno de la paciente y del profesional |
| **Asistente de IA** | Servicio externo | Consultas de las pacientes |
| **Apartados Cliente y Gestión** | PC / terminal del instituto (Qt) | Cargar y consultar turnos |
| **Sitio web** | Hosting externo gratuito (no ocupa las VMs) | Reserva y cuenta de la paciente |

Se usan **las dos instancias Always Free** de Oracle (`VM.Standard.E2.1.Micro`:
1 OCPU, 1 GB de RAM cada una, Ubuntu 24.04, región Santiago), repartidas para
que ninguna quede justa: una solo para la base y otra solo para n8n.

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

## Reparto en dos VMs (para no quedar justos)

Con 1 GB de RAM por máquina, MySQL y n8n juntos quedaban muy ajustados. Por
eso van separados:

| VM | Corre | Ajustes |
|---|---|---|
| **VM 1** | MySQL | Memoria de intercambio (swap) y MySQL configurado para consumir poco (buffer de InnoDB reducido, `performance_schema` apagado) |
| **VM 2** | n8n | Swap, n8n con su base interna por defecto, sin servicios extra |

- Las dos VMs se comunican por su **red privada** (misma red virtual de
  Oracle); el puerto de MySQL solo se abre a la VM 2 y no a internet.
- El sitio web va en un hosting gratuito aparte, para no cargar las VMs.
- Los respaldos de la base se copian a la VM 2 y a un almacenamiento externo.
- Oracle puede reclamar instancias Always Free que queden inactivas mucho
  tiempo; el uso constante del proyecto lo evita.

## Pendiente

- Confirmar cuál de las dos instancias hace de VM 1 y cuál de VM 2, y que ninguna tenga otro servicio pesado (por ejemplo, un servidor de Minecraft).
- Definir cómo se conecta la app de escritorio (API o conexión cifrada).
- Definir el alcance del modo contingencia.
- Elegir el hosting del sitio web.
