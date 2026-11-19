/* Modelo de datos que usan Gestión y la terminal: las mismas entidades de la base
 * (docs/modelo-entidades.md): categoría de protocolo, protocolo, profesional, paciente
 * y turno. Con la base, se llenan desde los stored procedures (datosbase.h); sin base,
 * desde el archivo local de la PC (almacenlocal.h). */
#ifndef MODELO_H
#define MODELO_H

#include "disponibilidad.h"

#include <QDateTime>
#include <QString>
#include <QStringList>
#include <QVector>

/* Categoría de protocolo: la seña depende de ella, no del protocolo. */
struct Categoria {
    QString nombre;
    int porcentajeSena;        /* 30, o 40 en cirugías */
    bool requiereEvaluacion;   /* cirugías: consulta previa obligatoria */
    int id = 0;                /* id en la base (0 = dato de prueba) */
};

struct Protocolo {
    QString nombre;
    int duracionMin;
    int precio;
    Categoria categoria;
    bool activo = true;        /* una baja lo oculta, no lo borra: los turnos viejos lo siguen mostrando */
    int id = 0;                /* id en la base (0 = dato de prueba) */
    QString descripcion;       /* texto del catálogo (solo con datos de la base) */
};

/* Profesional: qué protocolos hace (RF-18) y cuándo atiende (RF-03). */
struct Profesional {
    QString nombre;
    QString matricula;
    bool activo;
    QStringList protocolos;    /* nombres de los protocolos que realiza */
    QVector<Franja> franjas;
    QString email;             /* solo con datos de la base */
    int id = 0;                /* id en la base (0 = dato de prueba) */
};

/* Paciente (la cuenta es opcional; se identifica por DNI). */
struct Paciente {
    QString nombre;
    QString dni;
    QString telefono;          /* solo dígitos */
    QString email;             /* opcional */
    QDate nacimiento;
    int id = 0;                /* id en la base (0 = dato de prueba) */
};

/* Estado del turno (tabla maestra). */
/* Pendiente (sin seña) y Ausente existen solo cuando los datos vienen de la base. */
enum class EstadoTurno { Confirmado, Realizado, Cancelado, Pendiente, Ausente };

struct Turno {
    QString paciente;
    QString dni;
    QString telefono;       /* solo dígitos */
    QString protocolo;
    int precioAplicado;     /* precio del protocolo al momento de reservar */
    int sena;               /* seña calculada al reservar (porcentaje de la categoría) */
    QDateTime inicio;
    QDateTime fin;          /* inicio + duración del protocolo */
    EstadoTurno estado;
    QString origen;         /* Origen (tabla maestra): Gestión, Terminal, Web */
    bool senaPagada;
    QString codigoOperacion;   /* de la seña (mock): SIM-000123; vacío si no se pagó */
    int reembolsado = 0;       /* seña devuelta al cancelar (RF-10) */
    int id = 0;                /* id del turno en la base (0 = dato de prueba) */
    int idPaciente = 0;
    QString profesional;       /* quién atiende (solo con datos de la base) */
};

#endif
