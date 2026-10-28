/* Datos de prueba del apartado Gestión (Semana 3).
 * Todavía no hay base de datos: los protocolos y los turnos viven en memoria
 * mientras la ventana está abierta. Cuando se conecte la base (persistencia,
 * semana del 20 de octubre) este archivo se reemplaza por consultas a MySQL
 * que devuelvan lo mismo. Las estructuras siguen las entidades de
 * docs/modelo-entidades.md (Categoría de protocolo, Protocolo, Turno). */
#ifndef DATOSPRUEBA_H
#define DATOSPRUEBA_H

#include <QDateTime>
#include <QString>
#include <QStringList>
#include <QVector>

/* Categoría de protocolo: la seña depende de ella, no del protocolo. */
struct Categoria {
    QString nombre;
    int porcentajeSena;        /* 30, o 40 en cirugías */
    bool requiereEvaluacion;   /* cirugías: consulta previa obligatoria */
};

struct Protocolo {
    QString nombre;
    int duracionMin;
    int precio;
    Categoria categoria;
};

/* Estado del turno (tabla maestra). */
enum class EstadoTurno { Confirmado, Realizado, Cancelado };

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
};

namespace DatosPrueba {

QVector<Protocolo> protocolos();
/* Turnos de ejemplo en los días siguientes a hoy. */
QVector<Turno> turnos(const QDate &hoy);
/* Horarios en que atiende el instituto, de lunes a sábado. */
QStringList horariosDelDia();

QString texto(EstadoTurno estado);

}

#endif
