/* Junta lo que necesita cada apartado para saber si hay base (RNF-09):
 * la conexión (basedatos.h), los turnos guardados en el equipo
 * (contingencia.h) y la franja de aviso (avisoconexion.h). Gestión y Cliente
 * lo usan igual. */
#ifndef CONEXIONAPP_H
#define CONEXIONAPP_H

#include "avisoconexion.h"
#include "basedatos.h"
#include "contingencia.h"

#include <QObject>

class ConexionApp : public QObject
{
    Q_OBJECT

public:
    /* `archivoContingencia` vacío: carpeta de datos de la aplicación. */
    ConexionApp(AvisoConexion *aviso, const ConfigBD &config,
                const QString &archivoContingencia = QString(), QObject *parent = nullptr);

    /* Intenta conectar y actualiza la franja de aviso. true si hay base. */
    bool probar();
    bool hayConexion() const { return base_.conectado(); }

    /* Guarda un turno en este equipo (modo contingencia) y actualiza el
     * contador de la franja. true si se pudo escribir el archivo. */
    bool guardarEnContingencia(const TurnoPendiente &turno);

    BaseDatos &base() { return base_; }
    Contingencia &contingencia() { return local; }

private:
    AvisoConexion *aviso;
    BaseDatos base_;
    Contingencia local;
};

#endif
