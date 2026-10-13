/* Datos de prueba del apartado Gestión (Semana 3).
 * Todavía no hay base de datos: los protocolos y los turnos viven en memoria
 * mientras la ventana está abierta. Cuando se conecte la base (persistencia,
 * semana del 20 de octubre) este archivo se reemplaza por consultas a MySQL
 * que devuelvan lo mismo (Protocolo y Turno). */
#ifndef DATOSPRUEBA_H
#define DATOSPRUEBA_H

#include <QDateTime>
#include <QString>
#include <QStringList>
#include <QVector>

struct Protocolo {
    QString nombre;
    int duracionMin;
    int precio;
};

struct Turno {
    QString paciente;
    QString dni;
    QString telefono;   /* solo dígitos */
    QString protocolo;
    QDateTime fechaHora;
    bool senaPagada;
};

namespace DatosPrueba {

QVector<Protocolo> protocolos();
/* Turnos de ejemplo en los días siguientes a hoy. */
QVector<Turno> turnos(const QDate &hoy);
/* Horarios en que atiende el instituto, de lunes a sábado. */
QStringList horariosDelDia();

}

#endif
