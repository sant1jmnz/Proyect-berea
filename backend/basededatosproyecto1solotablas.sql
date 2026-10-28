CREATE DATABASE IF NOT EXISTS Proyecto1;
USE Proyecto1;


ALTER TABLE Turno DROP FOREIGN KEY FK_Turno_EvaluacionPrevia;

-- Borrado de tablas (de hijas a padres)
DROP TABLE IF EXISTS ConsultaAsistente;
DROP TABLE IF EXISTS Log;
DROP TABLE IF EXISTS Notificacion;
DROP TABLE IF EXISTS Cupon;
DROP TABLE IF EXISTS ReglaBeneficio;
DROP TABLE IF EXISTS TipoRegla;
DROP TABLE IF EXISTS MovimientoTarjeta;
DROP TABLE IF EXISTS TarjetaRegalo;
DROP TABLE IF EXISTS PagoSena;
DROP TABLE IF EXISTS MedioPago;
DROP TABLE IF EXISTS EstadoPago;
DROP TABLE IF EXISTS TurnoProtocolo;
DROP TABLE IF EXISTS EvaluacionPrevia;
DROP TABLE IF EXISTS Turno;
DROP TABLE IF EXISTS Origen;
DROP TABLE IF EXISTS EstadoTurno;
DROP TABLE IF EXISTS ResultadoEvaluacion;
DROP TABLE IF EXISTS ProfesionalProtocolo;
DROP TABLE IF EXISTS Protocolo;
DROP TABLE IF EXISTS CategoriaProtocolo;
DROP TABLE IF EXISTS Disponibilidad;
DROP TABLE IF EXISTS TelefonoProfesional;
DROP TABLE IF EXISTS Profesional;
DROP TABLE IF EXISTS TelefonoPaciente;
DROP TABLE IF EXISTS Paciente;
DROP TABLE IF EXISTS Usuario;
DROP TABLE IF EXISTS Rol;
DROP TABLE IF EXISTS CanalNotificacion;
DROP TABLE IF EXISTS EstadoNotificacion;
DROP TABLE IF EXISTS TipoNotificacion;
DROP TABLE IF EXISTS TipoEvento;


-- ===== seguridad =====

CREATE TABLE Rol (
    id_rol INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Usuario (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    id_rol INT NOT NULL,
    nombre_usuario VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_Usuario_Rol FOREIGN KEY (id_rol) REFERENCES Rol(id_rol)
);


-- ===== personas =====

CREATE TABLE Paciente (
    id_paciente INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NULL,
    dni VARCHAR(15) NOT NULL UNIQUE,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    fecha_nacimiento DATETIME NOT NULL,
    fecha_alta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    email VARCHAR(100),
    telegram_chat_id VARCHAR(50),
    CONSTRAINT FK_Paciente_Usuario FOREIGN KEY (id_usuario) REFERENCES Usuario(id_usuario)
);

CREATE TABLE TelefonoPaciente (
    id_telefono_paciente INT AUTO_INCREMENT PRIMARY KEY,
    id_paciente INT NOT NULL,
    telefono VARCHAR(30) NOT NULL,
    CONSTRAINT FK_TelefonoPaciente_Paciente FOREIGN KEY (id_paciente) REFERENCES Paciente(id_paciente)
);

CREATE TABLE Profesional (
    id_profesional INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    matricula VARCHAR(30) NOT NULL UNIQUE,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    activo TINYINT(1) NOT NULL DEFAULT 1,
    google_calendar_id VARCHAR(255),
    CONSTRAINT FK_Profesional_Usuario FOREIGN KEY (id_usuario) REFERENCES Usuario(id_usuario)
);

CREATE TABLE TelefonoProfesional (
    id_telefono_profesional INT AUTO_INCREMENT PRIMARY KEY,
    id_profesional INT NOT NULL,
    telefono VARCHAR(30) NOT NULL,
    CONSTRAINT FK_TelefonoProfesional_Profesional FOREIGN KEY (id_profesional) REFERENCES Profesional(id_profesional)
);

CREATE TABLE Disponibilidad (
    id_disponibilidad INT AUTO_INCREMENT PRIMARY KEY,
    id_profesional INT NOT NULL,
    fecha DATETIME NOT NULL,
    hora_inicio DATETIME NOT NULL,
    hora_fin DATETIME NOT NULL,
    activa TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT FK_Disponibilidad_Profesional FOREIGN KEY (id_profesional) REFERENCES Profesional(id_profesional)
);


-- ===== clinica =====

CREATE TABLE CategoriaProtocolo (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    porcentaje_sena DECIMAL(5,2) NOT NULL CHECK (porcentaje_sena BETWEEN 0 AND 100),
    requiere_evaluacion TINYINT(1) NOT NULL DEFAULT 0
);

CREATE TABLE Protocolo (
    id_protocolo INT AUTO_INCREMENT PRIMARY KEY,
    id_categoria INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(500),
    precio DECIMAL(12,2) NOT NULL CHECK (precio > 0),
    duracion_min INT NOT NULL CHECK (duracion_min > 0),
    activo TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT FK_Protocolo_Categoria FOREIGN KEY (id_categoria) REFERENCES CategoriaProtocolo(id_categoria)
);

CREATE TABLE ProfesionalProtocolo (
    id_profesional INT NOT NULL,
    id_protocolo INT NOT NULL,
    PRIMARY KEY (id_profesional, id_protocolo),
    CONSTRAINT FK_ProfesionalProtocolo_Profesional FOREIGN KEY (id_profesional) REFERENCES Profesional(id_profesional),
    CONSTRAINT FK_ProfesionalProtocolo_Protocolo FOREIGN KEY (id_protocolo) REFERENCES Protocolo(id_protocolo)
);

CREATE TABLE ResultadoEvaluacion (
    id_resultado INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);


-- ===== agenda =====

CREATE TABLE EstadoTurno (
    id_estado_turno INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Origen (
    id_origen INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Turno (
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
    CONSTRAINT FK_Turno_Paciente FOREIGN KEY (id_paciente) REFERENCES Paciente(id_paciente),
    CONSTRAINT FK_Turno_Profesional FOREIGN KEY (id_profesional) REFERENCES Profesional(id_profesional),
    CONSTRAINT FK_Turno_EstadoTurno FOREIGN KEY (id_estado_turno) REFERENCES EstadoTurno(id_estado_turno),
    CONSTRAINT FK_Turno_Origen FOREIGN KEY (id_origen) REFERENCES Origen(id_origen)
);

CREATE TABLE TurnoProtocolo (
    id_turno INT NOT NULL,
    id_protocolo INT NOT NULL,
    precio_aplicado DECIMAL(12,2) NOT NULL CHECK (precio_aplicado >= 0),
    PRIMARY KEY (id_turno, id_protocolo),
    CONSTRAINT FK_TurnoProtocolo_Turno FOREIGN KEY (id_turno) REFERENCES Turno(id_turno),
    CONSTRAINT FK_TurnoProtocolo_Protocolo FOREIGN KEY (id_protocolo) REFERENCES Protocolo(id_protocolo)
);

CREATE TABLE EvaluacionPrevia (
    id_evaluacion INT AUTO_INCREMENT PRIMARY KEY,
    id_turno INT NOT NULL,
    id_protocolo INT NOT NULL,
    id_resultado INT NULL,
    observaciones VARCHAR(500),
    fecha_resultado DATETIME,
    fecha_reclamo DATETIME,
    CONSTRAINT FK_EvaluacionPrevia_Turno FOREIGN KEY (id_turno) REFERENCES Turno(id_turno),
    CONSTRAINT FK_EvaluacionPrevia_Protocolo FOREIGN KEY (id_protocolo) REFERENCES Protocolo(id_protocolo),
    CONSTRAINT FK_EvaluacionPrevia_Resultado FOREIGN KEY (id_resultado) REFERENCES ResultadoEvaluacion(id_resultado)
);

-- Cierre de la relación circular turno <-> evaluacion previa
ALTER TABLE Turno ADD CONSTRAINT FK_Turno_EvaluacionPrevia
    FOREIGN KEY (id_evaluacion_previa) REFERENCES EvaluacionPrevia(id_evaluacion);


-- ===== pagos =====

CREATE TABLE EstadoPago (
    id_estado_pago INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE MedioPago (
    id_medio_pago INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE PagoSena (
    id_pago INT AUTO_INCREMENT PRIMARY KEY,
    id_turno INT NOT NULL,
    id_estado_pago INT NOT NULL,
    id_medio_pago INT NOT NULL,
    monto DECIMAL(12,2) NOT NULL CHECK (monto > 0),
    fecha_pago DATETIME NOT NULL,
    codigo_operacion VARCHAR(100),
    monto_reembolsado DECIMAL(12,2) CHECK (monto_reembolsado >= 0),
    fecha_resolucion DATETIME,
    CONSTRAINT FK_PagoSena_Turno FOREIGN KEY (id_turno) REFERENCES Turno(id_turno),
    CONSTRAINT FK_PagoSena_EstadoPago FOREIGN KEY (id_estado_pago) REFERENCES EstadoPago(id_estado_pago),
    CONSTRAINT FK_PagoSena_MedioPago FOREIGN KEY (id_medio_pago) REFERENCES MedioPago(id_medio_pago)
);

CREATE TABLE TarjetaRegalo (
    id_tarjeta INT AUTO_INCREMENT PRIMARY KEY,
    id_medio_pago INT NOT NULL,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    monto_inicial DECIMAL(12,2) NOT NULL CHECK (monto_inicial > 0),
    fecha_compra DATETIME NOT NULL,
    fecha_vencimiento DATETIME NOT NULL,
    comprador_nombre VARCHAR(100),
    comprador_telefono VARCHAR(30),
    CONSTRAINT FK_TarjetaRegalo_MedioPago FOREIGN KEY (id_medio_pago) REFERENCES MedioPago(id_medio_pago)
);

CREATE TABLE MovimientoTarjeta (
    id_movimiento INT AUTO_INCREMENT PRIMARY KEY,
    id_tarjeta INT NOT NULL,
    id_turno INT NOT NULL,
    monto DECIMAL(12,2) NOT NULL CHECK (monto > 0),
    fecha_movimiento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_MovimientoTarjeta_Tarjeta FOREIGN KEY (id_tarjeta) REFERENCES TarjetaRegalo(id_tarjeta),
    CONSTRAINT FK_MovimientoTarjeta_Turno FOREIGN KEY (id_turno) REFERENCES Turno(id_turno)
);


-- ===== beneficios =====

CREATE TABLE TipoRegla (
    id_tipo_regla INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE ReglaBeneficio (
    id_regla INT AUTO_INCREMENT PRIMARY KEY,
    id_tipo_regla INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    umbral INT NOT NULL CHECK (umbral > 0),
    porcentaje_descuento DECIMAL(5,2) NOT NULL CHECK (porcentaje_descuento BETWEEN 0 AND 100),
    vigencia_semanas INT NOT NULL CHECK (vigencia_semanas > 0),
    activa TINYINT(1) NOT NULL DEFAULT 1,
    ventana_dias INT,
    CONSTRAINT FK_ReglaBeneficio_TipoRegla FOREIGN KEY (id_tipo_regla) REFERENCES TipoRegla(id_tipo_regla)
);

CREATE TABLE Cupon (
    id_cupon INT AUTO_INCREMENT PRIMARY KEY,
    id_regla INT NOT NULL,
    id_paciente INT NOT NULL,
    id_turno INT NULL,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    secreto VARCHAR(255) NOT NULL,
    porcentaje_descuento DECIMAL(5,2) NOT NULL CHECK (porcentaje_descuento BETWEEN 0 AND 100),
    fecha_emision DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_vencimiento DATETIME NOT NULL,
    CONSTRAINT FK_Cupon_Regla FOREIGN KEY (id_regla) REFERENCES ReglaBeneficio(id_regla),
    CONSTRAINT FK_Cupon_Paciente FOREIGN KEY (id_paciente) REFERENCES Paciente(id_paciente),
    CONSTRAINT FK_Cupon_Turno FOREIGN KEY (id_turno) REFERENCES Turno(id_turno)
);


-- ===== notificaciones =====

CREATE TABLE CanalNotificacion (
    id_canal INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE EstadoNotificacion (
    id_estado_notificacion INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE TipoNotificacion (
    id_tipo_notificacion INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Notificacion (
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
    CONSTRAINT FK_Notificacion_Canal FOREIGN KEY (id_canal) REFERENCES CanalNotificacion(id_canal),
    CONSTRAINT FK_Notificacion_Estado FOREIGN KEY (id_estado_notificacion) REFERENCES EstadoNotificacion(id_estado_notificacion),
    CONSTRAINT FK_Notificacion_Tipo FOREIGN KEY (id_tipo_notificacion) REFERENCES TipoNotificacion(id_tipo_notificacion),
    CONSTRAINT FK_Notificacion_Paciente FOREIGN KEY (id_paciente) REFERENCES Paciente(id_paciente),
    CONSTRAINT FK_Notificacion_Profesional FOREIGN KEY (id_profesional) REFERENCES Profesional(id_profesional),
    CONSTRAINT FK_Notificacion_Turno FOREIGN KEY (id_turno) REFERENCES Turno(id_turno)
);


-- ===== auditoria =====

CREATE TABLE TipoEvento (
    id_tipo_evento INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(200)
);

CREATE TABLE Log (
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
    exitoso TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT FK_Log_TipoEvento FOREIGN KEY (id_tipo_evento) REFERENCES TipoEvento(id_tipo_evento),
    CONSTRAINT FK_Log_Usuario FOREIGN KEY (id_usuario) REFERENCES Usuario(id_usuario),
    CONSTRAINT FK_Log_Paciente FOREIGN KEY (id_paciente) REFERENCES Paciente(id_paciente),
    CONSTRAINT FK_Log_Origen FOREIGN KEY (id_origen) REFERENCES Origen(id_origen)
);


-- ===== asistente =====

CREATE TABLE ConsultaAsistente (
    id_consulta INT AUTO_INCREMENT PRIMARY KEY,
    id_paciente INT NULL,
    id_origen INT NOT NULL,
    pregunta LONGTEXT NOT NULL,
    fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    derivada TINYINT(1) NOT NULL DEFAULT 0,
    respuesta LONGTEXT,
    CONSTRAINT FK_ConsultaAsistente_Paciente FOREIGN KEY (id_paciente) REFERENCES Paciente(id_paciente),
    CONSTRAINT FK_ConsultaAsistente_Origen FOREIGN KEY (id_origen) REFERENCES Origen(id_origen)
);
