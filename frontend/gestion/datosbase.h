/* Datos de la base para el apartado Gestión.
 * Pasa lo que devuelven los stored procedures (comun/repositorio.h) a las mismas
 * estructuras que ya usan las pantallas con los datos de prueba (datosprueba.h):
 * así las pantallas no cambian y solo cambia de dónde salen los datos.
 * Cada función devuelve false (y deja el motivo en `error`) si la base no respondió. */
#ifndef DATOSBASE_H
#define DATOSBASE_H

#include "datosprueba.h"
#include "recordatorios.h"
#include "repositorio.h"

namespace DatosBase {

/* "Sosa, María" (como lo arma la base) → "María Sosa" (como lo muestran las pantallas). */
QString nombreYApellido(const QString &apellidoComaNombre);

bool cargarProtocolos(Repositorio &repo, QVector<Protocolo> &protocolos, QString *error);
bool cargarPacientes(Repositorio &repo, QVector<Paciente> &pacientes, QString *error);
/* Necesita los protocolos ya cargados: la base guarda ids y las pantallas usan nombres. */
bool cargarProfesionales(Repositorio &repo, const QVector<Protocolo> &protocolos,
                         QVector<Profesional> &profesionales, QString *error);
/* Turnos de los últimos y próximos `dias` días. */
bool cargarTurnos(Repositorio &repo, const QDate &hoy, int dias, QVector<Turno> &turnos, QString *error);
bool cargarAvisos(Repositorio &repo, const QDate &hoy, int dias, RegistroAvisos &avisos, QString *error);

/* Una fila de turno de la base → Turno de las pantallas. */
Turno aTurno(const TurnoBD &t);

}

#endif
