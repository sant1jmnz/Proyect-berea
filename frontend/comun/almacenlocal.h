/* Archivo local de esta PC (JSON): cuando no hay conexión con la base, Gestión y la
 * terminal guardan acá protocolos, turnos, profesionales y pacientes, así siguen estando
 * al volver a abrir y las dos aplicaciones ven lo mismo. Con la base conectada no se usa. */
#ifndef ALMACENLOCAL_H
#define ALMACENLOCAL_H

#include "modelo.h"

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
