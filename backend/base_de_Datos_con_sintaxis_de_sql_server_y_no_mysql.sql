create database if not exists Proyecto1;
use Proyecto1;


-- esquemas
create schema seguridad;
create schema personas;
create schema agenda;
create schema clinica;
create schema pagos;
create schema beneficios;
create schema notificaciones;
create schema auditoria;
create schema asistente;

-- ===== seguridad =====

-- roles del sistema (admin, profesional, recepcion...)
create table seguridad.Rol (
	id_rol int auto_increment primary key,
	nombre varchar(50) not null unique
)

-- usuarios con acceso al sistema, cada uno con un rol
create table seguridad.Usuario (
	id_usuario int auto_increment primary key,
	id_rol int not null,
	nombre_usuario varchar(50) not null unique,
	email varchar(100) not null unique,
	password_hash varchar(255) not null,
	activo bit not null default 1,
	fecha_creacion datetime not null default getdate(),
	FOREIGN KEY (id_rol) REFERENCES seguridad.Rol(id_rol)
)


-- ===== personas =====

-- pacientes, pueden o no tener usuario
create table personas.Paciente (
	id_paciente int primary key identity (1,1),
	id_usuario int,
	dni varchar(15) not null unique,
	nombre varchar(50) not null,
	apellido varchar(50) not null,
	fecha_nacimiento datetime not null,
	fecha_alta datetime not null default getdate(),
	email varchar(100),
	telegram_chat_id varchar(50),
	FOREIGN KEY (id_usuario) REFERENCES seguridad.Usuario(id_usuario)
)
go

-- telefonos de cada paciente
create table personas.TelefonoPaciente (
	id_telefono_paciente int primary key identity (1,1),
	id_paciente int not null,
	telefono varchar(30) not null,
	FOREIGN KEY (id_paciente) REFERENCES personas.Paciente(id_paciente)
)
go

-- profesionales, cada uno con su usuario
create table personas.Profesional (
	id_profesional int primary key identity (1,1),
	id_usuario int not null,
	matricula varchar(30) not null unique,
	nombre varchar(50) not null,
	apellido varchar(50) not null,
	email varchar(100),
	activo bit not null default 1,
	google_calendar_id varchar(255),
	FOREIGN KEY (id_usuario) REFERENCES seguridad.Usuario(id_usuario)
)
go

-- telefonos de cada profesional
create table personas.TelefonoProfesional (
	id_telefono_profesional int primary key identity (1,1),
	id_profesional int not null,
	telefono varchar(30) not null,
	FOREIGN KEY (id_profesional) REFERENCES personas.Profesional(id_profesional)
)
go

-- franjas horarias en las que atiende cada profesional
create table personas.Disponibilidad (
	id_disponibilidad int primary key identity (1,1),
	id_profesional int not null,
	fecha datetime not null,
	hora_inicio datetime not null,
	hora_fin datetime not null,
	activa bit not null default 1,
	FOREIGN KEY (id_profesional) REFERENCES personas.Profesional(id_profesional)
)
go

-- ===== clinica =====

-- categorias de protocolo, con su porcentaje de seña
create table clinica.CategoriaProtocolo (
	id_categoria int primary key identity (1,1),
	nombre varchar(100) not null unique,
	porcentaje_sena decimal(5,2) not null check (porcentaje_sena between 0 and 100),
	requiere_evaluacion bit not null default 0
)
go

-- protocolos (tratamientos), cada uno en una categoria
create table clinica.Protocolo (
	id_protocolo int primary key identity (1,1),
	id_categoria int not null,
	nombre varchar(100) not null,
	descripcion varchar(500),
	precio decimal(12,2) not null check (precio > 0),
	duracion_min int not null check (duracion_min > 0),
	activo bit not null default 1,
	FOREIGN KEY (id_categoria) REFERENCES clinica.CategoriaProtocolo(id_categoria)
)
go

-- protocolos que realiza cada profesional
create table clinica.ProfesionalProtocolo (
	id_profesional int not null,
	id_protocolo int not null,
	primary key (id_profesional, id_protocolo),
	FOREIGN KEY (id_profesional) REFERENCES personas.Profesional(id_profesional),
	FOREIGN KEY (id_protocolo) REFERENCES clinica.Protocolo(id_protocolo)
)
go

-- resultados posibles de una evaluacion previa
create table clinica.ResultadoEvaluacion (
	id_resultado int primary key identity (1,1),
	nombre varchar(50) not null unique
)
go

-- ===== agenda =====

-- estados de un turno (pendiente, confirmado, cancelado...)
create table agenda.EstadoTurno (
	id_estado_turno int primary key identity (1,1),
	nombre varchar(50) not null unique
)
go

-- por donde se origino la accion (web, telegram, recepcion...)
create table agenda.Origen (
	id_origen int primary key identity (1,1),
	nombre varchar(50) not null unique
)
go

-- turnos, la fk a evaluacion previa se agrega despues porque es circular
create table agenda.Turno (
	id_turno int primary key identity (1,1),
	id_paciente int not null,
	id_profesional int not null,
	id_estado_turno int not null,
	id_origen int not null,
	id_evaluacion_previa int,
	fecha_hora_inicio datetime not null,
	fecha_hora_fin datetime not null,
	fecha_creacion datetime not null default getdate(),
	google_event_id varchar(255),
	check (fecha_hora_fin > fecha_hora_inicio),
	FOREIGN KEY (id_paciente) REFERENCES personas.Paciente(id_paciente),
	FOREIGN KEY (id_profesional) REFERENCES personas.Profesional(id_profesional),
	FOREIGN KEY (id_estado_turno) REFERENCES agenda.EstadoTurno(id_estado_turno),
	FOREIGN KEY (id_origen) REFERENCES agenda.Origen(id_origen)
)
go

-- protocolos incluidos en cada turno, con el precio al momento de reservar
create table agenda.TurnoProtocolo (
	id_turno int not null,
	id_protocolo int not null,
	precio_aplicado decimal(12,2) not null check (precio_aplicado >= 0),
	primary key (id_turno, id_protocolo),
	FOREIGN KEY (id_turno) REFERENCES agenda.Turno(id_turno),
	FOREIGN KEY (id_protocolo) REFERENCES clinica.Protocolo(id_protocolo)
)
go

-- evaluaciones previas a un protocolo, ligadas a un turno
create table clinica.EvaluacionPrevia (
	id_evaluacion int primary key identity (1,1),
	id_turno int not null,
	id_protocolo int not null,
	id_resultado int,
	observaciones varchar(500),
	fecha_resultado datetime,
	fecha_reclamo datetime,
	FOREIGN KEY (id_turno) REFERENCES agenda.Turno(id_turno),
	FOREIGN KEY (id_protocolo) REFERENCES clinica.Protocolo(id_protocolo),
	FOREIGN KEY (id_resultado) REFERENCES clinica.ResultadoEvaluacion(id_resultado)
)
go

-- cierre de la relacion circular turno <-> evaluacion previa
alter table agenda.Turno add constraint FK_Turno_EvaluacionPrevia
	FOREIGN KEY (id_evaluacion_previa) REFERENCES clinica.EvaluacionPrevia(id_evaluacion)
go

-- ===== pagos =====

-- estados de un pago (pendiente, aprobado, reembolsado...)
create table pagos.EstadoPago (
	id_estado_pago int primary key identity (1,1),
	nombre varchar(50) not null unique
)
go

-- medios de pago disponibles
create table pagos.MedioPago (
	id_medio_pago int primary key identity (1,1),
	nombre varchar(50) not null unique
)
go

-- pagos de seña de cada turno
create table pagos.PagoSena (
	id_pago int primary key identity (1,1),
	id_turno int not null,
	id_estado_pago int not null,
	id_medio_pago int not null,
	monto decimal(12,2) not null check (monto > 0),
	fecha_pago datetime not null,
	codigo_operacion varchar(100),
	monto_reembolsado decimal(12,2) check (monto_reembolsado >= 0),
	fecha_resolucion datetime,
	FOREIGN KEY (id_turno) REFERENCES agenda.Turno(id_turno),
	FOREIGN KEY (id_estado_pago) REFERENCES pagos.EstadoPago(id_estado_pago),
	FOREIGN KEY (id_medio_pago) REFERENCES pagos.MedioPago(id_medio_pago)
)
go

-- tarjetas de regalo vendidas
create table pagos.TarjetaRegalo (
	id_tarjeta int primary key identity (1,1),
	id_medio_pago int not null,
	codigo varchar(50) not null unique,
	monto_inicial decimal(12,2) not null check (monto_inicial > 0),
	fecha_compra datetime not null,
	fecha_vencimiento datetime not null,
	comprador_nombre varchar(100),
	comprador_telefono varchar(30),
	FOREIGN KEY (id_medio_pago) REFERENCES pagos.MedioPago(id_medio_pago)
)
go

-- consumos de una tarjeta de regalo en un turno
create table pagos.MovimientoTarjeta (
	id_movimiento int primary key identity (1,1),
	id_tarjeta int not null,
	id_turno int not null,
	monto decimal(12,2) not null check (monto > 0),
	fecha_movimiento datetime not null default getdate(),
	FOREIGN KEY (id_tarjeta) REFERENCES pagos.TarjetaRegalo(id_tarjeta),
	FOREIGN KEY (id_turno) REFERENCES agenda.Turno(id_turno)
)
go

-- ===== beneficios =====

-- tipos de regla de beneficio
create table beneficios.TipoRegla (
	id_tipo_regla int primary key identity (1,1),
	nombre varchar(50) not null unique
)
go

-- reglas que generan cupones de descuento
create table beneficios.ReglaBeneficio (
	id_regla int primary key identity (1,1),
	id_tipo_regla int not null,
	nombre varchar(100) not null,
	umbral int not null check (umbral > 0),
	porcentaje_descuento decimal(5,2) not null check (porcentaje_descuento between 0 and 100),
	vigencia_semanas int not null check (vigencia_semanas > 0),
	activa bit not null default 1,
	ventana_dias int,
	FOREIGN KEY (id_tipo_regla) REFERENCES beneficios.TipoRegla(id_tipo_regla)
)
go

-- cupones emitidos a pacientes segun una regla
create table beneficios.Cupon (
	id_cupon int primary key identity (1,1),
	id_regla int not null,
	id_paciente int not null,
	id_turno int,
	codigo varchar(50) not null unique,
	secreto varchar(255) not null,
	porcentaje_descuento decimal(5,2) not null check (porcentaje_descuento between 0 and 100),
	fecha_emision datetime not null default getdate(),
	fecha_vencimiento datetime not null,
	FOREIGN KEY (id_regla) REFERENCES beneficios.ReglaBeneficio(id_regla),
	FOREIGN KEY (id_paciente) REFERENCES personas.Paciente(id_paciente),
	FOREIGN KEY (id_turno) REFERENCES agenda.Turno(id_turno)
)
go

-- ===== notificaciones =====

-- canales de envio (mail, telegram, sms...)
create table notificaciones.CanalNotificacion (
	id_canal int primary key identity (1,1),
	nombre varchar(50) not null unique
)
go

-- estados de una notificacion (pendiente, enviada, error...)
create table notificaciones.EstadoNotificacion (
	id_estado_notificacion int primary key identity (1,1),
	nombre varchar(50) not null unique
)
go

-- tipos de notificacion (recordatorio, confirmacion...)
create table notificaciones.TipoNotificacion (
	id_tipo_notificacion int primary key identity (1,1),
	nombre varchar(50) not null unique
)
go

-- notificaciones programadas y enviadas
create table notificaciones.Notificacion (
	id_notificacion int primary key identity (1,1),
	id_canal int not null,
	id_estado_notificacion int not null,
	id_tipo_notificacion int not null,
	id_paciente int,
	id_profesional int,
	id_turno int,
	mensaje varchar(1000) not null,
	fecha_programada datetime not null,
	intentos int not null default 0 check (intentos >= 0),
	fecha_envio datetime,
	detalle_error varchar(500),
	FOREIGN KEY (id_canal) REFERENCES notificaciones.CanalNotificacion(id_canal),
	FOREIGN KEY (id_estado_notificacion) REFERENCES notificaciones.EstadoNotificacion(id_estado_notificacion),
	FOREIGN KEY (id_tipo_notificacion) REFERENCES notificaciones.TipoNotificacion(id_tipo_notificacion),
	FOREIGN KEY (id_paciente) REFERENCES personas.Paciente(id_paciente),
	FOREIGN KEY (id_profesional) REFERENCES personas.Profesional(id_profesional),
	FOREIGN KEY (id_turno) REFERENCES agenda.Turno(id_turno)
)
go

-- ===== auditoria =====

-- tipos de evento que se registran en el log
create table auditoria.TipoEvento (
	id_tipo_evento int primary key identity (1,1),
	nombre varchar(50) not null unique,
	descripcion varchar(200)
)
go

-- log de eventos con valor anterior y nuevo
create table auditoria.Log (
	id_log int primary key identity (1,1),
	id_tipo_evento int not null,
	id_usuario int,
	id_paciente int,
	id_origen int not null,
	fecha_hora datetime not null default getdate(),
	descripcion varchar(500),
	ip_origen varchar(45),
	tabla_afectada varchar(100),
	id_registro_afectado int,
	valor_anterior varchar(max),
	valor_nuevo varchar(max),
	exitoso bit not null default 1,
	FOREIGN KEY (id_tipo_evento) REFERENCES auditoria.TipoEvento(id_tipo_evento),
	FOREIGN KEY (id_usuario) REFERENCES seguridad.Usuario(id_usuario),
	FOREIGN KEY (id_paciente) REFERENCES personas.Paciente(id_paciente),
	FOREIGN KEY (id_origen) REFERENCES agenda.Origen(id_origen)
)
go

-- ===== asistente =====

-- preguntas que los pacientes le hacen al asistente
create table asistente.ConsultaAsistente (
	id_consulta int primary key identity (1,1),
	id_paciente int,
	id_origen int not null,
	pregunta varchar(max) not null,
	fecha_hora datetime not null default getdate(),
	derivada bit not null default 0,
	respuesta varchar(max),
	FOREIGN KEY (id_paciente) REFERENCES personas.Paciente(id_paciente),
	FOREIGN KEY (id_origen) REFERENCES agenda.Origen(id_origen)
)
go
