/* Ventana principal del apartado Gestión (PC de recepción).
 * Semana 1: interfaz y navegación entre pantallas.
 * Semana 3: las 5 validaciones de la carga de un turno (nombre, DNI,
 * teléfono, protocolo y horario). Los datos son de prueba (datosprueba.h)
 * hasta que se conecte la base. */
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
    void confirmarTurno();
    void buscarTurnos();

private:
    void irA(int pagina);
    void cargarProtocolos();
    void marcarError(QLineEdit *campo, bool hayError);
    void reiniciarCarga();
    const Protocolo *protocoloElegido() const;
    QDateTime horarioElegido() const;

    Ui::VentanaGestion *ui;
    QVector<Protocolo> protocolos;
    QVector<Turno> turnos;
};

#endif
