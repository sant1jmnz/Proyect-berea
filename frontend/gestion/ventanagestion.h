/* Ventana principal del apartado Gestión (PC de recepción).
 * Semana 1: interfaz y navegación entre pantallas.
 * Semana 3: validaciones de los datos de la paciente, cálculo y registro
 * simulado de la seña, búsqueda y cancelación con reembolso. Los datos son
 * de prueba (datosprueba.h) hasta que se conecte la base. */
#ifndef VENTANAGESTION_H
#define VENTANAGESTION_H

#include "datosprueba.h"

#include <QMainWindow>

class QLineEdit;

namespace Ui { class VentanaGestion; }

class VentanaGestion : public QMainWindow
{
    Q_OBJECT

public:
    explicit VentanaGestion(QWidget *parent = nullptr);
    ~VentanaGestion();

private slots:
    void cambiarSeccion(int fila);   /* menú lateral */
    void continuarPaso1();           /* valida paciente y protocolo */
    void actualizarHorarios();       /* al cambiar el día del calendario */
    void continuarPaso2();           /* valida que haya un horario elegido */
    void registrarSena();            /* pago simulado (RF-09) */
    void confirmarTurno();
    void buscarTurnos();
    void cancelarTurno();            /* con reembolso o retención (RF-10) */
    void mostrarRecordatorio();      /* turno elegido en la tabla (RF-11) */

private:
    void irA(int pagina);
    void cargarProtocolos();
    void marcarError(QLineEdit *campo, bool hayError);
    void reiniciarCarga();
    void actualizarBotonSena();
    const Protocolo *protocoloElegido() const;
    QDateTime horarioElegido() const;

    Ui::VentanaGestion *ui;
    QVector<Protocolo> protocolos;
    QVector<Turno> turnos;
    QVector<int> filasTabla;     /* fila de tablaTurnos → índice en `turnos` */

    /* Seña del turno que se está cargando. */
    bool senaPagada = false;
    QString medioPago;
    QString comprobante;
    int proximoComprobante = 101;
};

#endif
