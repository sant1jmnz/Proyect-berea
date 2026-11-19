/* Datos de ejemplo y catálogo inicial. El catálogo es el mismo de la base y del sitio
 * web (sale de comun/fichas.generado.json); los turnos, profesionales y pacientes de
 * ejemplo solo los usan las pruebas. También están las conversiones del modelo que
 * comparten las dos aplicaciones (texto de un estado, protocolo → tratamiento). */
#ifndef DATOSPRUEBA_H
#define DATOSPRUEBA_H

#include "modelo.h"
#include "resumentratamiento.h"

namespace DatosPrueba {

QVector<Categoria> categorias();
QVector<Protocolo> protocolos();
/* Turnos de ejemplo en los días siguientes a hoy. */
QVector<Turno> turnos(const QDate &hoy);
QVector<Profesional> profesionales(const QDate &hoy);
QVector<Paciente> pacientes();
/* Horarios en que atiende el instituto, de lunes a sábado. */
QStringList horariosDelDia();

QString texto(EstadoTurno estado);

/* Los protocolos activos, como los usa el resumen y el buscador de precios (comun/). */
QVector<Tratamiento> comoTratamientos(const QVector<Protocolo> &protocolos);
Tratamiento comoTratamiento(const Protocolo &p);

}

#endif
