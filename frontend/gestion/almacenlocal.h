/* Almacén local de pruebas: guarda en un archivo JSON de esta PC los turnos,
 * pacientes, profesionales y protocolos, para que sigan estando al cerrar y
 * volver a abrir, y para que las dos aplicaciones (Gestión y Terminal) vean
 * lo mismo. Es un reemplazo temporal: cuando se conecte la base de datos, los
 * datos pasan a salir de los stored procedures y este archivo deja de usarse. */
#ifndef ALMACENLOCAL_H
#define ALMACENLOCAL_H

#include "datosprueba.h"

#include <QString>
#include <QVector>

namespace AlmacenLocal {

struct Datos {
    QVector<Protocolo> protocolos;
    QVector<Turno> turnos;
    QVector<Profesional> profesionales;
    QVector<Paciente> pacientes;
};

/* Variable de entorno DERMALIA_DATOS_LOCAL, o <datos de la aplicación>/Dermalia/datos_local.json. */
QString rutaPorDefecto();

/* false si el archivo no existe o no se entiende (en ese caso `datos` no se toca). */
bool leer(const QString &ruta, Datos *datos);
/* Escribe en forma atómica: o queda todo el archivo nuevo o queda el anterior. */
bool guardar(const QString &ruta, const Datos &datos);

}

#endif
