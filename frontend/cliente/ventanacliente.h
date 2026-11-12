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
    /* Los turnos se guardan en el archivo local de AlmacenLocal (el mismo que usa
     * Gestión); `archivoLocal` vacío usa el de siempre. */
    explicit VentanaCliente(QWidget *parent = nullptr, const QString &archivoLocal = QString());
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
    void recargarLocal();   /* toma del archivo los turnos que cargó o canceló Gestión */
    void guardarLocal();    /* deja los turnos (y la paciente nueva) en el archivo */

    Ui::VentanaCliente *ui;
    QVector<Protocolo> protocolos;
    QVector<int> protocolosVisibles;   /* fila de la lista → índice en `protocolos` */
    QVector<Turno> turnos;
    QString archivoLocal;
    int turnoMostrado = -1;            /* índice en `turnos` del que se ve en "Buscar mi turno" */
    bool ajustandoFecha = false;       /* evita que setSelectedDate vuelva a disparar el aviso */
    QString notaHorarioOriginal;
};

#endif
