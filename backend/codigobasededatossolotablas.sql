CREATE DATABASE IF NOT EXISTS Proyecto1;
USE Proyecto1;

-- Borrado de tablas (de hijas a padres) con prefijos
DROP TABLE IF EXISTS asistente_ConsultaAsistente;
DROP TABLE IF EXISTS auditoria_Log;
DROP TABLE IF EXISTS auditoria_TipoEvento;
DROP TABLE IF EXISTS notificaciones_Notificacion;
DROP TABLE IF EXISTS notificaciones_TipoNotificacion;
DROP TABLE IF EXISTS notificaciones_EstadoNotificacion;
DROP TABLE IF EXISTS notificaciones_CanalNotificacion;
DROP TABLE IF EXISTS beneficios_Cupon;
DROP TABLE IF EXISTS beneficios_ReglaBeneficio;
DROP TABLE IF EXISTS beneficios_TipoRegla;
DROP TABLE IF EXISTS pagos_MovimientoTarjeta;
DROP TABLE IF EXISTS pagos_TarjetaRegalo;
DROP TABLE IF EXISTS pagos_PagoSena;
DROP TABLE IF EXISTS pagos_MedioPago;
DROP TABLE IF EXISTS pagos_EstadoPago;
DROP TABLE IF EXISTS agenda_TurnoProtocolo;
DROP TABLE IF EXISTS clinica_EvaluacionPrevia;
DROP TABLE IF EXISTS agenda_Turno;
DROP TABLE IF EXISTS agenda_Origen;
DROP TABLE IF EXISTS agenda_EstadoTurno;
DROP TABLE IF EXISTS clinica_ResultadoEvaluacion;
DROP TABLE IF EXISTS clinica_ProfesionalProtocolo;
DROP TABLE IF EXISTS clinica_Protocolo;
DROP TABLE IF EXISTS clinica_CategoriaProtocolo;
DROP TABLE IF EXISTS personas_Disponibilidad;
DROP TABLE IF EXISTS personas_TelefonoProfesional;
DROP TABLE IF EXISTS personas_Profesional;
DROP TABLE IF EXISTS personas_TelefonoPaciente;
DROP TABLE IF EXISTS personas_Paciente;
DROP TABLE IF EXISTS seguridad_Usuario;
DROP TABLE IF EXISTS seguridad_Rol;


-- ===== seguridad =====

CREATE TABLE seguridad_Rol (
    id_rol INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE seguridad_Usuario (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    id_rol INT NOT NULL,
    nombre_usuario VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    activo TINYINT NOT NULL DEFAULT 1,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_Usuario_Rol FOREIGN KEY (id_rol) REFERENCES seguridad_Rol(id_rol)
);


-- ===== personas =====

CREATE TABLE personas_Paciente (
    id_paciente INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NULL,
    dni VARCHAR(15) NOT NULL UNIQUE,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    fecha_nacimiento DATETIME NOT NULL,
    fecha_alta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    email VARCHAR(100),
    telegram_chat_id VARCHAR(50),
    CONSTRAINT FK_Paciente_Usuario FOREIGN KEY (id_usuario) REFERENCES seguridad_Usuario(id_usuario)
);

CREATE TABLE personas_TelefonoPaciente (
    id_telefono_paciente INT AUTO_INCREMENT PRIMARY KEY,
    id_paciente INT NOT NULL,
    telefono VARCHAR(30) NOT NULL,
    CONSTRAINT FK_TelefonoPaciente_Paciente FOREIGN KEY (id_paciente) REFERENCES personas_Paciente(id_paciente)
);

CREATE TABLE personas_Profesional (
    id_profesional INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    matricula VARCHAR(30) NOT NULL UNIQUE,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    activo TINYINT NOT NULL DEFAULT 1,
    google_calendar_id VARCHAR(255),
    CONSTRAINT FK_Profesional_Usuario FOREIGN KEY (id_usuario) REFERENCES seguridad_Usuario(id_usuario)
);

CREATE TABLE personas_TelefonoProfesional (
    id_telefono_profesional INT AUTO_INCREMENT PRIMARY KEY,
    id_profesional INT NOT NULL,
    telefono VARCHAR(30) NOT NULL,
    CONSTRAINT FK_TelefonoProfesional_Profesional FOREIGN KEY (id_profesional) REFERENCES personas_Profesional(id_profesional)
);

CREATE TABLE personas_Disponibilidad (
    id_disponibilidad INT AUTO_INCREMENT PRIMARY KEY,
    id_profesional INT NOT NULL,
    fecha DATETIME NOT NULL,
    hora_inicio DATETIME NOT NULL,
    hora_fin DATETIME NOT NULL,
    activa TINYINT NOT NULL DEFAULT 1,
    CONSTRAINT FK_Disponibilidad_Profesional FOREIGN KEY (id_profesional) REFERENCES personas_Profesional(id_profesional)
);


-- ===== clinica =====

CREATE TABLE clinica_CategoriaProtocolo (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    porcentaje_sena DECIMAL(5,2) NOT NULL CHECK (porcentaje_sena BETWEEN 0 AND 100),
    requiere_evaluacion TINYINT NOT NULL DEFAULT 0
);

CREATE TABLE clinica_Protocolo (
    id_protocolo INT AUTO_INCREMENT PRIMARY KEY,
    id_categoria INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(500),
    precio DECIMAL(12,2) NOT NULL CHECK (precio > 0),
    duracion_min INT NOT NULL CHECK (duracion_min > 0),
    activo TINYINT NOT NULL DEFAULT 1,
    CONSTRAINT FK_Protocolo_Categoria FOREIGN KEY (id_categoria) REFERENCES clinica_CategoriaProtocolo(id_categoria)
);

CREATE TABLE clinica_ProfesionalProtocolo (
    id_profesional INT NOT NULL,
    id_protocolo INT NOT NULL,
    PRIMARY KEY (id_profesional, id_protocolo),
    CONSTRAINT FK_ProfesionalProtocolo_Profesional FOREIGN KEY (id_profesional) REFERENCES personas_Profesional(id_profesional),
    CONSTRAINT FK_ProfesionalProtocolo_Protocolo FOREIGN KEY (id_protocolo) REFERENCES clinica_Protocolo(id_protocolo)
);

CREATE TABLE clinica_ResultadoEvaluacion (
    id_resultado INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);


-- ===== agenda =====

CREATE TABLE agenda_EstadoTurno (
    id_estado_turno INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE agenda_Origen (
    id_origen INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE agenda_Turno (
    id_turno INT AUTO_INCREMENT PRIMARY KEY,
    id_paciente INT NOT NULL,
    id_profesional INT NOT NULL,
    id_estado_turno INT NOT NULL,
    id_origen INT NOT NULL,
    id_evaluacion_previa INT NULL,
    fecha_hora_inicio DATETIME NOT NULL,
    fecha_hora_fin DATETIME NOT NULL,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    google_event_id VARCHAR(255),
    CONSTRAINT CK_Turno_Fechas CHECK (fecha_hora_fin > fecha_hora_inicio),
    CONSTRAINT FK_Turno_Paciente FOREIGN KEY (id_paciente) REFERENCES personas_Paciente(id_paciente),
    CONSTRAINT FK_Turno_Profesional FOREIGN KEY (id_profesional) REFERENCES personas_Profesional(id_profesional),
    CONSTRAINT FK_Turno_EstadoTurno FOREIGN KEY (id_estado_turno) REFERENCES agenda_EstadoTurno(id_estado_turno),
    CONSTRAINT FK_Turno_Origen FOREIGN KEY (id_origen) REFERENCES agenda_Origen(id_origen)
);

CREATE TABLE agenda_TurnoProtocolo (
    id_turno INT NOT NULL,
    id_protocolo INT NOT NULL,
    precio_aplicado DECIMAL(12,2) NOT NULL CHECK (precio_aplicado >= 0),
    PRIMARY KEY (id_turno, id_protocolo),
    CONSTRAINT FK_TurnoProtocolo_Turno FOREIGN KEY (id_turno) REFERENCES agenda_Turno(id_turno),
    CONSTRAINT FK_TurnoProtocolo_Protocolo FOREIGN KEY (id_protocolo) REFERENCES clinica_Protocolo(id_protocolo)
);

CREATE TABLE clinica_EvaluacionPrevia (
    id_evaluacion INT AUTO_INCREMENT PRIMARY KEY,
    id_turno INT NOT NULL,
    id_protocolo INT NOT NULL,
    id_resultado INT NULL,
    observaciones VARCHAR(500),
    fecha_resultado DATETIME,
    fecha_reclamo DATETIME,
    CONSTRAINT FK_EvaluacionPrevia_Turno FOREIGN KEY (id_turno) REFERENCES agenda_Turno(id_turno),
    CONSTRAINT FK_EvaluacionPrevia_Protocolo FOREIGN KEY (id_protocolo) REFERENCES clinica_Protocolo(id_protocolo),
    CONSTRAINT FK_EvaluacionPrevia_Resultado FOREIGN KEY (id_resultado) REFERENCES clinica_ResultadoEvaluacion(id_resultado)
);

-- Cierre de la relación circular turno <-> evaluacion previa
ALTER TABLE agenda_Turno ADD CONSTRAINT FK_Turno_EvaluacionPrevia
    FOREIGN KEY (id_evaluacion_previa) REFERENCES clinica_EvaluacionPrevia(id_evaluacion);


-- ===== pagos =====

CREATE TABLE pagos_EstadoPago (
    id_estado_pago INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE pagos_MedioPago (
    id_medio_pago INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE pagos_PagoSena (
    id_pago INT AUTO_INCREMENT PRIMARY KEY,
    id_turno INT NOT NULL,
    id_estado_pago INT NOT NULL,
    id_medio_pago INT NOT NULL,
    monto DECIMAL(12,2) NOT NULL CHECK (monto > 0),
    fecha_pago DATETIME NOT NULL,
    codigo_operacion VARCHAR(100),
    monto_reembolsado DECIMAL(12,2) CHECK (monto_reembolsado >= 0),
    fecha_resolucion DATETIME,
    CONSTRAINT FK_PagoSena_Turno FOREIGN KEY (id_turno) REFERENCES agenda_Turno(id_turno),
    CONSTRAINT FK_PagoSena_EstadoPago FOREIGN KEY (id_estado_pago) REFERENCES pagos_EstadoPago(id_estado_pago),
    CONSTRAINT FK_PagoSena_MedioPago FOREIGN KEY (id_medio_pago) REFERENCES pagos_MedioPago(id_medio_pago)
);

CREATE TABLE pagos_TarjetaRegalo (
    id_tarjeta INT AUTO_INCREMENT PRIMARY KEY,
    id_medio_pago INT NOT NULL,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    monto_inicial DECIMAL(12,2) NOT NULL CHECK (monto_inicial > 0),
    fecha_compra DATETIME NOT NULL,
    fecha_vencimiento DATETIME NOT NULL,
    comprador_nombre VARCHAR(100),
    comprador_telefono VARCHAR(30),
    CONSTRAINT FK_TarjetaRegalo_MedioPago FOREIGN KEY (id_medio_pago) REFERENCES pagos_MedioPago(id_medio_pago)
);

CREATE TABLE pagos_MovimientoTarjeta (
    id_movimiento INT AUTO_INCREMENT PRIMARY KEY,
    id_tarjeta INT NOT NULL,
    id_turno INT NOT NULL,
    monto DECIMAL(12,2) NOT NULL CHECK (monto > 0),
    fecha_movimiento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_MovimientoTarjeta_Tarjeta FOREIGN KEY (id_tarjeta) REFERENCES pagos_TarjetaRegalo(id_tarjeta),
    CONSTRAINT FK_MovimientoTarjeta_Turno FOREIGN KEY (id_turno) REFERENCES agenda_Turno(id_turno)
);


-- ===== beneficios =====

CREATE TABLE beneficios_TipoRegla (
    id_tipo_regla INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE beneficios_ReglaBeneficio (
    id_regla INT AUTO_INCREMENT PRIMARY KEY,
    id_tipo_regla INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    umbral INT NOT NULL CHECK (umbral > 0),
    porcentaje_descuento DECIMAL(5,2) NOT NULL CHECK (porcentaje_descuento BETWEEN 0 AND 100),
    vigencia_semanas INT NOT NULL CHECK (vigencia_semanas > 0),
    activa TINYINT NOT NULL DEFAULT 1,
    ventana_dias INT,
    CONSTRAINT FK_ReglaBeneficio_TipoRegla FOREIGN KEY (id_tipo_regla) REFERENCES beneficios_TipoRegla(id_tipo_regla)
);

CREATE TABLE beneficios_Cupon (
    id_cupon INT AUTO_INCREMENT PRIMARY KEY,
    id_regla INT NOT NULL,
    id_paciente INT NOT NULL,
    id_turno INT NULL,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    secreto VARCHAR(255) NOT NULL,
    porcentaje_descuento DECIMAL(5,2) NOT NULL CHECK (porcentaje_descuento BETWEEN 0 AND 100),
    fecha_emision DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_vencimiento DATETIME NOT NULL,
    CONSTRAINT FK_Cupon_Regla FOREIGN KEY (id_regla) REFERENCES beneficios_ReglaBeneficio(id_regla),
    CONSTRAINT FK_Cupon_Paciente FOREIGN KEY (id_paciente) REFERENCES personas_Paciente(id_paciente),
    CONSTRAINT FK_Cupon_Turno FOREIGN KEY (id_turno) REFERENCES agenda_Turno(id_turno)
);


-- ===== notificaciones =====

CREATE TABLE notificaciones_CanalNotificacion (
    id_canal INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE notificaciones_EstadoNotificacion (
    id_estado_notificacion INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE notificaciones_TipoNotificacion (
    id_tipo_notificacion INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE notificaciones_Notificacion (
    id_notificacion INT AUTO_INCREMENT PRIMARY KEY,
    id_canal INT NOT NULL,
    id_estado_notificacion INT NOT NULL,
    id_tipo_notificacion INT NOT NULL,
    id_paciente INT NULL,
    id_profesional INT NULL,
    id_turno INT NULL,
    mensaje VARCHAR(1000) NOT NULL,
    fecha_programada DATETIME NOT NULL,
    intentos INT NOT NULL DEFAULT 0 CHECK (intentos >= 0),
    fecha_envio DATETIME NULL,
    detalle_error VARCHAR(500),
    CONSTRAINT FK_Notificacion_Canal FOREIGN KEY (id_canal) REFERENCES notificaciones_CanalNotificacion(id_canal),
    CONSTRAINT FK_Notificacion_Estado FOREIGN KEY (id_estado_notificacion) REFERENCES notificaciones_EstadoNotificacion(id_estado_notificacion),
    CONSTRAINT FK_Notificacion_Tipo FOREIGN KEY (id_tipo_notificacion) REFERENCES notificaciones_TipoNotificacion(id_tipo_notificacion),
    CONSTRAINT FK_Notificacion_Paciente FOREIGN KEY (id_paciente) REFERENCES personas_Paciente(id_paciente),
    CONSTRAINT FK_Notificacion_Profesional FOREIGN KEY (id_profesional) REFERENCES personas_Profesional(id_profesional),
    CONSTRAINT FK_Notificacion_Turno FOREIGN KEY (id_turno) REFERENCES agenda_Turno(id_turno)
);


-- ===== auditoria =====

CREATE TABLE auditoria_TipoEvento (
    id_tipo_evento INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(200)
);

CREATE TABLE auditoria_Log (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_tipo_evento INT NOT NULL,
    id_usuario INT NULL,
    id_paciente INT NULL,
    id_origen INT NOT NULL,
    fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    descripcion VARCHAR(500),
    ip_origen VARCHAR(45),
    tabla_afectada VARCHAR(100),
    id_registro_afectado INT,
    valor_anterior LONGTEXT,
    valor_nuevo LONGTEXT,
    exitoso TINYINT NOT NULL DEFAULT 1,
    CONSTRAINT FK_Log_TipoEvento FOREIGN KEY (id_tipo_evento) REFERENCES auditoria_TipoEvento(id_tipo_evento),
    CONSTRAINT FK_Log_Usuario FOREIGN KEY (id_usuario) REFERENCES seguridad_Usuario(id_usuario),
    CONSTRAINT FK_Log_Paciente FOREIGN KEY (id_paciente) REFERENCES personas_Paciente(id_paciente),
    CONSTRAINT FK_Log_Origen FOREIGN KEY (id_origen) REFERENCES agenda_Origen(id_origen)
);


-- ===== asistente =====

CREATE TABLE asistente_ConsultaAsistente (
    id_consulta INT AUTO_INCREMENT PRIMARY KEY,
    id_paciente INT NULL,
    id_origen INT NOT NULL,
    pregunta LONGTEXT NOT NULL,
    fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    derivada TINYINT NOT NULL DEFAULT 0,
    respuesta LONGTEXT,
    CONSTRAINT FK_ConsultaAsistente_Paciente FOREIGN KEY (id_paciente) REFERENCES personas_Paciente(id_paciente),
    CONSTRAINT FK_ConsultaAsistente_Origen FOREIGN KEY (id_origen) REFERENCES agenda_Origen(id_origen)
);
