#include "ventanacliente.h"
#include "dialogoasistente.h"
#include "ui_ventanacliente.h"

#include "almacenlocal.h"
#include "avisoconexion.h"
#include "conexionapp.h"
#include "datosbase.h"
#include "formato.h"
#include "reglasturno.h"
#include "dialogocuenta.h"
#include "repositorio.h"
#include "reembolso.h"
#include "sena.h"
#include "validaciones.h"

#include <QApplication>
#include <QCalendarWidget>
#include <QDesktopServices>
#include <QHBoxLayout>
#include <QInputDialog>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMessageBox>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QEventLoop>
#include <QTimer>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPushButton>
#include <QRandomGenerator>
#include <QRegularExpressionValidator>
#include <QStyle>
#include <QTextCharFormat>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>
#include <QVBoxLayout>
#include <algorithm>

/* Orden de las páginas dentro del QStackedWidget `paginas` del .ui. */
enum Pagina { PagInicio, PagProtocolo, PagHorario, PagConfirmar, PagBuscador, PagMiTurno };

/* Primer año en que se pueden sacar turnos. */
static const int ANIO_INICIAL = 2026;

/* Primer mes que se puede elegir: el actual (los meses que ya pasaron quedan bloqueados),
 * y nunca antes de enero de 2026. */
static QDate primerMesElegible()
{
    const QDate hoy = QDate::currentDate();
    return std::max(QDate(ANIO_INICIAL, 1, 1), QDate(hoy.year(), hoy.month(), 1));
}

/* Cuánto dura la sesión de la paciente sin tocar la terminal (es una terminal compartida). */
static const int MINUTOS_SESION = 3;

/* "¡Listo! Tu turno quedó reservado. Peeling químico · jueves 8 de octubre de 2026, 10:00" */
static QString mensajeReservado(const QString &protocolo, const QDateTime &inicio)
{
    return QString("¡Listo! Tu turno quedó reservado.\n%1 · %2, %3")
        .arg(protocolo, Formato::fechaLarga(inicio.date(), true), inicio.toString("HH:mm"));
}

/* Enlace del bot de Telegram (GET /api/estado); vacío si no hay API, bot o respuesta en 2 s. */
static QString enlaceTelegram()
{
    QNetworkAccessManager red;
    QNetworkReply *r = red.get(QNetworkRequest(QUrl(DialogoAsistente::urlPorDefecto() + "/api/estado")));
    QEventLoop espera;
    QTimer::singleShot(2000, &espera, &QEventLoop::quit);
    QObject::connect(r, &QNetworkReply::finished, &espera, &QEventLoop::quit);
    espera.exec();
    QString enlace;
    if (r->isFinished() && r->error() == QNetworkReply::NoError)
        enlace = QJsonDocument::fromJson(r->readAll()).object().value("telegram").toString();
    r->abort();
    r->deleteLater();
    return enlace;
}

/* Constructor de la pantalla del cliente (la terminal). Arma todo en este orden:
 *  * máscaras de los campos, navegación, botón de cuenta, pasos, código de cupón, calendario y 'Mi turno';
 *  * después carga datos locales/catálogo y prueba la conexión a la base (si falla, queda en modo contingencia). */
VentanaCliente::VentanaCliente(QWidget *parent, const QString &archivo, const QString &archivoContingencia)
    : QMainWindow(parent), ui(new Ui::VentanaCliente),
      archivoLocal(archivo.isEmpty() ? AlmacenLocal::rutaPorDefecto() : archivo)
{
    ui->setupUi(this);   /* crea todos los widgets dibujados en el .ui */

    /* Sábado y domingo vienen en rojo: los dejamos como el resto. */
    ui->calendario->setWeekdayTextFormat(Qt::Saturday, QTextCharFormat());
    ui->calendario->setWeekdayTextFormat(Qt::Sunday, QTextCharFormat());

    Formato::sombrearTarjetas(this, ui->hero);   /* sombra suave debajo de cada tarjeta, igual que en Gestión */

    armarMascaras();
    conectarNavegacion();
    armarBotonCuenta();
    armarPasos();
    armarCodigo();
    armarCalendario();
    armarMiTurno();

    /* Sin base arranca con el archivo local; el catálogo y los horarios ya se muestran. */
    recargarLocal();
    cargarProtocolos();
    actualizarHorarios();

    probarConexion(archivoContingencia);
}

/* Máscaras de entrada: mientras se escribe solo entran los caracteres válidos
 * (sin números en el nombre, sin letras en el DNI ni en el teléfono). */
void VentanaCliente::armarMascaras()
{
    ui->editNombre->setMaxLength(60);
    ui->editNombre->setValidator(new QRegularExpressionValidator(Validaciones::filtroNombre(), this));
    ui->editDni->setMaxLength(8);
    ui->editDni->setValidator(new QRegularExpressionValidator(Validaciones::filtroDni(), this));
    ui->editTelefono->setMaxLength(14);
    ui->editTelefono->setValidator(new QRegularExpressionValidator(Validaciones::filtroTelefono(), this));
    ui->editBuscarTurno->setMaxLength(14);
    ui->editBuscarTurno->setValidator(new QRegularExpressionValidator(Validaciones::filtroTelefono(), this));
}

/* Señales y slots: connect(quién avisa, qué pasó, quién reacciona, qué hace).
 * Franja de arriba (Inicio, Ayuda) y las tres opciones de la pantalla de inicio. */
void VentanaCliente::conectarNavegacion()
{
    /* Franja de arriba: "Inicio" vuelve al principio desde cualquier pantalla. */
    connect(ui->btnInicio, &QPushButton::clicked, this, [this] { irA(PagInicio); });
    connect(ui->btnAyuda, &QPushButton::clicked, this, [this] {
        QMessageBox::information(this, "Ayuda",
            "Sacar un turno: elegí el protocolo, después el horario y confirmá.\n"
            "Buscar mi turno: con tu DNI o tu teléfono; desde ahí lo podés cancelar.\n"
            "Ingresar (arriba): tu cuenta es opcional; con ella no escribís tus datos y ves tus turnos al instante.\n"
            "Ver resumen: qué es cada tratamiento, cuántas sesiones lleva y qué hacer antes y después.\n"
            "Si necesitás una mano, acercate a la recepción.");
    });

    /* Las opciones de la pantalla de inicio. */
    connect(ui->btnSacarTurno, &QPushButton::clicked, this, [this] { irA(PagProtocolo); });
    connect(ui->btnVerPrecios, &QPushButton::clicked, this, [this] { irA(PagBuscador); });
    connect(ui->btnMiTurno, &QPushButton::clicked, this, [this] {
        irA(PagMiTurno);
        if (sesion.activa() && !mostrarTurnosDe(sesion.dni))   /* con cuenta, sus turnos aparecen solos */
            ocultarTurno();
    });

    /* Tercera opción, al lado de las otras dos: el asistente de IA (RF-14). */
    btnAsistente = new QPushButton("Preguntale\nal asistente");
    btnAsistente->setObjectName("btnAsistente");
    btnAsistente->setProperty("opcion", true);
    btnAsistente->setIcon(QIcon(":/iconos/asistente.svg"));
    btnAsistente->setIconSize(QSize(28, 28));
    btnAsistente->setCursor(Qt::PointingHandCursor);
    ui->layoutOpciones->addWidget(btnAsistente);
    for (QPushButton *b : { ui->btnVerPrecios, ui->btnMiTurno, btnAsistente })   /* las tres del mismo ancho */
        b->setSizePolicy(QSizePolicy::Ignored, b->sizePolicy().verticalPolicy());
    ui->layoutOpciones->setStretch(2, 1);
    connect(btnAsistente, &QPushButton::clicked, this, [this] {
        DialogoAsistente dialogo(this);
        dialogo.exec();
    });
}

/* Cuenta de la paciente, arriba a la derecha: solo con la base (ahí se guardan las cuentas). */
void VentanaCliente::armarBotonCuenta()
{
    btnCuenta = new QPushButton("Ingresar");
    btnCuenta->setObjectName("btnCuenta");
    btnCuenta->setCursor(Qt::PointingHandCursor);
    btnCuenta->setToolTip("Ingresá o creá tu cuenta (es opcional)");
    btnCuenta->hide();
    ui->layoutBarra->insertWidget(ui->layoutBarra->indexOf(ui->btnAyuda), btnCuenta);
    connect(btnCuenta, &QPushButton::clicked, this, &VentanaCliente::tocarCuenta);
    relojSesion = new QTimer(this);
    relojSesion->setSingleShot(true);
    relojSesion->setInterval(MINUTOS_SESION * 60 * 1000);
    connect(relojSesion, &QTimer::timeout, this, [this] {
        cerrarSesion();
        irA(PagInicio);
    });
    qApp->installEventFilter(this);
}

/* Los 3 pasos de sacar un turno (RF-01): Continuar avanza, Volver retrocede. */
void VentanaCliente::armarPasos()
{
    connect(ui->btnVolver1, &QPushButton::clicked, this, [this] { irA(PagInicio); });
    connect(ui->btnContinuar1, &QPushButton::clicked, this, &VentanaCliente::continuarProtocolo);
    /* Paso 1: hasta MAX_PROTOCOLOS protocolos por turno, como en el sitio web: se tocan para marcarlos. */
    ui->listaProtocolos->setSelectionMode(QAbstractItemView::MultiSelection);
    connect(ui->listaProtocolos, &QListWidget::itemSelectionChanged, this, &VentanaCliente::protocolosCambiaron);

    /* Aviso de las cirugías (RF-25): una cirugía empieza con una consulta prequirúrgica paga. */
    lblAvisoCirugia = new QLabel(this);
    lblAvisoCirugia->setObjectName("lblAvisoCirugia");
    lblAvisoCirugia->setProperty("rol", "nota");
    lblAvisoCirugia->setWordWrap(true);
    lblAvisoCirugia->hide();
    btnSumarConsulta = new QPushButton("Reservar la consulta prequirúrgica", this);
    btnSumarConsulta->setObjectName("btnSumarConsulta");
    btnSumarConsulta->setCursor(Qt::PointingHandCursor);
    btnSumarConsulta->hide();
    ui->layoutProtocolos->addWidget(lblAvisoCirugia);
    ui->layoutProtocolos->addWidget(btnSumarConsulta);
    connect(btnSumarConsulta, &QPushButton::clicked, this, &VentanaCliente::sumarConsultaPrequirurgica);

    /* "Ver resumen" del último tratamiento tocado (el mismo resumen que la web). */
    auto *btnResumen = new QPushButton("Ver resumen");
    btnResumen->setObjectName("btnResumen1");
    btnResumen->setCursor(Qt::PointingHandCursor);
    btnResumen->setEnabled(false);
    ui->botonesProtocolo->insertWidget(ui->botonesProtocolo->indexOf(ui->btnVolver1), btnResumen);
    connect(ui->listaProtocolos, &QListWidget::itemSelectionChanged, this, [this, btnResumen] {
        btnResumen->setEnabled(!protocolosElegidos().isEmpty());
    });
    connect(btnResumen, &QPushButton::clicked, this, [this] {
        const QVector<const Protocolo *> elegidos = protocolosElegidos();
        if (elegidos.isEmpty())
            return;
        ResumenTratamiento::mostrar(this, DatosPrueba::comoTratamiento(*elegidos.last()),
                                    ResumenTratamiento::precioConsulta(DatosPrueba::comoTratamientos(protocolos)));
    });
    connect(ui->btnVolver2, &QPushButton::clicked, this, [this] { irA(PagProtocolo); });
    connect(ui->btnContinuar2, &QPushButton::clicked, this, &VentanaCliente::continuarHorario);
    connect(ui->btnVolver3, &QPushButton::clicked, this, [this] { irA(PagHorario); });
    connect(ui->btnConfirmar, &QPushButton::clicked, this, &VentanaCliente::confirmar);

    /* El botón de la seña queda apretado (checkable): cambia el texto (RF-08). */
    connect(ui->btnSena, &QPushButton::toggled, this, [this](bool pagada) {
        ui->btnSena->setText(pagada ? "✓  Seña pagada" : "Pagar seña");
    });
}

/* Cupón o tarjeta de regalo (RF-17, RF-23), en la tarjeta de la seña del paso 3. */
void VentanaCliente::armarCodigo()
{
    editCodigo = new QLineEdit(this);
    editCodigo->setObjectName("editCodigo");
    editCodigo->setMaxLength(40);
    editCodigo->setPlaceholderText("¿Tenés un cupón o una tarjeta de regalo? Escribí el código");
    auto *btnAplicar = new QPushButton("Aplicar", this);
    btnAplicar->setObjectName("btnAplicarCodigo");
    btnAplicar->setCursor(Qt::PointingHandCursor);
    auto *filaCodigo = new QHBoxLayout;
    filaCodigo->addWidget(editCodigo, 1);
    filaCodigo->addWidget(btnAplicar);
    lblEstadoCodigo = new QLabel(this);
    lblEstadoCodigo->setObjectName("lblEstadoCodigo");
    lblEstadoCodigo->setProperty("rol", "nota");
    lblEstadoCodigo->setWordWrap(true);
    ui->layoutSena->insertLayout(3, filaCodigo);   /* en el hueco, antes del espacio y del botón */
    ui->layoutSena->insertWidget(4, lblEstadoCodigo);
    connect(btnAplicar, &QPushButton::clicked, this, &VentanaCliente::aplicarCodigo);
    connect(editCodigo, &QLineEdit::returnPressed, this, &VentanaCliente::aplicarCodigo);
    connect(editCodigo, &QLineEdit::textChanged, this, &VentanaCliente::olvidarCodigo);   /* si cambia, hay que volver a aplicarlo */
}

/* Calendario: solo desde el mes actual (y desde 2026); si se elige un día ya pasado de este mes,
 * se ofrece el mismo día del año que viene. */
void VentanaCliente::armarCalendario()
{
    notaHorarioOriginal = ui->lblNotaHorario->text();
    ui->calendario->setMinimumDate(primerMesElegible());   /* meses pasados bloqueados; para ese mes, se usa el año que viene */
    ui->calendario->setSelectedDate(QDate::currentDate());
    marcarDiasPasados();
    connect(ui->calendario, &QCalendarWidget::selectionChanged, this, &VentanaCliente::diaElegido);
}

/* Buscar mi turno: con el botón o con Enter; se puede cancelar desde ahí. */
void VentanaCliente::armarMiTurno()
{
    /* "Agregar a Google Calendar" (RF-19), igual que en el sitio: abre el evento con el turno cargado. */
    btnCalendar = new QPushButton("Agregar a Google Calendar", this);
    btnCalendar->setObjectName("btnCalendar");
    btnCalendar->setCursor(Qt::PointingHandCursor);
    btnCalendar->setEnabled(false);
    ui->layoutCancelar->insertWidget(1, btnCalendar);
    /* Aviso por Telegram: abre el bot (el enlace viene de GET /api/estado). */
    btnTelegram = new QPushButton("Recibir avisos por Telegram", this);
    btnTelegram->setCursor(Qt::PointingHandCursor);
    btnTelegram->setEnabled(false);
    ui->layoutCancelar->insertWidget(2, btnTelegram);
    connect(btnTelegram, &QPushButton::clicked, this, [this] {
        const QString enlace = enlaceTelegram();
        if (enlace.isEmpty())
            QMessageBox::information(this, "Telegram", "El bot de Telegram no está disponible en este momento.");
        else
            QDesktopServices::openUrl(QUrl(enlace));
    });
    connect(btnCalendar, &QPushButton::clicked, this, &VentanaCliente::agregarACalendar);

    ui->editBuscarTurno->clear();   /* no hay turnos hasta que se cargan */
    ocultarTurno();
    connect(ui->btnBuscarTurno, &QPushButton::clicked, this, &VentanaCliente::buscarMiTurno);
    connect(ui->editBuscarTurno, &QLineEdit::returnPressed, this, &VentanaCliente::buscarMiTurno);
    connect(ui->btnCancelarMiTurno, &QPushButton::clicked, this, &VentanaCliente::cancelarMiTurno);
}

/* Sin conexión: a los turnos de este equipo se suman los de la última lectura de la base,
 * así no se ofrece un horario que la base ya tenía ocupado. */
static QVector<Turno> conAgendaDeBase(const QVector<Turno> &locales, const QVector<Turno> &deBase)
{
    QVector<Turno> todos = deBase;
    todos += locales;
    return todos;
}

/* Franja de aviso arriba de todo y conexión con la base (RNF-09). La terminal no pide
 * usuario: la paciente se identifica con su DNI. La conexión se prueba apenas se
 * muestra la ventana, para no demorar el arranque. */
void VentanaCliente::probarConexion(const QString &archivoContingencia)
{
    franja = new AvisoConexion;
    franja->setObjectName("avisoConexion");
    qobject_cast<QVBoxLayout *>(ui->central->layout())->insertWidget(0, franja);
    conexion = new ConexionApp(franja, ConfigBD::desdeEntorno(), archivoContingencia, this);
    connect(conexion, &ConexionApp::conectada, this, &VentanaCliente::conectarBase);
    connect(conexion, &ConexionApp::conexionPerdida, this, [this] {   /* sin base: los turnos nuevos quedan en este equipo */
        enModoBase = false;
        if (relojBase)
            relojBase->stop();
    });
    connect(conexion, &ConexionApp::relojDesfasado, this, [this](int minutos) {
        QMessageBox::warning(this, "Reloj del equipo",
            QString("El reloj de este equipo difiere %1 minutos de la hora de la base (%2).\n\n"
                    "Los turnos de \"hoy\" y los horarios libres se calculan con la hora de este equipo: "
                    "conviene corregirla. Es solo un aviso.")
                .arg(qAbs(minutos)).arg(minutos > 0 ? "adelantado" : "atrasado"));
    });
    QTimer::singleShot(0, conexion, &ConexionApp::probar);
}

/* Destructor: libera el Repositorio y la interfaz del .ui. */
VentanaCliente::~VentanaCliente()
{
    delete repositorio;
    delete ui;
}

/* Cambia de pantalla: pagina es una de las constantes PagInicio, PagProtocolo, ... (índice del QStackedWidget 'paginas' del .ui). */
void VentanaCliente::irA(int pagina)
{
    ui->paginas->setCurrentIndex(pagina);
}


/* ---------------------------------------------------------------------------
 * Carga de un turno en memoria
 * --------------------------------------------------------------------------- */

/* Vuelve a leer el archivo: Gestión pudo haber cargado o cancelado turnos. */
void VentanaCliente::recargarLocal()
{
    if (enModoBase)
        return;   /* con la base, los turnos se piden a la base en cada búsqueda */
    AlmacenLocal::Datos datos;
    if (!AlmacenLocal::leer(archivoLocal, &datos))
        return;
    turnos = datos.turnos;
    if (turnoMostrado >= turnos.size())
        turnoMostrado = -1;
}

/* Deja los turnos en el archivo sin pisar lo que es de Gestión (protocolos, profesionales). */
void VentanaCliente::guardarLocal()
{
    if (enModoBase)
        return;
    AlmacenLocal::Datos datos;
    AlmacenLocal::leer(archivoLocal, &datos);
    datos.turnos = turnos;
    if (datos.protocolos.isEmpty())
        datos.protocolos = protocolos;
    for (const Turno &t : std::as_const(turnos)) {   /* quien saca turno queda como paciente */
        const bool conocida = std::any_of(datos.pacientes.cbegin(), datos.pacientes.cend(),
                                          [&](const Paciente &p) { return p.dni == t.dni; });
        if (!conocida)
            datos.pacientes.append({ t.paciente, t.dni, t.telefono, QString(), QDate() });
    }
    if (!AlmacenLocal::guardar(archivoLocal, datos))
        QMessageBox::warning(this, "No se pudo guardar",
                             "El turno quedó cargado, pero no se pudo guardar en el archivo local de este equipo.");
}

/* La lista de protocolos sale del catálogo guardado (el mismo de Gestión); la primera vez, el inicial. */
void VentanaCliente::cargarProtocolos()
{
    protocolos = DatosPrueba::protocolos();
    AlmacenLocal::Datos guardados;
    QString error;
    if (enModoBase)   /* catálogo de la base (sp_listar_protocolos) */
        DatosBase::cargarProtocolos(*repositorio, protocolos, &error);
    else if (AlmacenLocal::leer(archivoLocal, &guardados) && !guardados.protocolos.isEmpty())
        protocolos = guardados.protocolos;
    ui->listaProtocolos->clear();
    protocolosVisibles.clear();
    for (int i = 0; i < protocolos.size(); ++i) {
        if (!protocolos[i].activo)
            continue;
        protocolosVisibles << i;
        ui->listaProtocolos->addItem(QString("%1\n%2 min · %3")
                                         .arg(protocolos[i].nombre).arg(protocolos[i].duracionMin).arg(Formato::pesos(protocolos[i].precio)));
    }
    ui->listaProtocolos->setCurrentRow(-1);
    ui->buscador->setCatalogo(DatosPrueba::comoTratamientos(protocolos));   /* "Consultar precios" usa el mismo catálogo */
}

/* Devuelve los tratamientos marcados en la lista, en el orden en que se tocaron (máximo MAX_PROTOCOLOS). */
QVector<const Protocolo *> VentanaCliente::protocolosElegidos() const
{
    QVector<const Protocolo *> elegidos;
    for (int fila : ordenElegidos)
        if (fila < protocolosVisibles.size() && ui->listaProtocolos->item(fila)->isSelected())
            elegidos << &protocolos[protocolosVisibles[fila]];
    return elegidos;
}

/* Fila de la consulta prequirúrgica (la que se reserva antes de cualquier cirugía), o -1. */
static int filaDeConsultaPrequirurgica(const QVector<Protocolo> &protocolos, const QVector<int> &visibles)
{
    for (int fila = 0; fila < visibles.size(); ++fila)
        if (Formato::sinTildes(protocolos[visibles[fila]].nombre).startsWith("consulta prequirurgica"))
            return fila;
    return -1;
}

/* Toda cirugía necesita una consulta prequirúrgica antes (RF-25): no se reserva directo. Si se toca una,
 * se desmarca y se ofrece la consulta. Además, un turno lleva hasta MAX_PROTOCOLOS protocolos. */
void VentanaCliente::protocolosCambiaron()
{
    if (cambiandoSeleccion)
        return;
    cambiandoSeleccion = true;
    /* Se actualiza el orden en que se tocaron: salen los que se desmarcaron y entran los nuevos. */
    QVector<int> vigentes;
    for (int fila : ordenElegidos)
        if (fila < ui->listaProtocolos->count() && ui->listaProtocolos->item(fila)->isSelected())
            vigentes << fila;
    for (int fila = 0; fila < ui->listaProtocolos->count() && fila < protocolosVisibles.size(); ++fila)
        if (ui->listaProtocolos->item(fila)->isSelected() && !vigentes.contains(fila))
            vigentes << fila;
    ordenElegidos = vigentes;

    const Protocolo *cirugia = nullptr;
    bool tope = false;
    int i = 0;
    while (i < ordenElegidos.size()) {
        const int fila = ordenElegidos[i];
        const Protocolo &p = protocolos[protocolosVisibles[fila]];
        if (!p.categoria.requiereEvaluacion && i < MAX_PROTOCOLOS) {
            ++i;
            continue;
        }
        if (p.categoria.requiereEvaluacion)
            cirugia = &p;
        else
            tope = true;
        ui->listaProtocolos->item(fila)->setSelected(false);   /* la cirugía o el que pasó el tope no se marca */
        ordenElegidos.removeAt(i);
    }
    cambiandoSeleccion = false;
    if (cirugia) {
        avisarCirugia(*cirugia);
    } else if (tope) {
        lblAvisoCirugia->setText(QString("Podés sumar hasta %1 protocolos en un mismo turno.").arg(MAX_PROTOCOLOS));
        lblAvisoCirugia->show();
        btnSumarConsulta->hide();
    } else {
        lblAvisoCirugia->hide();
        btnSumarConsulta->hide();
    }
}

/* Si el tratamiento tocado es una cirugía, muestra el aviso (RF-25): primero hace falta una consulta prequirúrgica paga.
 *  * Si esa consulta existe en el catálogo ofrece un botón para sumarla; si no, manda a la recepción. */
void VentanaCliente::avisarCirugia(const Protocolo &cirugia)
{
    const int fila = filaDeConsultaPrequirurgica(protocolos, protocolosVisibles);
    if (fila < 0) {
        lblAvisoCirugia->setText(QString("%1 necesita una consulta prequirúrgica antes. Pedila en la recepción.").arg(cirugia.nombre));
        lblAvisoCirugia->show();
        btnSumarConsulta->hide();
        return;
    }
    const Protocolo &consulta = protocolos[protocolosVisibles[fila]];
    lblAvisoCirugia->setText(QString("%1 empieza con una consulta prequirúrgica de %2, con su propia seña. Solo se agenda la cirugía "
                                     "si la evaluación da \"apto\". Si seguís con la cirugía, el valor de la consulta se devuelve.")
                                 .arg(cirugia.nombre, Formato::pesos(consulta.precio)));
    lblAvisoCirugia->show();
    btnSumarConsulta->show();
}

/* Botón 'sumar consulta': marca en la lista la consulta prequirúrgica y oculta el aviso. */
void VentanaCliente::sumarConsultaPrequirurgica()
{
    const int fila = filaDeConsultaPrequirurgica(protocolos, protocolosVisibles);
    if (fila < 0)
        return;
    lblAvisoCirugia->hide();
    btnSumarConsulta->hide();
    ui->listaProtocolos->item(fila)->setSelected(true);
    ui->listaProtocolos->scrollToItem(ui->listaProtocolos->item(fila));
}

/* Las cuentas del turno: seña por protocolo con el porcentaje de su categoría y el descuento
 * del cupón (las mismas que hace el sitio web). */
VentanaCliente::Cuentas VentanaCliente::cuentas() const
{
    Cuentas c;
    c.descuento = cuponDescuento;
    for (const Protocolo *p : protocolosElegidos()) {
        const int conDescuento = qRound(p->precio * (100 - c.descuento) / 100.0);
        c.nombres << p->nombre;
        c.total += p->precio;
        c.totalFinal += conDescuento;
        c.sena += Sena::calcular(conDescuento, p->categoria.porcentajeSena);
        c.duracionMin += p->duracionMin;
        c.hayCirugia = c.hayCirugia || p->categoria.requiereEvaluacion;
    }
    return c;
}

/* Muestra en el paso 3 lo que se va a reservar y cobrar. */
void VentanaCliente::pintarResumen()
{
    const Cuentas c = cuentas();
    const QDateTime inicio = horarioElegido();
    ui->lblResProtocolo->setText(c.nombres.join(" + "));
    if (inicio.isValid()) {
        ui->lblResFecha->setText(Formato::fechaLarga(inicio.date(), true));
        ui->lblResHora->setText(QString("%1 (%2 min)").arg(inicio.toString("HH:mm")).arg(c.duracionMin));
    }
    ui->lblResPrecio->setText(c.descuento ? QString("%1 (cupón −%2 %)").arg(Formato::pesos(c.totalFinal)).arg(c.descuento)
                                          : Formato::pesos(c.totalFinal));
    ui->lblSena->setText(Formato::pesos(c.sena));
    ui->lblReglaSena->setText(QString("%1. Te la devolvemos si cancelás con más de 24 h.")
                                  .arg(c.hayCirugia ? "40 % en cirugías, 30 % en el resto" : "30 % del total"));
    ui->lblNotaSena->setText(tarjetaCodigo.isEmpty() ? "Se paga al confirmar el turno."
                                                     : "La seña se descuenta del saldo de tu tarjeta de regalo.");
}

/* Borra el cupón o la tarjeta aplicados (y su descuento). Se llama cuando cambia la selección y el descuento ya no valdría. */
void VentanaCliente::olvidarCodigo()
{
    const bool habiaCodigo = !cuponCodigo.isEmpty() || !tarjetaCodigo.isEmpty() || cuponDescuento != 0;
    cuponCodigo.clear();
    cuponDescuento = 0;
    tarjetaCodigo.clear();
    lblEstadoCodigo->clear();
    if (habiaCodigo)
        pintarResumen();
}

/* Cupón (descuento) o tarjeta de regalo (paga la seña), revisados contra la base (RF-17, RF-23).
 * Sin base solo existe el cupón de ejemplo BIENVENIDA. Mismos mensajes que el sitio web. */
void VentanaCliente::aplicarCodigo()
{
    const QString codigo = editCodigo->text().trimmed().toUpper();
    cuponCodigo.clear();
    cuponDescuento = 0;
    tarjetaCodigo.clear();
    QString mensaje;
    if (codigo.isEmpty()) {
        lblEstadoCodigo->clear();
        pintarResumen();
        return;
    }
    if (!enModoBase) {
        if (codigo == "BIENVENIDA") {
            cuponCodigo = codigo;
            cuponDescuento = 10;
            mensaje = "Cupón aplicado: 10 % de descuento en tu primer turno.";
        } else {
            mensaje = "Ese código no existe o ya se usó. Revisá que esté bien escrito.";
        }
        lblEstadoCodigo->setText(mensaje);
        pintarResumen();
        return;
    }
    const Resultado tarjeta = repositorio->saldoTarjeta(codigo, "terminal");
    if (!tarjeta.ok) {
        mensaje = tarjeta.error;
    } else if (!tarjeta.filas.isEmpty()) {
        const QVariantMap f = tarjeta.filas.first();
        const int saldo = qRound(f.value("saldo").toDouble());
        if (f.value("vigente").toInt() == 1 && saldo > 0) {
            tarjetaCodigo = codigo;
            mensaje = QString("Tarjeta de regalo aplicada: tiene %1 de saldo y la seña se descuenta de ahí.").arg(Formato::pesos(saldo));
        } else {
            mensaje = "Esa tarjeta de regalo está vencida o sin saldo.";
        }
    } else if (!Validaciones::dniValido(ui->editDni->text())) {
        mensaje = "Escribí tu DNI primero: los cupones son personales.";
    } else {
        const Resultado cupones = repositorio->listarCupones(Validaciones::soloDigitos(ui->editDni->text()));
        QVariantMap cupon;
        for (const QVariantMap &f : cupones.filas)
            if (f.value("codigo").toString().toUpper() == codigo)
                cupon = f;
        if (!cupones.ok) {
            mensaje = cupones.error;
        } else if (cupon.isEmpty()) {
            mensaje = "Ese código no existe o es de otra paciente. Revisá que esté bien escrito.";
        } else if (cupon.value("usado").toInt() == 1) {
            mensaje = "Ese cupón ya se usó.";
        } else if (cupon.value("vigente").toInt() != 1) {
            mensaje = "Ese cupón está vencido.";
        } else {
            cuponCodigo = codigo;
            cuponDescuento = qRound(cupon.value("porcentaje_descuento").toDouble());
            mensaje = QString("Cupón aplicado: %1 % de descuento.").arg(cuponDescuento);
        }
    }
    lblEstadoCodigo->setText(mensaje);
    pintarResumen();
}

/* Devuelve fecha y hora del horario marcado en la lista. Con la base, la fecha viaja dentro del ítem; sin base se arma con el día del calendario + el texto 'HH:mm'. Devuelve vacío si no hay ninguno. */
QDateTime VentanaCliente::horarioElegido() const
{
    const QListWidgetItem *item = ui->listaHorarios->currentItem();
    if (!item || !item->isSelected() || !(item->flags() & Qt::ItemIsSelectable))
        return {};
    if (item->data(Qt::UserRole).isValid())   /* con la base, el horario viaja dentro del ítem */
        return item->data(Qt::UserRole).toDateTime();
    return QDateTime(ui->calendario->selectedDate(), QTime::fromString(item->text(), "HH:mm"));
}

/* Botón 'Continuar' del paso 1: exige al menos un tratamiento y pasa al paso de horarios. */
void VentanaCliente::continuarProtocolo()
{
    const Cuentas c = cuentas();
    if (c.nombres.isEmpty()) {
        QMessageBox::warning(this, "Falta el protocolo", "Tocá el tratamiento que querés hacerte para continuar.");
        return;
    }
    ui->lblPasoHorario->setText(QString("%1 (%2 min)").arg(c.nombres.join(" + ")).arg(c.duracionMin));
    actualizarHorarios();
    irA(PagHorario);
}

/* Los días anteriores a hoy se ven en gris en el calendario. */
void VentanaCliente::marcarDiasPasados()
{
    QTextCharFormat gris;
    gris.setForeground(QColor(176, 164, 158));
    const QDate hoy = QDate::currentDate();
    for (QDate dia = primerMesElegible(); dia < hoy; dia = dia.addDays(1))
        ui->calendario->setDateTextFormat(dia, gris);
}

/* Si el día elegido ya pasó, se avisa y se ofrece el mismo día y horario del año que viene. */
void VentanaCliente::diaElegido()
{
    if (ajustandoFecha)
        return;
    const QDate dia = ui->calendario->selectedDate();
    const QDate hoy = QDate::currentDate();
    if (dia < hoy) {
        QDate proxima = dia.addYears(1);
        while (proxima < hoy)
            proxima = proxima.addYears(1);
        const bool mesPasado = dia.year() < hoy.year() || dia.month() < hoy.month();
        const QString que = mesPasado
            ? QString("El mes de %1 ya pasó para este año (%2).").arg(QLocale().monthName(dia.month()), QString::number(dia.year()))
            : QString("El %1 de %2 ya pasó este año (%3).").arg(dia.day()).arg(QLocale().monthName(dia.month())).arg(dia.year());
        QMessageBox pregunta(QMessageBox::Question, "Esa fecha ya pasó",
                             QString("%1\n\n¿Querés ese mes, día y horario para el año que viene (%2)?\nSería el %3.")
                                 .arg(que).arg(proxima.year()).arg(Formato::fechaLarga(proxima, true)),
                             QMessageBox::NoButton, this);
        QPushButton *si = pregunta.addButton(QString("Sí, para %1").arg(proxima.year()), QMessageBox::YesRole);
        pregunta.addButton("No, elegir otro día", QMessageBox::NoRole);
        pregunta.exec();
        ajustandoFecha = true;
        ui->calendario->setSelectedDate(pregunta.clickedButton() == si ? proxima : hoy);
        ajustandoFecha = false;
    }
    actualizarHorarios();
}

/* RF-04: solo se ofrecen los horarios libres del día elegido (no los que ya pasaron ni los ocupados). */
void VentanaCliente::actualizarHorarios()
{
    const QDate dia = ui->calendario->selectedDate();
    recargarLocal();   /* horarios que Gestión ocupó o liberó */
    ui->listaHorarios->clear();
    ui->lblNotaHorario->setText(notaHorarioOriginal);

    if (dia.dayOfWeek() == Qt::Sunday) {
        ui->lblNotaHorario->setText("Los domingos el instituto no atiende. Elegí otro día.");
        return;
    }
    if (enModoBase) {   /* los horarios libres los calcula la base (RF-04) */
        horariosDeBase(dia);
        return;
    }
    ui->listaHorarios->addItems(ReglasTurno::horariosLibresSinBase(dia, conAgendaDeBase(turnos, agendaDeBase),
                                                                   QDateTime::currentDateTime()));
    if (ui->listaHorarios->count() == 0)
        ui->lblNotaHorario->setText("No quedan horarios libres ese día. Probá con otro.");
}

/* Botón 'Continuar' del paso 2: exige un horario elegido y pasa al paso de datos personales. */
void VentanaCliente::continuarHorario()
{
    const QDateTime inicio = horarioElegido();
    if (protocolosElegidos().isEmpty()) {
        irA(PagProtocolo);
        return;
    }
    if (!inicio.isValid()) {
        QMessageBox::warning(this, "Falta el horario", "Elegí un día y tocá un horario libre.");
        return;
    }
    pintarResumen();
    irA(PagConfirmar);
}

/* Nombre y apellido, DNI y teléfono: se avisa todo lo que está mal. */
bool VentanaCliente::datosValidos()
{
    QString errorNombre, errorDni, errorTelefono;
    Validaciones::nombreApellidoValido(ui->editNombre->text(), &errorNombre);
    Validaciones::dniValido(ui->editDni->text(), &errorDni);
    Validaciones::telefonoValido(ui->editTelefono->text(), &errorTelefono);
    QStringList errores;
    QLineEdit *primero = nullptr;
    const struct { QLineEdit *campo; QString error; } revisiones[] = {
        { ui->editNombre, errorNombre }, { ui->editDni, errorDni }, { ui->editTelefono, errorTelefono } };
    for (const auto &r : revisiones) {
        if (r.error.isEmpty())
            continue;
        errores << "• " + r.error;
        if (!primero)
            primero = r.campo;
    }
    if (errores.isEmpty())
        return true;
    QMessageBox::warning(this, "Revisá tus datos", errores.join("\n"));
    primero->setFocus();
    return false;
}

/* Paso 3: se valida, se carga el turno al momento y se muestra en "Buscar mi turno". */
void VentanaCliente::confirmar()
{
    const QVector<const Protocolo *> elegidos = protocolosElegidos();
    const QDateTime inicio = horarioElegido();
    if (elegidos.isEmpty() || !inicio.isValid()) {   /* no debería pasar: los pasos anteriores ya lo revisan */
        irA(PagProtocolo);
        return;
    }
    if (!datosValidos())
        return;
    if (inicio <= QDateTime::currentDateTime()) {
        QMessageBox::warning(this, "Horario vencido", "Ese horario ya pasó. Elegí otro.");
        actualizarHorarios();
        irA(PagHorario);
        return;
    }
    if (enModoBase) {
        if (confirmarEnBase(cuentas(), elegidos, inicio))
            mostrarRecienCargado(Validaciones::soloDigitos(ui->editDni->text()));
        return;
    }
    recargarLocal();
    if (ReglasTurno::horarioOcupado(conAgendaDeBase(turnos, agendaDeBase), inicio)) {
        QMessageBox::warning(this, "Horario ocupado", "Ese horario ya no está libre. Elegí otro.");
        actualizarHorarios();
        irA(PagHorario);
        return;
    }

    const Cuentas c = cuentas();
    Turno nuevo = { ui->editNombre->text().simplified(), Validaciones::soloDigitos(ui->editDni->text()),
                    Validaciones::soloDigitos(ui->editTelefono->text()), c.nombres.join(" + "), c.totalFinal,
                    c.sena, inicio, inicio.addSecs(c.duracionMin * 60), EstadoTurno::Confirmado, "Terminal",
                    ui->btnSena->isChecked(), QString(), 0 };
    if (nuevo.senaPagada)
        nuevo.codigoOperacion = ReglasTurno::nuevoCodigoOperacion(turnos);
    turnos.append(nuevo);
    guardarLocal();
    /* Sin base, el turno también queda en contingencia: se manda solo cuando vuelve la conexión (RNF-09). */
    conexion->guardarEnContingencia({ nuevo.paciente, nuevo.dni, nuevo.telefono, nuevo.protocolo,
                                      nuevo.inicio, nuevo.sena, nuevo.senaPagada, nuevo.origen });

    QString mensaje = mensajeReservado(nuevo.protocolo, inicio);
    mensaje += nuevo.senaPagada ? QString("\nSeña pagada: código %1.").arg(nuevo.codigoOperacion)
                                : "\nLa seña quedó sin pagar: acercate a recepción para abonarla.";
    QMessageBox::information(this, "Turno confirmado", mensaje);

    mostrarRecienCargado(nuevo.dni);
}

/* Después de reservar: la carga queda en blanco y se muestra el turno en "Mi turno". */
void VentanaCliente::mostrarRecienCargado(const QString &dni)
{
    reiniciarCarga();
    ui->editBuscarTurno->setText(dni);
    buscarMiTurno();
    irA(PagMiTurno);
}

/* Deja los 3 pasos en blanco para el próximo turno. */
void VentanaCliente::reiniciarCarga()
{
    ui->editNombre->clear();
    ui->editDni->clear();
    ui->editTelefono->clear();
    ui->listaProtocolos->clearSelection();
    ui->listaProtocolos->setCurrentRow(-1);
    lblAvisoCirugia->hide();
    btnSumarConsulta->hide();
    editCodigo->clear();   /* también olvida el cupón o la tarjeta */
    ui->btnSena->setChecked(false);
    completarConLaCuenta();
    ajustandoFecha = true;
    ui->calendario->setSelectedDate(QDate::currentDate());
    ajustandoFecha = false;
    actualizarHorarios();
}

/* ---------------------------------------------------------------------------
 * Buscar mi turno y cancelarlo
 * --------------------------------------------------------------------------- */

/* Esconde la tarjeta de 'Mi turno' y desactiva los botones de Google Calendar y Telegram. */
void VentanaCliente::ocultarTurno()
{
    turnoMostrado = -1;
    ui->tarjetaMiTurno->setVisible(false);
    btnCalendar->setEnabled(false);
    btnTelegram->setEnabled(false);
}

/* El mismo enlace que arma el sitio web: abre Google Calendar con el turno cargado (RF-19). */
void VentanaCliente::agregarACalendar()
{
    if (turnoMostrado < 0 || turnoMostrado >= turnos.size())
        return;
    const Turno &t = turnos[turnoMostrado];
    const QString formato = "yyyyMMdd'T'HHmm'00'";
    QUrlQuery datos;
    datos.addQueryItem("action", "TEMPLATE");
    datos.addQueryItem("text", "Turno en Dermalia: " + t.protocolo);
    datos.addQueryItem("dates", t.inicio.toString(formato) + "/" + t.fin.toString(formato));
    datos.addQueryItem("ctz", "America/Argentina/Buenos_Aires");
    datos.addQueryItem("details", "Recordá llegar 10 minutos antes. Si necesitás cancelar, hacelo con más de 24 h para que te devolvamos la seña.");
    datos.addQueryItem("location", "Dermalia, Instituto de Estética Médica, Flores, CABA");
    QUrl url("https://calendar.google.com/calendar/render");
    url.setQuery(datos);
    QDesktopServices::openUrl(url);
}

/* Por DNI o teléfono, sin contraseña (RF-12). Se muestra el próximo turno vigente
 * o, si no hay, el último que tuvo. */
void VentanaCliente::buscarMiTurno()
{
    const QString texto = ui->editBuscarTurno->text().trimmed();
    QString errorDni, errorTel;
    if (!Validaciones::dniValido(texto, &errorDni) && !Validaciones::telefonoValido(texto, &errorTel)) {
        ocultarTurno();
        QMessageBox::warning(this, "Dato incorrecto",
                             "Ingresá un DNI (7 u 8 dígitos) o un teléfono (10 a 13 dígitos), solo números.");
        ui->editBuscarTurno->setFocus();
        return;
    }
    const QString buscado = Validaciones::soloDigitos(texto);
    if (!mostrarTurnosDe(buscado)) {
        ocultarTurno();
        QMessageBox::information(this, "Sin turnos", QString("No encontramos turnos para %1.").arg(buscado));
    }
}

/* Los turnos de ese DNI o teléfono: con la base, de sp_buscar_turnos; sin base, del archivo local. */
void VentanaCliente::traerTurnos(const QString &buscado)
{
    recargarLocal();
    if (!enModoBase)
        return;
    turnos.clear();
    for (const TurnoBD &fila : repositorio->buscarTurnos(buscado))
        turnos.append(DatosBase::aTurno(fila));
}

/* true si el turno es de quien se buscó (por DNI o por teléfono). */
static bool esDe(const Turno &t, const QString &buscado)
{
    return t.dni == buscado || Validaciones::soloDigitos(t.telefono) == buscado;
}

/* Muestra el próximo turno vigente de ese DNI o teléfono o, si no hay, el último que tuvo. */
bool VentanaCliente::mostrarTurnosDe(const QString &buscado)
{
    const QDateTime ahora = QDateTime::currentDateTime();
    ultimoBuscado = buscado;
    traerTurnos(buscado);
    QVector<int> encontrados;
    for (int i = 0; i < turnos.size(); ++i)
        if (esDe(turnos[i], buscado))
            encontrados << i;
    if (encontrados.isEmpty())
        return false;
    int elegido = -1;
    int vigentes = 0;
    for (int i : encontrados) {
        if (!ReglasTurno::esVigente(turnos[i], ahora))
            continue;
        ++vigentes;
        if (elegido < 0 || turnos[i].inicio < turnos[elegido].inicio)
            elegido = i;
    }
    if (elegido < 0)   /* ninguno vigente: se muestra el más reciente */
        elegido = *std::max_element(encontrados.cbegin(), encontrados.cend(),
                                    [&](int a, int b) { return turnos[a].inicio < turnos[b].inicio; });
    mostrarTurno(elegido, vigentes);
    return true;
}

/* Pinta la tarjeta de 'Mi turno' con el turno de la posición indice (próximo o último, estado, seña y botones). */
void VentanaCliente::mostrarTurno(int indice, int vigentes)
{
    turnoMostrado = indice;
    const Turno &t = turnos[indice];
    const bool activo = (t.estado == EstadoTurno::Confirmado || t.estado == EstadoTurno::Pendiente) && t.inicio > QDateTime::currentDateTime();

    QString titulo = activo ? "Tu próximo turno" : "Tu último turno";
    if (vigentes > 1)
        titulo += QString(" · tenés %1 turnos").arg(vigentes);
    ui->lblMiTurno->setText(titulo);
    ui->lblEstadoTurno->setText(DatosPrueba::texto(t.estado));
    ui->lblEstadoTurno->setProperty("etiqueta", t.estado == EstadoTurno::Confirmado || t.estado == EstadoTurno::Realizado ? "ok" : "pendiente");
    ui->lblEstadoTurno->style()->unpolish(ui->lblEstadoTurno);
    ui->lblEstadoTurno->style()->polish(ui->lblEstadoTurno);
    ui->lblResTurnoPaciente->setText(t.paciente);
    ui->lblResTurnoProtocolo->setText(t.protocolo);
    ui->lblResTurnoFecha->setText(Formato::fechaLarga(t.inicio.date(), true));
    ui->lblResTurnoHora->setText(QString("%1 (%2 min)").arg(t.inicio.toString("HH:mm")).arg(t.inicio.secsTo(t.fin) / 60));
    QString sena = Formato::pesos(t.sena) + (t.senaPagada ? " · pagada" : " · sin pagar");
    if (t.estado == EstadoTurno::Cancelado && t.senaPagada)
        sena = t.reembolsado > 0 ? QString("%1 · reembolsada").arg(Formato::pesos(t.reembolsado)) : QString("%1 · no reembolsable").arg(Formato::pesos(t.sena));
    ui->lblResTurnoSena->setText(sena);
    if (t.estado == EstadoTurno::Cancelado) {
        ui->lblRecordatorio->setText("Turno cancelado: ya no te enviamos recordatorios.");
    } else if (t.inicio <= QDateTime::currentDateTime()) {
        ui->lblRecordatorio->setText("Este turno ya pasó.");
    } else {
        const QDateTime aviso = t.inicio.addDays(-1);
        ui->lblRecordatorio->setText(QString("Te lo vamos a recordar el %1 a las %2.").arg(Formato::fechaLarga(aviso.date()), aviso.toString("HH:mm")));
    }
    ui->btnCancelarMiTurno->setEnabled(activo);
    btnCalendar->setEnabled(activo);
    btnTelegram->setEnabled(activo);
    ui->tarjetaMiTurno->setVisible(true);
}

/* Texto de un turno para elegirlo en la lista de cancelación. */
static QString descripcionTurno(const Turno &t)
{
    return QString("%1 · %2 · %3 hs · seña %4")
        .arg(t.protocolo, Formato::fechaLarga(t.inicio.date(), true), t.inicio.toString("HH:mm"),
             t.senaPagada ? "pagada" : "sin pagar");
}

/* Cancelar: si la persona tiene más de un turno vigente, primero elige cuál; después confirma.
 * RF-10: más de 24 h de anticipación y seña pagada → se devuelve el 100%; si no, queda retenida. */
void VentanaCliente::cancelarMiTurno()
{
    traerTurnos(ultimoBuscado);   /* puede haber cambiado desde que se mostró */
    const QDateTime ahora = QDateTime::currentDateTime();
    QVector<int> vigentes;   /* turnos de quien buscó que todavía se pueden cancelar */
    for (int i = 0; i < turnos.size(); ++i)
        if (esDe(turnos[i], ultimoBuscado) && ReglasTurno::esVigente(turnos[i], ahora))
            vigentes << i;
    std::sort(vigentes.begin(), vigentes.end(), [this](int a, int b) { return turnos[a].inicio < turnos[b].inicio; });
    if (vigentes.isEmpty()) {
        QMessageBox::information(this, "Nada para cancelar", "No tenés turnos vigentes para cancelar.");
        buscarMiTurno();
        return;
    }

    int elegido = vigentes.first();
    if (vigentes.size() > 1) {   /* varios turnos: se elige cuál cancelar */
        QStringList opciones;
        for (int i = 0; i < vigentes.size(); ++i)
            opciones << QString("%1) %2").arg(i + 1).arg(descripcionTurno(turnos[vigentes[i]]));
        QInputDialog eleccion(this);
        eleccion.setWindowTitle("¿Qué turno querés cancelar?");
        eleccion.setLabelText(QString("Tenés %1 turnos. Elegí el que querés cancelar:").arg(vigentes.size()));
        eleccion.setComboBoxItems(opciones);
        eleccion.setOkButtonText("Seguir");
        eleccion.setCancelButtonText("Volver");
        if (eleccion.exec() != QDialog::Accepted)
            return;
        const int posicion = opciones.indexOf(eleccion.textValue());
        if (posicion < 0)
            return;
        elegido = vigentes[posicion];
    }

    Turno &t = turnos[elegido];
    const int devolver = Reembolso::monto(t.sena, t.senaPagada, t.inicio, ahora);
    const QString regla = ReglasTurno::explicacionReembolso(t, ahora);

    const auto respuesta = QMessageBox::question(this, "Cancelar turno",
        QString("¿Querés cancelar este turno?\n\n%1\n\n%2").arg(descripcionTurno(t), regla));
    if (respuesta != QMessageBox::Yes)
        return;

    if (enModoBase) {   /* la base aplica la regla de las 24 horas y devuelve la seña */
        const Respuesta r = repositorio->cancelarTurno(t.id, "terminal");
        if (!r.ok) {
            QMessageBox::warning(this, "No se pudo cancelar", r.mensaje);
            return;
        }
        QMessageBox::information(this, "Turno cancelado",
                                 r.valor > 0 ? QString("Turno cancelado. Se te devolvieron %1.").arg(Formato::pesos(qRound(r.valor)))
                                             : "Turno cancelado.");
        buscarMiTurno();
        return;
    }
    t.estado = EstadoTurno::Cancelado;
    t.reembolsado = devolver;
    guardarLocal();
    actualizarHorarios();              /* el horario vuelve a estar libre */
    QMessageBox::information(this, "Turno cancelado",
                             devolver > 0 ? QString("Turno cancelado. Se te devolvieron %1.").arg(Formato::pesos(devolver)) : "Turno cancelado.");
    buscarMiTurno();                   /* muestra el próximo turno que le queda, o el cancelado si no tiene más */
}


/* ---------------------------------------------------------------------------
 * Con la base conectada: los datos salen de los stored procedures
 * --------------------------------------------------------------------------- */

/* Se llama cada vez que ConexionApp logra conectarse (al arrancar o con "Reintentar"). */
void VentanaCliente::conectarBase()
{
    if (enModoBase)
        return;   /* ya estaba conectada */
    if (!repositorio)
        repositorio = new Repositorio(conexion->base());
    enModoBase = true;
    QString errorAgenda;
    DatosBase::cargarTurnos(*repositorio, QDate::currentDate(), ReglasTurno::DIAS_AGENDA, agendaDeBase, &errorAgenda);
    cargarProtocolos();
    actualizarHorarios();
    ocultarTurno();

    btnCuenta->show();

    /* Gestión y la Terminal usan la misma base: cada 3 segundos se mira si cambió algo. */
    if (!relojBase) {
        relojBase = new QTimer(this);
        relojBase->setInterval(ReglasTurno::MS_SINCRONIZAR);
        connect(relojBase, &QTimer::timeout, this, &VentanaCliente::sincronizarBase);
    }
    relojBase->start();
}

/* Si Gestión cambió el catálogo, o alguien cargó o canceló un turno, se actualiza
 * lo que se está viendo sin perder lo que la paciente ya eligió. */
void VentanaCliente::sincronizarBase()
{
    if (!enModoBase || QApplication::activeModalWidget())
        return;   /* con un cartel abierto se espera a la próxima vuelta */
    QString error;

    /* Catálogo: precios, altas y bajas de protocolos. */
    QVector<Protocolo> catalogo;
    if (DatosBase::cargarProtocolos(*repositorio, catalogo, &error)
        && DatosBase::resumen(catalogo) != DatosBase::resumen(protocolos)) {
        QVector<int> idsElegidos;   /* se vuelven a marcar en el mismo orden */
        for (const Protocolo *p : protocolosElegidos())
            idsElegidos << p->id;
        cargarProtocolos();
        for (int id : idsElegidos)
            for (int fila = 0; fila < protocolosVisibles.size(); ++fila)
                if (protocolos[protocolosVisibles[fila]].id == id)
                    ui->listaProtocolos->item(fila)->setSelected(true);
    }

    /* Turnos: si cambiaron, se recalculan los horarios libres y "mi turno". */
    QVector<Turno> agenda;
    if (!DatosBase::cargarTurnos(*repositorio, QDate::currentDate(), ReglasTurno::DIAS_AGENDA, agenda, &error))
        return;
    agendaDeBase = agenda;   /* queda como respaldo por si se corta la conexión */
    const QString resumen = DatosBase::resumen(agenda);
    if (resumen == resumenAgenda)
        return;
    resumenAgenda = resumen;

    const QListWidgetItem *horario = ui->listaHorarios->currentItem();
    const QString horarioElegido = horario && horario->isSelected() ? horario->text() : QString();
    actualizarHorarios();
    Formato::volverAElegir(ui->listaHorarios, horarioElegido);

    /* "Buscar mi turno": si la paciente ya buscó (aunque todavía no tuviera turnos), se vuelve
     * a buscar; así aparece el turno que le cargó la recepción o cambia el estado si se canceló. */
    const bool mirandoMiTurno = ui->paginas->currentIndex() == PagMiTurno || turnoMostrado >= 0;
    if (mirandoMiTurno && !ultimoBuscado.isEmpty() && !mostrarTurnosDe(ultimoBuscado))
        ocultarTurno();
}

/* Horarios libres del día para el protocolo elegido, con el profesional que atiende. */
void VentanaCliente::horariosDeBase(const QDate &dia)
{
    QVector<int> ids;
    for (const Protocolo *p : protocolosElegidos())
        ids << p->id;
    if (ids.isEmpty()) {
        ui->lblNotaHorario->setText("Elegí primero el protocolo.");
        return;
    }
    /* La base devuelve un horario por cada profesional libre: a la paciente se le
     * muestra cada hora una sola vez, con el primer profesional que la tiene libre.
     * Con varios protocolos, solo salen los profesionales que hacen todos (RF-18). */
    QStringList yaMostradas;
    for (const HorarioLibre &h : repositorio->horariosLibres(dia, ids)) {
        const QString hora = h.inicio.toString("HH:mm");
        if (h.inicio <= QDateTime::currentDateTime() || yaMostradas.contains(hora))
            continue;
        yaMostradas << hora;
        auto *item = new QListWidgetItem(hora);
        item->setToolTip("Con " + DatosBase::nombreYApellido(h.profesional));
        item->setData(Qt::UserRole, h.inicio);               /* cuándo */
        item->setData(Qt::UserRole + 1, h.idProfesional);    /* con quién */
        ui->listaHorarios->addItem(item);
    }
    if (ui->listaHorarios->count() == 0)
        ui->lblNotaHorario->setText("No quedan horarios libres ese día. Probá con otro.");
}

/* Si el DNI ya está en la base se usa esa paciente; si no, se la da de alta.
 * El apellido sale de la última palabra del nombre; la fecha de nacimiento se pregunta. */
bool VentanaCliente::buscarOCrearPaciente(int *idPaciente)
{
    const QString dni = Validaciones::soloDigitos(ui->editDni->text());
    const Resultado r = repositorio->buscarPaciente(dni);
    if (!r.ok) {   /* si la base falló no se sabe si existe: no se da de alta para no duplicarla */
        QMessageBox::warning(this, "No pudimos buscar tus datos", r.error);
        return false;
    }
    for (const QVariantMap &fila : r.filas) {
        if (fila.value("dni").toString() == dni) {
            *idPaciente = fila.value("id_paciente").toInt();
            return true;
        }
    }

    QString nombre, apellido;
    Formato::separarNombre(ui->editNombre->text(), &nombre, &apellido);

    QDate nacimiento;
    QString texto;
    for (;;) {   /* se vuelve a preguntar hasta que la fecha sea válida o la paciente cancele */
        bool ok = false;
        texto = QInputDialog::getText(this, "Es tu primera vez",
                                      QString("Hola %1. ¿Cuál es tu fecha de nacimiento? (dd/mm/aaaa)").arg(nombre),
                                      QLineEdit::Normal, texto, &ok);
        if (!ok)
            return false;
        QString error;
        nacimiento = Validaciones::fechaDesdeTexto(texto, &error);
        if (nacimiento.isValid() && Validaciones::fechaNacimientoValida(nacimiento, QDate::currentDate(), &error))
            break;
        QMessageBox::warning(this, "Fecha incorrecta", error);
    }
    const Respuesta alta = repositorio->altaPaciente(dni, nombre, apellido, nacimiento, QString(),
                                                     Validaciones::soloDigitos(ui->editTelefono->text()), "terminal");
    if (!alta.ok) {
        QMessageBox::warning(this, "No pudimos guardar tus datos", alta.mensaje);
        return false;
    }
    *idPaciente = alta.id;
    return true;
}

/* Paso 3 con la base: sp_alta_turno y, si tocó "Pagar seña", sp_registrar_seña. */
bool VentanaCliente::confirmarEnBase(const Cuentas &c, const QVector<const Protocolo *> &elegidos, const QDateTime &inicio)
{
    int idPaciente = 0;
    if (!buscarOCrearPaciente(&idPaciente))
        return false;

    QVector<int> ids;
    for (const Protocolo *p : elegidos)
        ids << p->id;
    const int idProfesional = ui->listaHorarios->currentItem()->data(Qt::UserRole + 1).toInt();
    const Respuesta turno = repositorio->altaTurno(idPaciente, idProfesional, inicio, ids, "terminal", 0, cuponCodigo);
    if (!turno.ok) {   /* la base aplicó una regla (por ejemplo, otra persona se llevó ese horario) */
        QMessageBox::warning(this, "No pudimos reservar el turno", turno.mensaje);
        actualizarHorarios();
        irA(PagHorario);
        return false;
    }

    QString mensaje = mensajeReservado(c.nombres.join(" + "), inicio);
    if (ui->btnSena->isChecked()) {
        /* Con una tarjeta de regalo la seña sale de su saldo; si no, se paga con tarjeta. */
        const bool conTarjeta = !tarjetaCodigo.isEmpty();
        const Respuesta sena = repositorio->registrarSena(turno.id, conTarjeta ? "tarjeta de regalo" : "tarjeta",
                                                          tarjetaCodigo, "terminal");
        mensaje += sena.ok ? QString("\nSeña pagada%1: código %2.").arg(conTarjeta ? " con tu tarjeta de regalo" : "", sena.dato)
                           : QString("\nLa seña no se pudo registrar (%1): acercate a recepción.").arg(sena.mensaje);
    } else {
        mensaje += "\nLa seña quedó sin pagar: acercate a recepción para abonarla.";
    }
    const QString telegram = enlaceTelegram();
    /* Texto enriquecido para que el enlace al bot se pueda tocar (abre el navegador). */
    QString html = mensaje.toHtmlEscaped().replace("\n", "<br>");
    if (!telegram.isEmpty())
        html += "<br>Recibí los avisos de tu turno por Telegram: <a href=\"" + telegram.toHtmlEscaped() + "\">" + telegram.toHtmlEscaped() + "</a>";
    QMessageBox aviso(QMessageBox::Information, "Turno confirmado", html, QMessageBox::Ok, this);
    aviso.setTextFormat(Qt::RichText);
    aviso.exec();
    return true;
}


/* ---------------------------------------------------------------------------
 * Cuenta de la paciente (opcional, RF-15)
 * --------------------------------------------------------------------------- */

/* Sin sesión abre "Ingresar / Crear cuenta"; con sesión pregunta si se quiere salir. */
void VentanaCliente::tocarCuenta()
{
    if (!repositorio)
        return;
    if (sesion.activa()) {
        const auto r = QMessageBox::question(this, "Tu cuenta",
            QString("Ingresaste como %1.\n¿Querés salir de tu cuenta?").arg(sesion.nombre));
        if (r == QMessageBox::Yes)
            cerrarSesion();
        return;
    }
    DialogoCuenta dialogo(repositorio, this);
    if (dialogo.exec() == QDialog::Accepted)
        empezarSesion(dialogo.sesion());
}

void VentanaCliente::empezarSesion(const SesionPaciente &nueva)
{
    sesion = nueva;
    btnCuenta->setText("Hola, " + sesion.nombre.section(' ', 0, 0));
    btnCuenta->setToolTip("Tocá para salir de tu cuenta");
    completarConLaCuenta();
    relojSesion->start();
}

/* Cierra la sesión del paciente: avisa a la base (queda en el log), limpia los campos y vuelve el botón a 'Ingresar'. */
void VentanaCliente::cerrarSesion()
{
    if (!sesion.activa())
        return;
    if (repositorio)
        repositorio->cerrarSesion(sesion.idUsuario, "terminal");   /* queda en el log */
    sesion = SesionPaciente();
    relojSesion->stop();
    btnCuenta->setText("Ingresar");
    btnCuenta->setToolTip("Ingresá o creá tu cuenta (es opcional)");
    ui->editNombre->clear();
    ui->editDni->clear();
    ui->editTelefono->clear();
    ui->editBuscarTurno->clear();
    ultimoBuscado.clear();
    ocultarTurno();
}

/* Con sesión iniciada, rellena nombre, DNI y teléfono (y la búsqueda de turno) con los datos de la cuenta. */
void VentanaCliente::completarConLaCuenta()
{
    if (!sesion.activa())
        return;
    ui->editNombre->setText(sesion.nombre);
    ui->editDni->setText(sesion.dni);
    ui->editTelefono->setText(sesion.telefono);
    ui->editBuscarTurno->setText(sesion.dni);
}

/* Cada clic, tecla o toque reinicia el reloj de inactividad: pasados 3 minutos sin tocar nada, la sesión se cierra sola. */
bool VentanaCliente::eventFilter(QObject *objeto, QEvent *evento)
{
    if (sesion.activa() && (evento->type() == QEvent::MouseButtonPress || evento->type() == QEvent::KeyPress
                            || evento->type() == QEvent::TouchBegin))
        relojSesion->start();   /* vuelve a contar los 3 minutos */
    return QMainWindow::eventFilter(objeto, evento);
}

