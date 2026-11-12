/* Ventana principal del apartado Cliente (terminal táctil del instituto).
 * Sin base de datos todavía: los turnos viven en memoria mientras la ventana está
 * abierta (se cargan al momento y la búsqueda "Buscar mi turno" los encuentra).
 * Cuando se conecte la base, `turnos` se reemplaza por consultas a los stored procedures. */
#ifndef VENTANACLIENTE_H
#define VENTANACLIENTE_H

#include "datosprueba.h"

#include <QMainWindow>
#include <QVector>

namespace Ui { class VentanaCliente; }

class VentanaCliente : public QMainWindow
{
    Q_OBJECT

public:
    explicit VentanaCliente(QWidget *parent = nullptr);
    ~VentanaCliente();

    /* Los turnos cargados (para las pruebas). */
    const QVector<Turno> &turnosCargados() const { return turnos; }

private:
    void irA(int pagina);
    void cargarProtocolos();
    const Protocolo *protocoloElegido() const;
    QDateTime horarioElegido() const;
    void continuarProtocolo();
    void diaElegido();
    void actualizarHorarios();
    void marcarDiasPasados();
    void continuarHorario();
    bool datosValidos();
    void confirmar();
    void reiniciarCarga();
    void buscarMiTurno();
    void mostrarTurno(int indice, int cantidad);
    void ocultarTurno();
    void cancelarMiTurno();
    QString nuevoCodigoOperacion() const;

    Ui::VentanaCliente *ui;
    QVector<Protocolo> protocolos;
    QVector<int> protocolosVisibles;   /* fila de la lista → índice en `protocolos` */
    QVector<Turno> turnos;
    int turnoMostrado = -1;            /* índice en `turnos` del que se ve en "Buscar mi turno" */
    bool ajustandoFecha = false;       /* evita que setSelectedDate vuelva a disparar el aviso */
    QString notaHorarioOriginal;
};

#endif
