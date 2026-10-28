#include "conexionapp.h"

ConexionApp::ConexionApp(AvisoConexion *franja, const ConfigBD &config,
                         const QString &archivoContingencia, QObject *parent)
    : QObject(parent), aviso(franja), base_(config), local(archivoContingencia)
{
    connect(aviso, &AvisoConexion::reintentar, this, &ConexionApp::probar);
}

bool ConexionApp::probar()
{
    const bool conectada = base_.conectar();
    if (conectada)
        aviso->mostrarConectado(local.cantidad());
    else
        aviso->mostrarSinConexion(base_.ultimoError(), local.cantidad());
    return conectada;
}

bool ConexionApp::guardarEnContingencia(const TurnoPendiente &turno)
{
    const bool guardado = local.guardar(turno);
    aviso->actualizarPendientes(local.cantidad());
    return guardado;
}
