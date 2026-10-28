/* Franja de aviso que se muestra arriba de la ventana cuando la app no llega
 * a la base (RNF-09). Dice qué pasó con palabras claras, cuántos turnos
 * quedaron guardados en este equipo y deja reintentar la conexión. */
#ifndef AVISOCONEXION_H
#define AVISOCONEXION_H

#include <QFrame>

class QLabel;
class QPushButton;

class AvisoConexion : public QFrame
{
    Q_OBJECT

public:
    explicit AvisoConexion(QWidget *parent = nullptr);

    /* Sin conexión: muestra el motivo y que se trabaja en modo contingencia. */
    void mostrarSinConexion(const QString &motivo, int pendientes);
    /* Con conexión: se oculta; si hay pendientes avisa que falta sincronizarlos. */
    void mostrarConectado(int pendientes);
    /* Solo actualiza el contador (se guardó otro turno en este equipo). */
    void actualizarPendientes(int pendientes);

    bool sinConexion() const { return estaSinConexion; }
    QString texto() const;

signals:
    void reintentar();

private:
    QLabel *lblMensaje;
    QPushButton *btnReintentar;
    bool estaSinConexion = false;
    QString motivoActual;
    int pendientesActuales = 0;
    void refrescar();
};

#endif
