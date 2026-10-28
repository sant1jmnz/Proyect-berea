#include "avisoconexion.h"

#include <QHBoxLayout>
#include <QLabel>
#include <QPushButton>

AvisoConexion::AvisoConexion(QWidget *parent)
    : QFrame(parent)
{
    setObjectName("avisoConexion");
    /* Colores en la propia franja: sirve igual en Gestión y en Cliente. */
    setStyleSheet(
        "QFrame#avisoConexion { background: #fff3cd; border: 1px solid #e0b84a; border-radius: 8px; }"
        "QFrame#avisoConexion QLabel { color: #5c4300; background: transparent; }"
        "QFrame#avisoConexion QPushButton { background: #ffffff; color: #5c4300; border: 1px solid #e0b84a;"
        " border-radius: 6px; padding: 6px 14px; font-weight: bold; }"
        "QFrame#avisoConexion QPushButton:hover { background: #fff9e6; }");

    lblMensaje = new QLabel(this);
    lblMensaje->setWordWrap(true);
    lblMensaje->setAccessibleName("Aviso de conexión con la base de datos");
    btnReintentar = new QPushButton("Reintentar", this);

    auto *capa = new QHBoxLayout(this);
    capa->setContentsMargins(12, 8, 12, 8);
    capa->addWidget(lblMensaje, 1);
    capa->addWidget(btnReintentar);

    connect(btnReintentar, &QPushButton::clicked, this, &AvisoConexion::reintentar);
    hide();
}

void AvisoConexion::mostrarSinConexion(const QString &motivo, int pendientes)
{
    estaSinConexion = true;
    motivoActual = motivo;
    pendientesActuales = pendientes;
    btnReintentar->show();
    refrescar();
    show();
}

void AvisoConexion::mostrarConectado(int pendientes)
{
    estaSinConexion = false;
    motivoActual.clear();
    pendientesActuales = pendientes;
    btnReintentar->hide();
    refrescar();
    setVisible(pendientes > 0);   /* conectado y sin nada pendiente: no hace falta avisar */
}

void AvisoConexion::actualizarPendientes(int pendientes)
{
    pendientesActuales = pendientes;
    refrescar();
}

QString AvisoConexion::texto() const
{
    return lblMensaje->text();
}

void AvisoConexion::refrescar()
{
    const QString pendientes = pendientesActuales == 1
        ? "1 turno guardado en este equipo"
        : QString("%1 turnos guardados en este equipo").arg(pendientesActuales);

    if (estaSinConexion) {
        QString t = "⚠ Sin conexión con la base de datos. " + motivoActual
                    + " Se trabaja en modo contingencia: los turnos nuevos se guardan en este equipo "
                      "y se envían cuando vuelva la conexión.";
        if (pendientesActuales > 0)
            t += " Ahora hay " + pendientes + ".";
        lblMensaje->setText(t);
    } else {
        lblMensaje->setText("Conexión recuperada. Hay " + pendientes + " pendiente de enviar a la base.");
    }
}
