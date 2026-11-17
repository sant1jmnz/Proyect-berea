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
class QLabel;
class QLineEdit;
class QPushButton;
class Repositorio;

namespace Ui { class VentanaCliente; }

class VentanaCliente : public QMainWindow
{
    Q_OBJECT

public:
    /* Protocolos que se pueden sumar a un mismo turno (los stored procedures reciben hasta 3). */
    static constexpr int MAX_PROTOCOLOS = 3;

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
    /* Los protocolos tocados en el paso 1, en el orden de la lista (hasta MAX_PROTOCOLOS por turno). */
    QVector<const Protocolo *> protocolosElegidos() const;
    void protocolosCambiaron();          /* una cirugía no se reserva directo: pide la consulta previa (RF-25) */
    void avisarCirugia(const Protocolo &cirugia);
    void sumarConsultaPrequirurgica();
    /* Lo que se va a cobrar con los protocolos y el cupón elegidos (mismas cuentas que el sitio web). */
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
    void aplicarCodigo();                /* cupón o tarjeta de regalo del paso 3 */
    void olvidarCodigo();
    void agregarACalendar();
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

    /* Con la base */
    void conectarBase();
    void horariosDeBase(const QDate &dia);
    bool confirmarEnBase(const Cuentas &c, const QVector<const Protocolo *> &elegidos, const QDateTime &inicio);
    bool buscarOCrearPaciente(int *idPaciente);

    Ui::VentanaCliente *ui;
    QVector<Protocolo> protocolos;
    QVector<int> protocolosVisibles;   /* fila de la lista → índice en `protocolos` */
    QVector<Turno> turnos;
    QString archivoLocal;
    QString buscadoActual;             /* DNI o teléfono (solo dígitos) de la última búsqueda con resultados */
    int turnoMostrado = -1;            /* índice en `turnos` del que se ve en "Buscar mi turno" */
    bool ajustandoFecha = false;       /* evita que setSelectedDate vuelva a disparar el aviso */
    QString notaHorarioOriginal;

    /* Widgets que se arman en el constructor (no están en el .ui) */
    QLabel *lblAvisoCirugia = nullptr;
    QPushButton *btnSumarConsulta = nullptr;
    QLineEdit *editCodigo = nullptr;
    QPushButton *btnAplicarCodigo = nullptr;
    QLabel *lblEstadoCodigo = nullptr;
    QPushButton *btnCalendar = nullptr;
    /* Cupón (descuento) o tarjeta de regalo (paga la seña con su saldo) aplicados en el paso 3 */
    QString cuponCodigo;
    int cuponDescuento = 0;
    QString tarjetaCodigo;
    QVector<int> ordenElegidos;          /* filas marcadas, en el orden en que se tocaron (como en el sitio) */
    bool cambiandoSeleccion = false;     /* evita que deseleccionar una cirugía vuelva a disparar el aviso */

    AvisoConexion *franja = nullptr;   /* "sin conexión con la base" */
    ConexionApp *conexion = nullptr;
    Repositorio *repositorio = nullptr;
    bool enModoBase = false;           /* true: los datos salen de la base */
};

#endif
