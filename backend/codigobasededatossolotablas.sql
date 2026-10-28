-- Dermalia: estructura de la base (solo tablas), MySQL 8.
-- El modelo está dividido en 9 schemas (consigna 3c). En MySQL un schema es
-- una base de datos: las tablas se nombran schema.Tabla y las FK cruzan
-- schemas sin problema. Cambios de la revisión explicados en backend/REVISION.md.

-- La conexión en utf8mb4, así los textos con tildes llegan bien.
SET NAMES utf8mb4;

-- Borrado: con la FK circular Turno <-> EvaluacionPrevia no hay un orden de
-- DROP TABLE que funcione, así que se apagan los chequeos y se borran los schemas.
SET FOREIGN_KEY_CHECKS = 0;
DROP DATABASE IF EXISTS asistente;
DROP DATABASE IF EXISTS auditoria;
DROP DATABASE IF EXISTS notificaciones;
DROP DATABASE IF EXISTS beneficios;
DROP DATABASE IF EXISTS pagos;
DROP DATABASE IF EXISTS agenda;
DROP DATABASE IF EXISTS clinica;
DROP DATABASE IF EXISTS personas;
DROP DATABASE IF EXISTS seguridad;
SET FOREIGN_KEY_CHECKS = 1;

-- utf8mb4 para que se guarden bien tildes y eñes.
CREATE DATABASE seguridad CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE DATABASE personas CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE DATABASE clinica CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE DATABASE agenda CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE DATABASE pagos CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE DATABASE beneficios CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE DATABASE notificaciones CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE DATABASE auditoria CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE DATABASE asistente CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;


-- ===== seguridad =====

CREATE TABLE seguridad.Rol (
    id_rol INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE seguridad.Usuario (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    id_rol INT NOT NULL,
    nombre_usuario VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    activo TINYINT NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)),
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_Usuario_Rol FOREIGN KEY (id_rol) REFERENCES seguridad.Rol(id_rol)
);


-- ===== personas =====

CREATE TABLE personas.Paciente (
    id_paciente INT AUTO_INCREMENT PRIMARY KEY,
    -- UNIQUE: una cuenta es de una sola paciente (0,1)-(0,1).
    id_usuario INT NULL UNIQUE,
    dni VARCHAR(15) NOT NULL UNIQUE,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    -- DATE: la hora de nacimiento no hace falta.
    fecha_nacimiento DATE NOT NULL,
    fecha_alta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    email VARCHAR(100),
    telegram_chat_id VARCHAR(50),
    CONSTRAINT FK_Paciente_Usuario FOREIGN KEY (id_usuario) REFERENCES seguridad.Usuario(id_usuario)
);

-- Teléfono multivaluado (consigna 1b): una paciente puede tener varios.
CREATE TABLE personas.TelefonoPaciente (
    id_telefono_paciente INT AUTO_INCREMENT PRIMARY KEY,
    id_paciente INT NOT NULL,
    telefono VARCHAR(30) NOT NULL,
    CONSTRAINT UQ_TelefonoPaciente UNIQUE (id_paciente, telefono),
    CONSTRAINT FK_TelefonoPaciente_Paciente FOREIGN KEY (id_paciente) REFERENCES personas.Paciente(id_paciente)
);

CREATE TABLE personas.Profesional (
    id_profesional INT AUTO_INCREMENT PRIMARY KEY,
    -- UNIQUE: cada profesional tiene su propia cuenta (1,1)-(0,1).
    id_usuario INT NOT NULL UNIQUE,
    matricula VARCHAR(30) NOT NULL UNIQUE,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    activo TINYINT NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)),
    google_calendar_id VARCHAR(255),
    CONSTRAINT FK_Profesional_Usuario FOREIGN KEY (id_usuario) REFERENCES seguridad.Usuario(id_usuario)
);

CREATE TABLE personas.TelefonoProfesional (
    id_telefono_profesional INT AUTO_INCREMENT PRIMARY KEY,
    id_profesional INT NOT NULL,
    telefono VARCHAR(30) NOT NULL,
    CONSTRAINT UQ_TelefonoProfesional UNIQUE (id_profesional, telefono),
    CONSTRAINT FK_TelefonoProfesional_Profesional FOREIGN KEY (id_profesional) REFERENCES personas.Profesional(id_profesional)
);

-- Franja horaria de un día: la fecha va una sola vez y las horas son TIME.
CREATE TABLE personas.Disponibilidad (
    id_disponibilidad INT AUTO_INCREMENT PRIMARY KEY,
    id_profesional INT NOT NULL,
    fecha DATE NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    activa TINYINT NOT NULL DEFAULT 1 CHECK (activa IN (0, 1)),
    CONSTRAINT CK_Disponibilidad_Horas CHECK (hora_fin > hora_inicio),
    CONSTRAINT FK_Disponibilidad_Profesional FOREIGN KEY (id_profesional) REFERENCES personas.Profesional(id_profesional)
);


-- ===== clinica =====

CREATE TABLE clinica.CategoriaProtocolo (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    porcentaje_sena DECIMAL(5,2) NOT NULL CHECK (porcentaje_sena BETWEEN 0 AND 100),
    requiere_evaluacion TINYINT NOT NULL DEFAULT 0 CHECK (requiere_evaluacion IN (0, 1))
);

CREATE TABLE clinica.Protocolo (
    id_protocolo INT AUTO_INCREMENT PRIMARY KEY,
    id_categoria INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(500),
    precio DECIMAL(12,2) NOT NULL CHECK (precio > 0),
    duracion_min INT NOT NULL CHECK (duracion_min > 0),
    activo TINYINT NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)),
    CONSTRAINT FK_Protocolo_Categoria FOREIGN KEY (id_categoria) REFERENCES clinica.CategoriaProtocolo(id_categoria)
);

CREATE TABLE clinica.ProfesionalProtocolo (
    id_profesional INT NOT NULL,
    id_protocolo INT NOT NULL,
    PRIMARY KEY (id_profesional, id_protocolo),
    CONSTRAINT FK_ProfesionalProtocolo_Profesional FOREIGN KEY (id_profesional) REFERENCES personas.Profesional(id_profesional),
    CONSTRAINT FK_ProfesionalProtocolo_Protocolo FOREIGN KEY (id_protocolo) REFERENCES clinica.Protocolo(id_protocolo)
);

CREATE TABLE clinica.ResultadoEvaluacion (
    id_resultado INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);


-- ===== agenda =====

CREATE TABLE agenda.EstadoTurno (
    id_estado_turno INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE agenda.Origen (
    id_origen INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE agenda.Turno (
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
    CONSTRAINT FK_Turno_Paciente FOREIGN KEY (id_paciente) REFERENCES personas.Paciente(id_paciente),
    CONSTRAINT FK_Turno_Profesional FOREIGN KEY (id_profesional) REFERENCES personas.Profesional(id_profesional),
    CONSTRAINT FK_Turno_EstadoTurno FOREIGN KEY (id_estado_turno) REFERENCES agenda.EstadoTurno(id_estado_turno),
    CONSTRAINT FK_Turno_Origen FOREIGN KEY (id_origen) REFERENCES agenda.Origen(id_origen)
);

CREATE TABLE agenda.TurnoProtocolo (
    id_turno INT NOT NULL,
    id_protocolo INT NOT NULL,
    precio_aplicado DECIMAL(12,2) NOT NULL CHECK (precio_aplicado >= 0),
    PRIMARY KEY (id_turno, id_protocolo),
    CONSTRAINT FK_TurnoProtocolo_Turno FOREIGN KEY (id_turno) REFERENCES agenda.Turno(id_turno),
    CONSTRAINT FK_TurnoProtocolo_Protocolo FOREIGN KEY (id_protocolo) REFERENCES clinica.Protocolo(id_protocolo)
);

CREATE TABLE clinica.EvaluacionPrevia (
    id_evaluacion INT AUTO_INCREMENT PRIMARY KEY,
    -- UNIQUE: un turno de consulta genera a lo sumo una evaluación.
    id_turno INT NOT NULL UNIQUE,
    id_protocolo INT NOT NULL,
    id_resultado INT NULL,
    observaciones VARCHAR(500),
    fecha_resultado DATETIME,
    fecha_reclamo DATETIME,
    CONSTRAINT FK_EvaluacionPrevia_Turno FOREIGN KEY (id_turno) REFERENCES agenda.Turno(id_turno),
    CONSTRAINT FK_EvaluacionPrevia_Protocolo FOREIGN KEY (id_protocolo) REFERENCES clinica.Protocolo(id_protocolo),
    CONSTRAINT FK_EvaluacionPrevia_Resultado FOREIGN KEY (id_resultado) REFERENCES clinica.ResultadoEvaluacion(id_resultado)
);

-- Cierre de la relación circular turno <-> evaluacion previa
ALTER TABLE agenda.Turno ADD CONSTRAINT FK_Turno_EvaluacionPrevia
    FOREIGN KEY (id_evaluacion_previa) REFERENCES clinica.EvaluacionPrevia(id_evaluacion);


-- ===== pagos =====

CREATE TABLE pagos.EstadoPago (
    id_estado_pago INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE pagos.MedioPago (
    id_medio_pago INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE pagos.PagoSena (
    id_pago INT AUTO_INCREMENT PRIMARY KEY,
    -- UNIQUE: un turno tiene como máximo un pago de seña.
    id_turno INT NOT NULL UNIQUE,
    id_estado_pago INT NOT NULL,
    id_medio_pago INT NOT NULL,
    monto DECIMAL(12,2) NOT NULL CHECK (monto > 0),
    fecha_pago DATETIME NOT NULL,
    codigo_operacion VARCHAR(100),
    monto_reembolsado DECIMAL(12,2) CHECK (monto_reembolsado >= 0),
    fecha_resolucion DATETIME,
    -- No se puede devolver más de lo que se pagó.
    CONSTRAINT CK_PagoSena_Reembolso CHECK (monto_reembolsado <= monto),
    CONSTRAINT FK_PagoSena_Turno FOREIGN KEY (id_turno) REFERENCES agenda.Turno(id_turno),
    CONSTRAINT FK_PagoSena_EstadoPago FOREIGN KEY (id_estado_pago) REFERENCES pagos.EstadoPago(id_estado_pago),
    CONSTRAINT FK_PagoSena_MedioPago FOREIGN KEY (id_medio_pago) REFERENCES pagos.MedioPago(id_medio_pago)
);

CREATE TABLE pagos.TarjetaRegalo (
    id_tarjeta INT AUTO_INCREMENT PRIMARY KEY,
    id_medio_pago INT NOT NULL,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    monto_inicial DECIMAL(12,2) NOT NULL CHECK (monto_inicial > 0),
    fecha_compra DATETIME NOT NULL,
    fecha_vencimiento DATETIME NOT NULL,
    comprador_nombre VARCHAR(100),
    comprador_telefono VARCHAR(30),
    CONSTRAINT CK_TarjetaRegalo_Fechas CHECK (fecha_vencimiento > fecha_compra),
    CONSTRAINT FK_TarjetaRegalo_MedioPago FOREIGN KEY (id_medio_pago) REFERENCES pagos.MedioPago(id_medio_pago)
);

CREATE TABLE pagos.MovimientoTarjeta (
    id_movimiento INT AUTO_INCREMENT PRIMARY KEY,
    id_tarjeta INT NOT NULL,
    id_turno INT NOT NULL,
    -- Positivo = gasto; negativo = devolución de saldo (modelo, grupo 3, decisión 7).
    monto DECIMAL(12,2) NOT NULL CHECK (monto <> 0),
    fecha_movimiento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_MovimientoTarjeta_Tarjeta FOREIGN KEY (id_tarjeta) REFERENCES pagos.TarjetaRegalo(id_tarjeta),
    CONSTRAINT FK_MovimientoTarjeta_Turno FOREIGN KEY (id_turno) REFERENCES agenda.Turno(id_turno)
);


-- ===== beneficios =====

CREATE TABLE beneficios.TipoRegla (
    id_tipo_regla INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE beneficios.ReglaBeneficio (
    id_regla INT AUTO_INCREMENT PRIMARY KEY,
    id_tipo_regla INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    umbral INT NOT NULL CHECK (umbral > 0),
    porcentaje_descuento DECIMAL(5,2) NOT NULL CHECK (porcentaje_descuento BETWEEN 0 AND 100),
    -- Los cupones duran entre 2 y 8 semanas.
    vigencia_semanas INT NOT NULL CHECK (vigencia_semanas BETWEEN 2 AND 8),
    activa TINYINT NOT NULL DEFAULT 1 CHECK (activa IN (0, 1)),
    ventana_dias INT CHECK (ventana_dias > 0),
    CONSTRAINT FK_ReglaBeneficio_TipoRegla FOREIGN KEY (id_tipo_regla) REFERENCES beneficios.TipoRegla(id_tipo_regla)
);

CREATE TABLE beneficios.Cupon (
    id_cupon INT AUTO_INCREMENT PRIMARY KEY,
    id_regla INT NOT NULL,
    id_paciente INT NOT NULL,
    -- El cupón se usa en un solo turno (una sola columna) y, con UNIQUE,
    -- un turno no puede usar dos cupones: (0,1)-(0,1).
    id_turno INT NULL UNIQUE,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    secreto VARCHAR(255) NOT NULL,
    porcentaje_descuento DECIMAL(5,2) NOT NULL CHECK (porcentaje_descuento BETWEEN 0 AND 100),
    fecha_emision DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_vencimiento DATETIME NOT NULL,
    CONSTRAINT CK_Cupon_Fechas CHECK (fecha_vencimiento > fecha_emision),
    CONSTRAINT FK_Cupon_Regla FOREIGN KEY (id_regla) REFERENCES beneficios.ReglaBeneficio(id_regla),
    CONSTRAINT FK_Cupon_Paciente FOREIGN KEY (id_paciente) REFERENCES personas.Paciente(id_paciente),
    CONSTRAINT FK_Cupon_Turno FOREIGN KEY (id_turno) REFERENCES agenda.Turno(id_turno)
);


-- ===== notificaciones =====

CREATE TABLE notificaciones.CanalNotificacion (
    id_canal INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE notificaciones.EstadoNotificacion (
    id_estado_notificacion INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE notificaciones.TipoNotificacion (
    id_tipo_notificacion INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE notificaciones.Notificacion (
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
    -- El aviso va a una paciente o a un profesional: exactamente uno de los dos.
    CONSTRAINT CK_Notificacion_Destinatario CHECK ((id_paciente IS NULL) <> (id_profesional IS NULL)),
    CONSTRAINT FK_Notificacion_Canal FOREIGN KEY (id_canal) REFERENCES notificaciones.CanalNotificacion(id_canal),
    CONSTRAINT FK_Notificacion_Estado FOREIGN KEY (id_estado_notificacion) REFERENCES notificaciones.EstadoNotificacion(id_estado_notificacion),
    CONSTRAINT FK_Notificacion_Tipo FOREIGN KEY (id_tipo_notificacion) REFERENCES notificaciones.TipoNotificacion(id_tipo_notificacion),
    CONSTRAINT FK_Notificacion_Paciente FOREIGN KEY (id_paciente) REFERENCES personas.Paciente(id_paciente),
    CONSTRAINT FK_Notificacion_Profesional FOREIGN KEY (id_profesional) REFERENCES personas.Profesional(id_profesional),
    CONSTRAINT FK_Notificacion_Turno FOREIGN KEY (id_turno) REFERENCES agenda.Turno(id_turno)
);


-- ===== auditoria =====

CREATE TABLE auditoria.TipoEvento (
    id_tipo_evento INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(200)
);

CREATE TABLE auditoria.Log (
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
    exitoso TINYINT NOT NULL DEFAULT 1 CHECK (exitoso IN (0, 1)),
    CONSTRAINT FK_Log_TipoEvento FOREIGN KEY (id_tipo_evento) REFERENCES auditoria.TipoEvento(id_tipo_evento),
    CONSTRAINT FK_Log_Usuario FOREIGN KEY (id_usuario) REFERENCES seguridad.Usuario(id_usuario),
    CONSTRAINT FK_Log_Paciente FOREIGN KEY (id_paciente) REFERENCES personas.Paciente(id_paciente),
    CONSTRAINT FK_Log_Origen FOREIGN KEY (id_origen) REFERENCES agenda.Origen(id_origen)
);


-- ===== asistente =====

CREATE TABLE asistente.ConsultaAsistente (
    id_consulta INT AUTO_INCREMENT PRIMARY KEY,
    id_paciente INT NULL,
    id_origen INT NOT NULL,
    pregunta LONGTEXT NOT NULL,
    fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    derivada TINYINT NOT NULL DEFAULT 0 CHECK (derivada IN (0, 1)),
    respuesta LONGTEXT,
    CONSTRAINT FK_ConsultaAsistente_Paciente FOREIGN KEY (id_paciente) REFERENCES personas.Paciente(id_paciente),
    CONSTRAINT FK_ConsultaAsistente_Origen FOREIGN KEY (id_origen) REFERENCES agenda.Origen(id_origen)
);
