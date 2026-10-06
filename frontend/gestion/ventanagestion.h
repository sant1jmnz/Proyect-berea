/* Ventana principal del apartado Gestión (PC de recepción).
 * Semana 1: prototipo navegable, sin base. Los turnos viven en memoria. */
#ifndef VENTANAGESTION_H
#define VENTANAGESTION_H

#include "dermalia.h"

#include <QDateTime>
#include <QMainWindow>
#include <QString>
#include <QVector>

namespace Ui { class VentanaGestion; }

/* Mismos datos que la tabla Turno de db/schema.sql. */
struct Turno {
    QString paciente, dni, telefono, protocolo;
    long precio;
    QDateTime inicio, fin;
    long sena;
    bool senaPagada;
    EstadoTurno estado;
};

class VentanaGestion : public QMainWindow
{
    Q_OBJECT

public:
    explicit VentanaGestion(QWidget *parent = nullptr);
    ~VentanaGestion();

private slots:
    void cambiarSeccion(int fila);   /* menú lateral */
    void actualizarInicio();         /* números y próximos turnos del inicio */
    void actualizarBotones();        /* habilita "Continuar" cuando se puede */
    void cargarHorarios();           /* paso 2: horarios libres (RF-04) */
    void mostrarResumen();           /* paso 3: resumen y seña (RF-10) */
    void confirmarTurno();           /* RF-02, RF-09 */
    void buscarTurnos();             /* RF-13 */
    void mostrarSeleccion();         /* recordatorio del turno elegido (RF-11) */
    void cancelarTurno();            /* RF-13 */

private:
    void irA(int pagina);
    QDateTime inicioElegido() const;

    Ui::VentanaGestion *ui;
    QVector<Turno> turnos;           /* Semana 2: pasa a la tabla Turno */
};

#endif
