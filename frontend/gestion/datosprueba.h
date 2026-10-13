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
    bool esCirugia;
};

enum class EstadoTurno { Confirmado, Realizado, Cancelado };
enum class EstadoSena { Pendiente, Pagada, Reembolsada, Retenida };

struct Turno {
    QString paciente;
    QString dni;
    QString telefono;   /* solo dígitos */
    QString protocolo;
    QDateTime fechaHora;
    int duracionMin;
    int sena;
    EstadoSena estadoSena;
    QString medioPago;  /* vacío mientras la seña está pendiente */
    QString comprobante;
    EstadoTurno estado;
};

namespace DatosPrueba {

QVector<Protocolo> protocolos();
/* Turnos de ejemplo armados a partir de hoy, así siempre hay uno a más de
 * 24 h (la seña se reembolsa) y otro a menos (no se reembolsa). */
QVector<Turno> turnos(const QDateTime &ahora);
/* Horarios en que atiende el instituto, de lunes a sábado. */
QStringList horariosDelDia();
QStringList mediosDePago();

QString texto(EstadoTurno estado);
QString texto(EstadoSena estado);

}

#endif
