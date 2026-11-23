#include "avisoconexion.h"

#include <QHBoxLayout>
#include <QLabel>
#include <QPushButton>

// Franja amarilla de aviso: mensaje y botón de reintento; arranca oculta.
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

// Muestra la franja de contingencia: no hay base y los turnos nuevos quedan en este equipo.
void AvisoConexion::mostrarSinConexion(const QString &motivo, int pendientes)
{
    estaSinConexion = true;
    motivoActual = motivo;
    pendientesActuales = pendientes;
    btnReintentar->setText("Reintentar");
    btnReintentar->show();
    refrescar();
    show();
}

// Avisa que no hay sesión: se ven datos de prueba y nada se guarda; el botón pasa a 'Ingresar'.
void AvisoConexion::mostrarSinIngreso(const QString &motivo)
{
    estaSinConexion = true;
    lblMensaje->setText("⚠ " + motivo + " Mientras tanto se ven datos de prueba y lo que cargues "
                        "NO se guarda en la base.");
    btnReintentar->setText("Ingresar");
    btnReintentar->show();
    show();
}

// Con la conexión de vuelta la franja solo queda visible si hay turnos pendientes de enviar.
void AvisoConexion::mostrarConectado(int pendientes)
{
    estaSinConexion = false;
    motivoActual.clear();
    pendientesActuales = pendientes;
    btnReintentar->setText("Reintentar");
    btnReintentar->hide();
    refrescar();
    setVisible(pendientes > 0);   /* conectado y sin nada pendiente: no hace falta avisar */
}

// Actualiza la cantidad de turnos pendientes en el texto.
void AvisoConexion::actualizarPendientes(int pendientes)
{
    pendientesActuales = pendientes;
    refrescar();
}

// Texto que muestra hoy la franja.
QString AvisoConexion::texto() const
{
    return lblMensaje->text();
}

// Arma el texto según haya o no conexión, con singular/plural de los turnos pendientes.
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
