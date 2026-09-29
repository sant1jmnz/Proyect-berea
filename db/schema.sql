-- Dermalia: esquema para SQL Server (T-SQL).
-- Todo queda en la base local del instituto (RNF-06, RNF-09).
IF DB_ID('dermalia') IS NULL CREATE DATABASE dermalia;
GO
USE dermalia;
GO

CREATE TABLE Protocolo (            -- R2: base de precios y protocolos
    id            INT IDENTITY PRIMARY KEY,
    nombre        NVARCHAR(100) NOT NULL,
    palabras      NVARCHAR(300) NOT NULL DEFAULT '',  -- claves del buscador (RF-05/06)
    duracion_min  INT NOT NULL CHECK (duracion_min > 0),
    precio        INT NOT NULL CHECK (precio >= 0),   -- pesos enteros
    activo        BIT NOT NULL DEFAULT 1              -- RNF-08: la recepción lo edita
);

CREATE TABLE Profesional (
    id      INT IDENTITY PRIMARY KEY,
    nombre  NVARCHAR(100) NOT NULL,
    activo  BIT NOT NULL DEFAULT 1
);

CREATE TABLE Disponibilidad (       -- RF-03: agenda propia, sin calendario externo
    id              INT IDENTITY PRIMARY KEY,
    profesional_id  INT NOT NULL REFERENCES Profesional(id),
    inicio          DATETIME2(0) NOT NULL,
    fin             DATETIME2(0) NOT NULL,
    CHECK (fin > inicio)
);

CREATE TABLE Paciente (
    id        INT IDENTITY PRIMARY KEY,
    nombre    NVARCHAR(100) NOT NULL,
    dni       VARCHAR(12)   NOT NULL,
    telefono  VARCHAR(20)   NOT NULL
);
CREATE INDEX IX_Paciente_dni ON Paciente(dni);
CREATE INDEX IX_Paciente_telefono ON Paciente(telefono);

CREATE TABLE Turno (
    id              INT IDENTITY PRIMARY KEY,
    paciente_id     INT NOT NULL REFERENCES Paciente(id),
    protocolo_id    INT NOT NULL REFERENCES Protocolo(id),
    profesional_id  INT NOT NULL REFERENCES Profesional(id),
    inicio          DATETIME2(0) NOT NULL,
    fin             DATETIME2(0) NOT NULL,
    origen          VARCHAR(10) NOT NULL CHECK (origen IN ('terminal','recepcion')),
    estado          VARCHAR(12) NOT NULL DEFAULT 'confirmado'
                    CHECK (estado IN ('confirmado','realizado','cancelado','ausente')),
    sena_monto      INT NOT NULL DEFAULT 0,           -- RF-10
    sena_pagada     BIT NOT NULL DEFAULT 0,           -- mock (RNF-05): solo un estado
    creado          DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CHECK (fin > inicio)
);
-- RF-04: un profesional no puede tener dos turnos vivos en el mismo horario.
CREATE UNIQUE INDEX UX_Turno_profesional_inicio
    ON Turno(profesional_id, inicio) WHERE estado IN ('confirmado','realizado');

CREATE TABLE ConsultaSinRespuesta ( -- RF-07: consultas derivadas a WhatsApp
    id       INT IDENTITY PRIMARY KEY,
    texto    NVARCHAR(200) NOT NULL,
    origen   VARCHAR(10) NOT NULL CHECK (origen IN ('terminal','recepcion')),
    creada   DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);
GO
