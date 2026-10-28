/* Ventana principal del apartado Gestión (PC de recepción).
 * Semana 1: interfaz y navegación entre pantallas.
 * Semana 2: aviso cuando la base no responde (modo contingencia) y las
 * pantallas de protocolos, profesionales con su disponibilidad y pacientes.
 * Semana 3: validaciones de la carga de un turno, seña simulada, cancelación
 * con reembolso (RF-10) y avisos de turno (RF-11). Los datos son de prueba
 * (datosprueba.h) hasta que se conecte la base. */
#ifndef VENTANAGESTION_H
#define VENTANAGESTION_H

#include "datosprueba.h"
#include "recordatorios.h"

#include <QMainWindow>

class AvisoConexion;
class ConexionApp;
class PaginaAvisos;
class PaginaPacientes;
class PaginaProfesionales;
class PaginaProtocolos;
class QLineEdit;

namespace Ui { class VentanaGestion; }

class VentanaGestion : public QMainWindow
{
    Q_OBJECT

public:
    /* `archivoContingencia` vacío: los turnos sin conexión van a la carpeta de
     * datos de la aplicación (las pruebas pasan un archivo temporal). */
    explicit VentanaGestion(QWidget *parent = nullptr, const QString &archivoContingencia = QString());
    ~VentanaGestion();

private slots:
    void cambiarSeccion(int fila);   /* menú lateral */
    void continuarPaso1();           /* valida paciente y protocolo */
    void actualizarHorarios();       /* al cambiar el día del calendario */
    void continuarPaso2();           /* valida que haya un horario elegido */
    void confirmarTurno();
    void buscarTurnos();
    void cancelarTurno();            /* RF-13 + RF-10: cancela y devuelve la seña si corresponde */
    void turnoElegido();             /* muestra el recordatorio del turno de la tabla */
    void protocolosCambiaron();      /* alta, edición o baja en la pantalla Protocolos */
    void cargarTurnoPara(const QString &nombre, const QString &dni, const QString &telefono);

private:
    void irA(int pagina);
    void cargarProtocolos();
    void marcarError(QLineEdit *campo, bool hayError);
    void reiniciarCarga();
    const Protocolo *protocoloElegido() const;
    QDateTime horarioElegido() const;
    void armarPantallasNuevas();
    QString nuevoCodigoOperacion() const;

    Ui::VentanaGestion *ui;
    QVector<Protocolo> protocolos;
    QVector<int> protocolosVisibles;   /* fila de la lista → índice en `protocolos` (sin las bajas) */
    QVector<Turno> turnos;
    QVector<int> filaATurno;           /* fila de la tabla de turnos → índice en `turnos` */
    QVector<Profesional> profesionales;
    QVector<Paciente> pacientes;
    RegistroAvisos avisos;

    AvisoConexion *franja = nullptr;
    ConexionApp *conexion = nullptr;
    PaginaProtocolos *paginaProtocolos = nullptr;
    PaginaProfesionales *paginaProfesionales = nullptr;
    PaginaPacientes *paginaPacientes = nullptr;
    PaginaAvisos *paginaAvisos = nullptr;

public:
    ConexionApp *conexionApp() const { return conexion; }
    const QVector<Turno> &listaTurnos() const { return turnos; }
};

#endif
