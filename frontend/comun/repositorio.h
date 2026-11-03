/* Repositorio: la capa que le habla a los stored procedures de la base
 * (backend/03_sp_semana3.sql y 04_sp_semana4.sql) y devuelve datos ya
 * interpretados. Las pantallas de Gestión y Cliente usan esta clase en vez de
 * escribir CALL a mano: así hay un solo lugar donde cambia el nombre de un SP
 * o el orden de sus parámetros.
 *
 * Convención de los SP que escriben: devuelven una fila con
 *   estado ('OK'/'ERROR'), codigo, mensaje, id, valor, dato
 * y `BaseDatos::llamar` convierte el 'ERROR' en `Resultado::ok = false` con el
 * mensaje en español listo para mostrar. Acá eso se resume en `Respuesta`.
 * Catálogo de SP, parámetros y códigos de error: docs/12-contrato-sp.md. */
#ifndef REPOSITORIO_H
#define REPOSITORIO_H

#include "basedatos.h"

#include <QDate>
#include <QDateTime>
#include <QString>
#include <QTime>
#include <QVector>

/* Lo que devuelve un SP que escribe (alta, seña, cancelación...). */
struct Respuesta {
    bool ok = false;
    int codigo = 0;        /* 0 si salió bien; si no, el código del error (52xxx de las reglas) */
    QString mensaje;       /* para mostrarle a la persona */
    int id = 0;            /* lo que se creó o modificó (turno, pago, paciente...) */
    double valor = 0;      /* un monto: seña a pagar, monto reembolsado... */
    QString dato;          /* un texto: código de operación, rol, token... */
};

/* Un protocolo del catálogo, con su seña ya calculada. */
struct ProtocoloBD {
    int id = 0;
    int idCategoria = 0;
    QString nombre;
    QString descripcion;
    QString categoria;
    int precio = 0;
    int duracionMin = 0;
    int porcentajeSena = 0;
    int sena = 0;
    bool requiereEvaluacion = false;
    bool activo = true;
};

/* Un horario libre (de sp_horarios_libres). */
struct HorarioLibre {
    int idProfesional = 0;
    QString profesional;
    QDateTime inicio;
    QDateTime fin;
};

/* Una fila de sp_buscar_turnos. */
struct TurnoBD {
    int id = 0;
    QString paciente;
    QString dni;
    QString profesional;
    QDateTime inicio;
    QDateTime fin;
    QString estado;        /* pendiente, confirmado, realizado, cancelado, ausente */
    QString origen;
    QString protocolos;    /* "Peeling químico + Mesoterapia facial" */
    double precioFinal = 0;
    double sena = 0;
    QString estadoSena;    /* sin seña, pagada, reembolsada, retenida... */
    int idPaciente = 0;
    QString telefono;
    QString codigoOperacion;     /* SIM-... si la seña está paga */
    QString recordatorioCanal;   /* del último recordatorio del turno */
    QString recordatorioEstado;
    QDateTime recordatorioProgramado;
};

class Repositorio
{
public:
    explicit Repositorio(BaseDatos &base) : base(base) {}

    /* ---- seguridad ---- */
    /* La contraseña se manda como SHA-256 en hexadecimal: nunca en claro. */
    Respuesta login(const QString &usuario, const QString &clave, const QString &ip, const QString &origen);
    static QString hashClave(const QString &clave);

    /* ---- pacientes ---- */
    Respuesta altaPaciente(const QString &dni, const QString &nombre, const QString &apellido, const QDate &nacimiento,
                           const QString &email, const QString &telefono, const QString &origen, int idUsuario = 0);
    Respuesta modificarPaciente(int idPaciente, const QString &nombre, const QString &apellido, const QString &email,
                                const QString &telefonoNuevo, const QString &origen, int idUsuario = 0);
    Resultado buscarPaciente(const QString &texto);
    /* Listados completos para las pantallas (filas por nombre de columna). */
    Resultado listarPacientes();
    Resultado listarProfesionales();
    Resultado listarProfesionalProtocolo();
    Resultado listarDisponibilidad(const QDate &desde);
    Resultado listarNotificaciones(const QDate &desde, const QDate &hasta);

    /* ---- profesionales y disponibilidad ---- */
    Respuesta altaProfesional(const QString &matricula, const QString &nombre, const QString &apellido, const QString &email,
                              const QString &telefono, const QString &usuario, const QString &clave,
                              const QString &origen, int idUsuario = 0);
    Respuesta modificarProfesional(int idProfesional, const QString &nombre, const QString &apellido, const QString &email,
                                   bool activo, const QString &origen, int idUsuario = 0);
    Respuesta cargarDisponibilidad(int idProfesional, const QDate &fecha, const QTime &desde, const QTime &hasta,
                                   const QString &origen, int idUsuario = 0);
    Respuesta bajaDisponibilidad(int idDisponibilidad, const QString &origen, int idUsuario = 0);
    Respuesta asignarProtocolo(int idProfesional, int idProtocolo, bool habilitar, const QString &origen, int idUsuario = 0);
    /* n8n o la recepción informan el resultado de un aviso. */
    Respuesta marcarNotificacion(int idNotificacion, const QString &resultado, const QString &detalle = QString());

    /* ---- catálogo y profesionales ---- */
    /* `incluirBajas`: también los protocolos dados de baja (pantalla de administración). */
    QVector<ProtocoloBD> listarProtocolos(const QString &texto = QString(), int idCategoria = 0, bool incluirBajas = false);
    Respuesta altaProtocolo(int idCategoria, const QString &nombre, const QString &descripcion, double precio,
                            int duracionMin, const QString &origen, int idUsuario = 0);
    Respuesta modificarProtocolo(int idProtocolo, const QString &nombre, const QString &descripcion, double precio,
                                 int duracionMin, bool activo, const QString &origen, int idUsuario = 0);
    /* Profesionales que hacen TODOS los protocolos pedidos (RF-18). */
    Resultado profesionalesParaProtocolos(const QVector<int> &idsProtocolo);

    /* ---- agenda ---- */
    QVector<HorarioLibre> horariosLibres(const QDate &fecha, const QVector<int> &idsProtocolo, int idProfesional = 0);
    Respuesta altaTurno(int idPaciente, int idProfesional, const QDateTime &inicio, const QVector<int> &idsProtocolo,
                        const QString &origen, int idUsuario = 0, const QString &codigoCupon = QString());
    Respuesta registrarSena(int idTurno, const QString &medioPago, const QString &codigoTarjeta,
                            const QString &origen, int idUsuario = 0);
    Respuesta cancelarTurno(int idTurno, const QString &origen, int idUsuario = 0);
    QVector<TurnoBD> buscarTurnos(const QString &texto, bool soloVigentes = false);
    /* Agenda de un período (inclusive en ambos extremos). */
    QVector<TurnoBD> listarTurnos(const QDate &desde, const QDate &hasta);

    /* ---- reportes y auditoría: devuelven las filas tal cual ---- */
    Resultado reporte(const QString &sp, const QDate &desde, const QDate &hasta, const QVariantList &extra = {});
    Resultado auditoria(const QDate &desde, const QDate &hasta, const QString &tipoEvento = QString(),
                        int idUsuario = 0, int idPaciente = 0, int exitoso = -1, const QString &origen = QString());

    /* Último error de una consulta que no devuelve Respuesta (para mostrarlo). */
    QString ultimoError() const { return error; }

private:
    BaseDatos &base;
    QString error;

    static Respuesta aRespuesta(const Resultado &r);
    static TurnoBD aTurno(const QVariantMap &fila);
    static QString lista(const QVector<int> &ids);
    /* Un id que no se cargó (0) viaja a la base como NULL. */
    static QVariant idONulo(int id);
    /* Un texto vacío viaja a la base como NULL. */
    static QVariant textoONulo(const QString &texto);
};

#endif
