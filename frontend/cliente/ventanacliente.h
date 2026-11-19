/* Ventana principal del apartado Cliente (terminal táctil del instituto).
 * Con la base conectada, los protocolos, los horarios libres, la reserva, la
 * búsqueda y la cancelación pasan por los stored procedures (comun/repositorio.h).
 * Sin base, los turnos se guardan en el archivo local de esta PC (el mismo que
 * usa Gestión) y además quedan en contingencia para mandarlos cuando vuelva la base. */
#ifndef VENTANACLIENTE_H
#define VENTANACLIENTE_H

#include "datosprueba.h"

#include "dialogocuenta.h"

#include <QMainWindow>
#include <QVector>

class AvisoConexion;
class ConexionApp;
class Repositorio;

namespace Ui { class VentanaCliente; }

class QLabel;
class QLineEdit;
class QPushButton;
class QTimer;

class VentanaCliente : public QMainWindow
{
    Q_OBJECT

public:
    /* Protocolos que se pueden sumar a un mismo turno (los stored procedures reciben hasta 3). */
    static const int MAX_PROTOCOLOS = 3;

    /* `archivoLocal` y `archivoContingencia` vacíos: los de siempre (las pruebas pasan otros). */
    explicit VentanaCliente(QWidget *parent = nullptr, const QString &archivoLocal = QString(),
                            const QString &archivoContingencia = QString());
    ~VentanaCliente();

    /* Para las pruebas. */
    const QVector<Turno> &turnosCargados() const { return turnos; }
    bool usaBase() const { return enModoBase; }
    ConexionApp *conexionApp() const { return conexion; }
    const SesionPaciente &sesionActual() const { return sesion; }

protected:
    /* Cualquier toque reinicia el tiempo de la sesión de la paciente. */
    bool eventFilter(QObject *objeto, QEvent *evento) override;

private:
    /* Partes del constructor */
    void armarMascaras();
    void conectarNavegacion();
    void armarBotonCuenta();
    void armarPasos();
    void armarCodigo();            /* cupón o tarjeta de regalo en el paso 3 */
    void armarCalendario();
    void armarMiTurno();
    void probarConexion(const QString &archivoContingencia);

    void irA(int pagina);
    void cargarProtocolos();
    /* Los protocolos tocados en el paso 1, en el orden en que se tocaron (hasta MAX_PROTOCOLOS). */
    QVector<const Protocolo *> protocolosElegidos() const;
    void protocolosCambiaron();          /* una cirugía no se reserva directo: pide la consulta previa (RF-25) */
    void avisarCirugia(const Protocolo &cirugia);
    void sumarConsultaPrequirurgica();
    /* Lo que se va a cobrar con los protocolos y el cupón elegidos (las mismas cuentas que el sitio web). */
    struct Cuentas {
        QStringList nombres;
        int total = 0;        /* suma de precios */
        int totalFinal = 0;   /* con el descuento del cupón */
        int sena = 0;         /* seña por protocolo, con el porcentaje de su categoría */
        int duracionMin = 0;
        int descuento = 0;    /* % del cupón aplicado */
        bool hayCirugia = false;
    };
    Cuentas cuentas() const;
    void pintarResumen();
    void aplicarCodigo();                /* cupón o tarjeta de regalo del paso 3 (RF-17, RF-23) */
    void olvidarCodigo();
    void agregarACalendar();             /* RF-19 */
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
    void traerTurnos(const QString &buscado);
    void mostrarRecienCargado(const QString &dni);
    void mostrarTurno(int indice, int cantidad);
    void ocultarTurno();
    void cancelarMiTurno();
    void recargarLocal();   /* toma del archivo los turnos que cargó o canceló Gestión */
    void guardarLocal();    /* deja los turnos (y la paciente nueva) en el archivo */

    /* Con la base */
    void conectarBase();
    void horariosDeBase(const QDate &dia);
    void sincronizarBase();            /* cada 3 segundos: trae lo que cambió Gestión */
    bool confirmarEnBase(const Cuentas &c, const QVector<const Protocolo *> &elegidos, const QDateTime &inicio);
    bool buscarOCrearPaciente(int *idPaciente);

    /* Cuenta de la paciente (opcional) */
    void tocarCuenta();
    void empezarSesion(const SesionPaciente &nueva);
    void cerrarSesion();
    void completarConLaCuenta();   /* nombre, DNI y teléfono de la cuenta en el paso 3 y en "mi turno" */

    Ui::VentanaCliente *ui;
    QVector<Protocolo> protocolos;
    QVector<int> protocolosVisibles;   /* fila de la lista → índice en `protocolos` */
    QVector<Turno> turnos;
    QString archivoLocal;
    QString ultimoBuscado;             /* DNI o teléfono (solo dígitos) de la última búsqueda, aunque no haya tenido turnos */
    int turnoMostrado = -1;            /* índice en `turnos` del que se ve en "Buscar mi turno" */
    bool ajustandoFecha = false;       /* evita que setSelectedDate vuelva a disparar el aviso */
    QString notaHorarioOriginal;

    /* Widgets que se arman en el constructor (no están en el .ui) */
    QLabel *lblAvisoCirugia = nullptr;
    QPushButton *btnSumarConsulta = nullptr;
    QLineEdit *editCodigo = nullptr;
    QLabel *lblEstadoCodigo = nullptr;
    QPushButton *btnCalendar = nullptr;
    /* Cupón (descuento) o tarjeta de regalo (paga la seña con su saldo) aplicados en el paso 3 */
    QString cuponCodigo;
    int cuponDescuento = 0;
    QString tarjetaCodigo;
    QVector<int> ordenElegidos;          /* filas marcadas, en el orden en que se tocaron (como en el sitio) */
    bool cambiandoSeleccion = false;     /* evita que desmarcar una cirugía vuelva a disparar el aviso */

    AvisoConexion *franja = nullptr;   /* "sin conexión con la base" */
    ConexionApp *conexion = nullptr;
    Repositorio *repositorio = nullptr;
    bool enModoBase = false;           /* true: los datos salen de la base */
    QTimer *relojBase = nullptr;
    QPushButton *btnCuenta = nullptr;  /* arriba a la derecha: "Ingresar" o "Hola, María" */
    SesionPaciente sesion;
    QTimer *relojSesion = nullptr;     /* la terminal es compartida: sin tocar nada, la sesión se cierra */
    QString resumenAgenda;             /* para saber si los turnos de la base cambiaron */
};

#endif
