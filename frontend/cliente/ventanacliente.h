/* Ventana principal del apartado Cliente (terminal táctil del instituto).
 * Con la base conectada, los protocolos, los horarios libres, la reserva, la
 * búsqueda y la cancelación pasan por los stored procedures (comun/repositorio.h).
 * Sin base, los turnos se guardan en el archivo local de esta PC (el mismo que
 * usa Gestión) y además quedan en contingencia para mandarlos cuando vuelva la base. */
#ifndef VENTANACLIENTE_H
#define VENTANACLIENTE_H

#include "datosprueba.h"

#include <QMainWindow>
#include <QVector>

class AvisoConexion;
class ConexionApp;
class Repositorio;

namespace Ui { class VentanaCliente; }

class QTimer;

class VentanaCliente : public QMainWindow
{
    Q_OBJECT

public:
    /* `archivoLocal` y `archivoContingencia` vacíos: los de siempre (las pruebas pasan otros). */
    explicit VentanaCliente(QWidget *parent = nullptr, const QString &archivoLocal = QString(),
                            const QString &archivoContingencia = QString());
    ~VentanaCliente();

    /* Para las pruebas. */
    const QVector<Turno> &turnosCargados() const { return turnos; }
    bool usaBase() const { return enModoBase; }
    ConexionApp *conexionApp() const { return conexion; }

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
    bool mostrarTurnosDe(const QString &buscado);   /* false si no tiene turnos */
    void mostrarTurno(int indice, int cantidad);
    void ocultarTurno();
    void cancelarMiTurno();
    QString nuevoCodigoOperacion() const;
    void recargarLocal();   /* toma del archivo los turnos que cargó o canceló Gestión */
    void guardarLocal();    /* deja los turnos (y la paciente nueva) en el archivo */

    /* Con la base */
    void conectarBase();
    void horariosDeBase(const QDate &dia);
    void sincronizarBase();            /* cada 3 segundos: trae lo que cambió Gestión */
    bool confirmarEnBase(const Protocolo *p, const QDateTime &inicio);
    bool buscarOCrearPaciente(int *idPaciente);

    Ui::VentanaCliente *ui;
    QVector<Protocolo> protocolos;
    QVector<int> protocolosVisibles;   /* fila de la lista → índice en `protocolos` */
    QVector<Turno> turnos;
    QString archivoLocal;
    QString buscadoActual;             /* DNI o teléfono (solo dígitos) de la última búsqueda con resultados */
    QString ultimoBuscado;             /* lo último que se buscó, aunque no haya tenido turnos */
    int turnoMostrado = -1;            /* índice en `turnos` del que se ve en "Buscar mi turno" */
    bool ajustandoFecha = false;       /* evita que setSelectedDate vuelva a disparar el aviso */
    QString notaHorarioOriginal;

    AvisoConexion *franja = nullptr;   /* "sin conexión con la base" */
    ConexionApp *conexion = nullptr;
    Repositorio *repositorio = nullptr;
    bool enModoBase = false;           /* true: los datos salen de la base */
    QTimer *relojBase = nullptr;
    QString resumenAgenda;             /* para saber si los turnos de la base cambiaron */
};

#endif
