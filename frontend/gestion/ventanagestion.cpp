#include "ventanagestion.h"
#include "ui_ventanagestion.h"

#include "avisoconexion.h"
#include "datosbase.h"
#include "dialogologin.h"
#include "repositorio.h"
#include "conexionapp.h"
#include "paginaavisos.h"
#include "paginapacientes.h"
#include "paginaprofesionales.h"
#include "paginaprotocolos.h"
#include "paginareportes.h"
#include "reembolso.h"
#include "sena.h"
#include "validaciones.h"

#include <QGraphicsDropShadowEffect>
#include <QHBoxLayout>
#include <QInputDialog>
#include <QRandomGenerator>
#include <QTimer>
#include <QVBoxLayout>
#include <QHeaderView>
#include <QMessageBox>
#include <QRegularExpressionValidator>
#include <QStyle>
#include <QTextCharFormat>
#include <algorithm>

/* Orden de las páginas dentro del QStackedWidget `paginas` del .ui. */
enum Pagina { PagInicio, PagProtocolo, PagHorario, PagConfirmar, PagBuscador, PagBuscarTurnos,
              /* se agregan por código en armarPantallasNuevas() */
              PagProtocolos, PagProfesionales, PagPacientes, PagAvisos, PagReportes };

/* A qué página lleva cada fila del menú lateral. Los pasos 2 y 3 no están
 * en el menú: se llega con "Continuar". */
static const int paginaDeMenu[] = { PagInicio, PagProtocolo, PagBuscador, PagBuscarTurnos,
                                    PagProtocolos, PagProfesionales, PagPacientes, PagAvisos, PagReportes };
enum { MenuCargarTurno = 1, MenuBuscarTurnos = 3, MenuPacientes = 6 };
/* Columnas de `tablaTurnos`. */
enum { ColPaciente, ColDni, ColTelefono, ColProtocolo, ColFecha, ColEstado, ColSena };

static QString pesos(int monto)
{
    return "$" + QLocale().toString(monto);   /* $25.000 */
}

/* "+54 11 4444-3322" → "541144443322": así se compara y se guarda. */
static QString soloDigitos(const QString &texto)
{
    QString limpio = Validaciones::normalizar(texto);
    limpio.remove('+');
    return limpio;
}

static QString fechaLarga(const QDate &fecha)
{
    return QLocale().toString(fecha, "dddd d 'de' MMMM");   /* jueves 8 de octubre */
}

VentanaGestion::VentanaGestion(QWidget *parent, const QString &archivoContingencia)
    : QMainWindow(parent), ui(new Ui::VentanaGestion)
{
    ui->setupUi(this);   /* crea todos los widgets dibujados en el .ui */

    /* Ajustes de aspecto que Qt Designer no deja marcar. */
    ui->tablaTurnos->horizontalHeader()->setSectionResizeMode(QHeaderView::ResizeToContents);
    ui->tablaTurnos->horizontalHeader()->setSectionResizeMode(ColProtocolo, QHeaderView::Stretch);
    /* Sábado y domingo vienen en rojo: los dejamos como el resto. */
    ui->calendario->setWeekdayTextFormat(Qt::Saturday, QTextCharFormat());
    ui->calendario->setWeekdayTextFormat(Qt::Sunday, QTextCharFormat());

    /* Sombra suave debajo de cada tarjeta, para que no se vea plano. */
    for (QFrame *tarjeta : findChildren<QFrame *>()) {
        if (!tarjeta->property("tarjeta").toBool() && tarjeta != ui->hero)
            continue;
        auto *sombra = new QGraphicsDropShadowEffect(tarjeta);
        sombra->setBlurRadius(28);
        sombra->setOffset(0, 6);
        sombra->setColor(QColor(90, 55, 40, 26));   /* marrón casi transparente */
        tarjeta->setGraphicsEffect(sombra);
    }

    /* Datos de prueba: reemplazan los textos de ejemplo escritos en el .ui. */
    const QDateTime ahora = QDateTime::currentDateTime();
    protocolos = DatosPrueba::protocolos();
    turnos = DatosPrueba::turnos(ahora.date());
    profesionales = DatosPrueba::profesionales(ahora.date());
    pacientes = DatosPrueba::pacientes();
    for (const Turno &t : std::as_const(turnos))   /* los turnos futuros ya tienen su aviso */
        if (t.estado == EstadoTurno::Confirmado && t.inicio > ahora)
            avisos.programar(t.paciente, t.dni, t.telefono, t.protocolo, t.inicio, ahora);
    armarPantallasNuevas();
    cargarProtocolos();
    ui->lblFechaHoy->setText(QLocale().toString(ahora.date(), "dddd d 'de' MMMM 'de' yyyy"));
    ui->calendario->setMinimumDate(ahora.date());   /* no se cargan turnos en el pasado */

    /* Mientras se escribe, el DNI solo acepta números y el teléfono números,
     * espacios, guiones y paréntesis. La regla completa se revisa al continuar. */
    ui->editDni->setValidator(new QRegularExpressionValidator(QRegularExpression("\\d{0,8}"), this));
    ui->editTelefono->setValidator(
        new QRegularExpressionValidator(QRegularExpression("\\+?[\\d \\-()]{0,20}"), this));
    ui->editTelefono->setPlaceholderText("11 5555-0102");
    ui->editPaciente->setPlaceholderText("Nombre y apellido");
    ui->editPaciente->clear();
    ui->editDni->clear();
    ui->editTelefono->clear();
    for (QLineEdit *campo : { ui->editPaciente, ui->editDni, ui->editTelefono })
        connect(campo, &QLineEdit::textEdited, this, [this, campo] { marcarError(campo, false); });

    /* Señales y slots: connect(quién avisa, qué pasó, quién reacciona, qué hace). */

    /* Menú lateral y accesos del inicio. */
    connect(ui->menu, &QListWidget::currentRowChanged, this, &VentanaGestion::cambiarSeccion);
    connect(ui->btnIrCargar, &QPushButton::clicked, this, [this] { ui->menu->setCurrentRow(MenuCargarTurno); });
    connect(ui->btnIrBuscar, &QPushButton::clicked, this, [this] { ui->menu->setCurrentRow(MenuBuscarTurnos); });

    /* Los 3 pasos de cargar un turno: Continuar valida y avanza, Volver retrocede. */
    connect(ui->btnContinuar1, &QPushButton::clicked, this, &VentanaGestion::continuarPaso1);
    connect(ui->calendario, &QCalendarWidget::selectionChanged, this, &VentanaGestion::actualizarHorarios);
    connect(ui->btnVolver2, &QPushButton::clicked, this, [this] { irA(PagProtocolo); });
    connect(ui->btnContinuar2, &QPushButton::clicked, this, &VentanaGestion::continuarPaso2);
    connect(ui->btnVolver3, &QPushButton::clicked, this, [this] { irA(PagHorario); });

    /* El botón de la seña queda apretado (checkable): cambia el texto. */
    connect(ui->btnSena, &QPushButton::toggled, this, [this](bool pagada) {
        ui->btnSena->setText(pagada ? "✓  Seña pagada" : "Marcar seña como pagada");
    });
    connect(ui->btnConfirmar, &QPushButton::clicked, this, &VentanaGestion::confirmarTurno);

    /* Buscar turnos: con el botón o con Enter. */
    connect(ui->btnBuscar, &QPushButton::clicked, this, &VentanaGestion::buscarTurnos);
    connect(ui->editBuscar, &QLineEdit::returnPressed, this, &VentanaGestion::buscarTurnos);

    connect(ui->btnAyuda, &QPushButton::clicked, this, [this] {
        QMessageBox::information(this, "Ayuda",
            "Cargar turno: paciente y protocolo, después horario, después confirmar.\n"
            "Buscar turnos: por nombre, DNI o teléfono; desde ahí se cancela.");
    });

    connect(ui->btnCancelarTurno, &QPushButton::clicked, this, &VentanaGestion::cancelarTurno);
    connect(ui->tablaTurnos, &QTableWidget::itemSelectionChanged, this, &VentanaGestion::turnoElegido);
    ui->tablaTurnos->setSelectionBehavior(QAbstractItemView::SelectRows);
    ui->tablaTurnos->setSelectionMode(QAbstractItemView::SingleSelection);
    ui->tablaTurnos->setEditTriggers(QAbstractItemView::NoEditTriggers);

    /* Franja de aviso y modo contingencia (RNF-09). La conexión se prueba
     * apenas se muestra la ventana, para no demorar el arranque. */
    conexion = new ConexionApp(franja, ConfigBD::desdeEntorno(), archivoContingencia, this);
    /* Cuando la conexión se logra (ahora o con "Reintentar"), se pide el ingreso y se leen los datos de la base. */
    connect(conexion, &ConexionApp::conectada, this, &VentanaGestion::conectarBase);
    connect(conexion, &ConexionApp::pendientesSincronizados, this, [this](int enviados, const QStringList &problemas) {
        QString texto = QString("Volvió la conexión: se enviaron %1 turnos guardados en este equipo.").arg(enviados);
        if (!problemas.isEmpty())
            texto += "\n\nNo se pudieron enviar (siguen guardados):\n• " + problemas.join("\n• ");
        QMessageBox::information(this, "Turnos sincronizados", texto);
    });
    QTimer::singleShot(0, conexion, &ConexionApp::probar);

    actualizarHorarios();
    buscarTurnos();
}

VentanaGestion::~VentanaGestion()
{
    delete ui;
}

/* Agrega al menú y al QStackedWidget las pantallas que se arman por código:
 * Protocolos, Profesionales, Pacientes y Avisos; y pone arriba la franja de
 * "sin conexión con la base". */
void VentanaGestion::armarPantallasNuevas()
{
    for (const char *texto : { "Protocolos", "Profesionales", "Pacientes", "Avisos", "Reportes" })
        ui->menu->addItem(texto);

    paginaProtocolos = new PaginaProtocolos(&protocolos);
    paginaProfesionales = new PaginaProfesionales(&profesionales, &protocolos);
    paginaPacientes = new PaginaPacientes(&pacientes);
    paginaAvisos = new PaginaAvisos(&avisos);
    paginaReportes = new PaginaReportes;
    paginaReportes->setObjectName("pagReportes");
    paginaProtocolos->setObjectName("pagProtocolos");
    paginaProfesionales->setObjectName("pagProfesionales");
    paginaPacientes->setObjectName("pagPacientes");
    paginaAvisos->setObjectName("pagAvisos");
    for (QWidget *pagina : { static_cast<QWidget *>(paginaProtocolos), static_cast<QWidget *>(paginaProfesionales),
                             static_cast<QWidget *>(paginaPacientes), static_cast<QWidget *>(paginaAvisos), static_cast<QWidget *>(paginaReportes) })
        ui->paginas->addWidget(pagina);   /* quedan en el orden de Pagina */

    connect(paginaProtocolos, &PaginaProtocolos::cambiaron, this, &VentanaGestion::protocolosCambiaron);
    connect(paginaPacientes, &PaginaPacientes::cargarTurnoPara, this, &VentanaGestion::cargarTurnoPara);

    /* La franja va arriba del contenido, a lo ancho de las pantallas. */
    franja = new AvisoConexion;
    franja->setObjectName("avisoConexion");
    auto *capaCentral = qobject_cast<QHBoxLayout *>(ui->central->layout());
    const int lugar = capaCentral->indexOf(ui->paginas);
    capaCentral->removeWidget(ui->paginas);
    auto *columna = new QWidget;
    auto *capaColumna = new QVBoxLayout(columna);
    capaColumna->setContentsMargins(0, 0, 0, 0);
    capaColumna->setSpacing(0);
    auto *margen = new QWidget;
    auto *capaMargen = new QHBoxLayout(margen);
    capaMargen->setContentsMargins(28, 14, 28, 0);
    capaMargen->addWidget(franja);
    capaColumna->addWidget(margen);
    capaColumna->addWidget(ui->paginas, 1);
    capaCentral->insertWidget(lugar, columna, 1);
}

/* Código de operación del pago simulado (mock): SIM-123456, sin repetirse. */
QString VentanaGestion::nuevoCodigoOperacion() const
{
    for (;;) {
        const QString codigo = QString("SIM-%1").arg(QRandomGenerator::global()->bounded(100000, 1000000));
        const bool usado = std::any_of(turnos.cbegin(), turnos.cend(),
                                       [&](const Turno &t) { return t.codigoOperacion == codigo; });
        if (!usado)
            return codigo;
    }
}

void VentanaGestion::irA(int pagina)
{
    ui->paginas->setCurrentIndex(pagina);
}

void VentanaGestion::cambiarSeccion(int fila)
{
    if (fila >= 0)
        irA(paginaDeMenu[fila]);
}

void VentanaGestion::cargarProtocolos()
{
    ui->listaProtocolos->clear();
    protocolosVisibles.clear();
    for (int i = 0; i < protocolos.size(); ++i) {
        const Protocolo &p = protocolos[i];
        if (!p.activo)
            continue;   /* los protocolos dados de baja ya no se ofrecen */
        protocolosVisibles << i;
        ui->listaProtocolos->addItem(QString("%1\n%2 min · %3").arg(p.nombre).arg(p.duracionMin).arg(pesos(p.precio)));
    }
}

void VentanaGestion::protocolosCambiaron()
{
    cargarProtocolos();
    paginaProfesionales->recargarProtocolos();
}

void VentanaGestion::cargarTurnoPara(const QString &nombre, const QString &dni, const QString &telefono)
{
    ui->editPaciente->setText(nombre);
    ui->editDni->setText(dni);
    ui->editTelefono->setText(telefono);
    ui->menu->setCurrentRow(MenuCargarTurno);
}

const Protocolo *VentanaGestion::protocoloElegido() const
{
    const int fila = ui->listaProtocolos->currentRow();
    if (!ui->listaProtocolos->currentItem() || !ui->listaProtocolos->currentItem()->isSelected())
        return nullptr;
    return (fila >= 0 && fila < protocolosVisibles.size()) ? &protocolos[protocolosVisibles[fila]] : nullptr;
}

QDateTime VentanaGestion::horarioElegido() const
{
    const QListWidgetItem *item = ui->listaHorarios->currentItem();
    if (!item || !item->isSelected() || !(item->flags() & Qt::ItemIsSelectable))
        return {};
    const QVariant guardado = item->data(Qt::UserRole);   /* con la base, el horario completo viaja en el ítem */
    if (guardado.isValid())
        return guardado.toDateTime();
    return QDateTime(ui->calendario->selectedDate(), QTime::fromString(item->text(), "HH:mm"));
}

/* Pinta el borde del campo en rojo (regla QLineEdit[error="true"] del .ui). */
void VentanaGestion::marcarError(QLineEdit *campo, bool hayError)
{
    campo->setProperty("error", hayError);
    campo->style()->unpolish(campo);
    campo->style()->polish(campo);
}

/* Paso 1: se revisan todos los datos juntos y se avisa todo lo que falta. */
void VentanaGestion::continuarPaso1()
{
    QString errorNombre, errorDni, errorTelefono;
    Validaciones::nombreValido(ui->editPaciente->text(), &errorNombre);
    Validaciones::dniValido(ui->editDni->text(), &errorDni);
    Validaciones::telefonoValido(ui->editTelefono->text(), &errorTelefono);

    struct Revision { QLineEdit *campo; QString error; };
    const Revision revisiones[] = {
        { ui->editPaciente, errorNombre },
        { ui->editDni, errorDni },
        { ui->editTelefono, errorTelefono },
    };

    QStringList errores;
    QLineEdit *primero = nullptr;
    for (const Revision &r : revisiones) {
        marcarError(r.campo, !r.error.isEmpty());
        if (r.error.isEmpty())
            continue;
        errores << "• " + r.error;
        if (!primero)
            primero = r.campo;
    }
    if (!protocoloElegido())
        errores << "• Elegí el protocolo que pide la paciente.";

    if (!errores.isEmpty()) {
        QMessageBox::warning(this, "Revisá los datos", errores.join("\n"));
        if (primero)
            primero->setFocus();
        return;
    }

    const Protocolo *p = protocoloElegido();
    ui->lblPasoHorario->setText(QString("%1 · %2 (%3 min)")
                                    .arg(ui->editPaciente->text().simplified(), p->nombre)
                                    .arg(p->duracionMin));
    actualizarHorarios();
    irA(PagHorario);
}

/* RF-04: solo se ofrecen los horarios libres del día elegido. */
void VentanaGestion::actualizarHorarios()
{
    const QDate dia = ui->calendario->selectedDate();
    const QDateTime ahora = QDateTime::currentDateTime();
    ui->listaHorarios->clear();

    if (enModoBase) {   /* los horarios libres los calcula la base (RF-04) */
        cargarHorariosDeBase(dia);
        return;
    }

    if (dia.dayOfWeek() == Qt::Sunday) {
        auto *item = new QListWidgetItem("Domingo: el instituto no atiende");
        item->setFlags(Qt::NoItemFlags);
        ui->listaHorarios->addItem(item);
        return;
    }

    for (const QString &hora : DatosPrueba::horariosDelDia()) {
        const QDateTime inicio(dia, QTime::fromString(hora, "HH:mm"));
        if (inicio <= ahora)
            continue;
        const bool ocupado = std::any_of(turnos.cbegin(), turnos.cend(), [&](const Turno &t) {
            return t.inicio == inicio && t.estado != EstadoTurno::Cancelado;
        });
        if (!ocupado)
            ui->listaHorarios->addItem(hora);
    }

    if (ui->listaHorarios->count() == 0) {
        auto *item = new QListWidgetItem("No quedan horarios libres este día");
        item->setFlags(Qt::NoItemFlags);
        ui->listaHorarios->addItem(item);
    }
}

void VentanaGestion::continuarPaso2()
{
    const QDateTime inicio = horarioElegido();
    if (!inicio.isValid()) {
        QMessageBox::warning(this, "Falta el horario", "Elegí un día y un horario libre.");
        return;
    }

    /* Resumen del paso 3 con lo que se cargó. */
    const Protocolo *p = protocoloElegido();
    ui->lblResPaciente->setText(ui->editPaciente->text().simplified());
    ui->lblResDni->setText(ui->editDni->text().trimmed());
    ui->lblResTelefono->setText(ui->editTelefono->text().simplified());
    ui->lblResProtocolo->setText(p->nombre);
    ui->lblResPrecio->setText(pesos(p->precio));
    ui->lblSena->setText(pesos(Sena::calcular(p->precio, p->categoria.porcentajeSena)));
    ui->lblReglaSena->setText(
        QString("%1% del precio (categoría %2); se descuenta del total al pagar. "
                "Se reembolsa si se cancela con más de 24 h de anticipación (RF-10).")
            .arg(p->categoria.porcentajeSena).arg(p->categoria.nombre));
    ui->lblResFecha->setText(fechaLarga(inicio.date()));
    QString textoHora = QString("%1 (%2 min)").arg(inicio.toString("HH:mm")).arg(p->duracionMin);
    if (enModoBase && ui->listaHorarios->currentItem())   /* el ítem dice "09:00 · Apellido, Nombre" */
        textoHora += " · con " + ui->listaHorarios->currentItem()->text().section(" · ", 1);
    ui->lblResHora->setText(textoHora);
    const QDateTime aviso = inicio.addDays(-1);
    ui->lblResRecordatorio->setText(QString("%1 · %2 (RF-11)").arg(fechaLarga(aviso.date()), aviso.toString("HH:mm")));
    irA(PagConfirmar);
}

void VentanaGestion::confirmarTurno()
{
    const Protocolo *p = protocoloElegido();
    const QDateTime inicio = horarioElegido();
    if (!p || !inicio.isValid()) {   /* no debería pasar: los pasos 1 y 2 ya lo revisan */
        irA(PagProtocolo);
        return;
    }
    if (enModoBase) {
        confirmarTurnoEnBase(p, inicio);
        return;
    }

    const Turno t = { ui->editPaciente->text().simplified(), ui->editDni->text().trimmed(),
                      soloDigitos(ui->editTelefono->text()), p->nombre, p->precio,
                      Sena::calcular(p->precio, p->categoria.porcentajeSena), inicio,
                      inicio.addSecs(p->duracionMin * 60), EstadoTurno::Confirmado, "Gestión",
                      ui->btnSena->isChecked(), QString(), 0 };
    Turno nuevo = t;
    /* Seña simulada (RF-09, RNF-05): imita un pago real pero no mueve dinero. */
    if (nuevo.senaPagada)
        nuevo.codigoOperacion = nuevoCodigoOperacion();
    turnos.append(nuevo);
    /* Recordatorio 24 h antes (RF-11): queda registrado en la pantalla Avisos. */
    const QDateTime ahora = QDateTime::currentDateTime();
    avisos.programar(nuevo.paciente, nuevo.dni, nuevo.telefono, nuevo.protocolo, nuevo.inicio, ahora);
    paginaAvisos->recargar();

    QString mensaje = QString("El turno quedó cargado.\n%1 · %2, %3")
                          .arg(nuevo.paciente, fechaLarga(inicio.date()), inicio.toString("HH:mm"));
    if (nuevo.senaPagada)
        mensaje += QString("\nPago de la seña simulado y aprobado (código %1).").arg(nuevo.codigoOperacion);
    /* Sin base, el turno se guarda en este equipo hasta que vuelva la conexión (RNF-09). */
    if (!conexion->hayConexion()) {
        if (conexion->guardarEnContingencia({ nuevo.paciente, nuevo.dni, nuevo.telefono, nuevo.protocolo,
                                              nuevo.inicio, nuevo.sena, nuevo.senaPagada, nuevo.origen, {} }))
            mensaje += "\nNo hay conexión con la base: el turno se guardó en este equipo y se enviará cuando vuelva.";
        else
            mensaje += "\nAtención: no hay conexión con la base y tampoco se pudo guardar el turno en este equipo.";
    }
    QMessageBox::information(this, "Turno confirmado", mensaje);

    reiniciarCarga();
    ui->editBuscar->setText(nuevo.dni);   /* muestra el turno recién cargado */
    buscarTurnos();
    ui->menu->setCurrentRow(MenuBuscarTurnos);
}

/* Deja los 3 pasos en blanco para el próximo turno. */
void VentanaGestion::reiniciarCarga()
{
    for (QLineEdit *campo : { ui->editPaciente, ui->editDni, ui->editTelefono }) {
        campo->clear();
        marcarError(campo, false);
    }
    ui->listaProtocolos->clearSelection();
    ui->listaProtocolos->setCurrentRow(-1);
    ui->btnSena->setChecked(false);
    actualizarHorarios();
}

/* RF-13: busca por nombre (si hay letras) o por DNI o teléfono (si son números). */
void VentanaGestion::buscarTurnos()
{
    const QString texto = ui->editBuscar->text().simplified();
    if (enModoBase)
        refrescarTurnosDeBase(texto);
    const QString numeros = soloDigitos(texto);
    const bool esNumero = !numeros.isEmpty() && std::all_of(numeros.cbegin(), numeros.cend(),
                                                            [](QChar c) { return c.isDigit(); });

    QVector<int> encontrados;
    for (int i = 0; i < turnos.size(); ++i) {
        const Turno &t = turnos[i];
        if (texto.isEmpty()
            || (esNumero && (t.dni.contains(numeros) || t.telefono.contains(numeros)))
            || (!esNumero && t.paciente.contains(texto, Qt::CaseInsensitive)))
            encontrados.append(i);
    }
    std::sort(encontrados.begin(), encontrados.end(),
              [this](int a, int b) { return turnos[a].inicio < turnos[b].inicio; });
    filaATurno = encontrados;

    ui->tablaTurnos->blockSignals(true);
    ui->tablaTurnos->clearContents();
    ui->tablaTurnos->setRowCount(encontrados.size());
    for (int fila = 0; fila < encontrados.size(); ++fila) {
        const Turno &t = turnos[encontrados[fila]];
        QString sena = QString("%1 (%2)").arg(pesos(t.sena), t.senaPagada ? "pagada" : "sin pagar");
        if (t.estado == EstadoTurno::Cancelado && t.senaPagada)
            sena = t.reembolsado > 0 ? QString("%1 (reembolsada)").arg(pesos(t.reembolsado))
                                     : QString("%1 (no reembolsable)").arg(pesos(t.sena));
        const QString columnas[] = {
            t.paciente, t.dni, t.telefono, t.protocolo, t.inicio.toString("dd/MM/yy HH:mm"),
            DatosPrueba::texto(t.estado), sena,
        };
        for (int col = ColPaciente; col <= ColSena; ++col) {
            auto *item = new QTableWidgetItem(columnas[col]);
            if (t.estado == EstadoTurno::Realizado || t.estado == EstadoTurno::Cancelado)
                item->setForeground(QColor(122, 106, 100));   /* gris: ya pasó o se canceló */
            ui->tablaTurnos->setItem(fila, col, item);
        }
    }
    ui->tablaTurnos->blockSignals(false);
    turnoElegido();

    const int cantidad = encontrados.size();
    ui->lblCuenta->setText(cantidad == 1 ? "1 turno" : QString("%1 turnos").arg(cantidad));
}

/* Muestra el recordatorio del turno elegido y habilita Cancelar solo si se
 * puede cancelar (un turno ya realizado o ya cancelado no). */
void VentanaGestion::turnoElegido()
{
    const int fila = ui->tablaTurnos->currentRow();
    const bool hay = fila >= 0 && fila < filaATurno.size() && !ui->tablaTurnos->selectedItems().isEmpty();
    if (!hay) {
        ui->btnCancelarTurno->setEnabled(false);
        ui->lblRecordatorio->setText("Elegí un turno de la lista para ver su recordatorio y poder cancelarlo.");
        return;
    }
    const Turno &t = turnos[filaATurno[fila]];
    ui->btnCancelarTurno->setEnabled(t.estado == EstadoTurno::Confirmado || t.estado == EstadoTurno::Pendiente);

    QString texto = "Sin recordatorio programado.";
    for (const Aviso &a : avisos.todos()) {
        if (a.dni == t.dni && a.inicioTurno == t.inicio) {
            texto = QString("Recordatorio por %1 · %2 · programado para el %3 (RF-11).")
                        .arg(Recordatorios::nombre(a.canal), Recordatorios::nombre(a.estado).toLower(),
                             QLocale().toString(a.programado, "dddd d 'de' MMMM · HH:mm"));
            break;
        }
    }
    if (t.estado == EstadoTurno::Cancelado)
        texto = "Turno cancelado: ya no se envían avisos.";
    ui->lblRecordatorio->setText(texto);
}

/* RF-13 y RF-10: se cancela el turno elegido. Con más de 24 h de anticipación
 * y la seña pagada, se devuelve el 100%; si no, la seña queda retenida. */
void VentanaGestion::cancelarTurno()
{
    const int fila = ui->tablaTurnos->currentRow();
    if (fila < 0 || fila >= filaATurno.size())
        return;
    Turno &t = turnos[filaATurno[fila]];
    if (t.estado != EstadoTurno::Confirmado && t.estado != EstadoTurno::Pendiente) {
        QMessageBox::information(this, "No se puede cancelar", "Solo se cancelan turnos pendientes o confirmados.");
        return;
    }

    const QDateTime ahora = QDateTime::currentDateTime();
    const int devolver = Reembolso::monto(t.sena, t.senaPagada, t.inicio, ahora);
    QString regla;
    if (!t.senaPagada)
        regla = "La seña no estaba pagada: no hay nada que devolver.";
    else if (devolver > 0)
        regla = QString("Faltan más de %1 horas: se devuelve la seña completa (%2).")
                    .arg(Reembolso::HORAS_LIMITE).arg(pesos(devolver));
    else
        regla = QString("Faltan %1 horas o menos: la seña (%2) no se devuelve (RF-10).")
                    .arg(Reembolso::HORAS_LIMITE).arg(pesos(t.sena));

    const auto respuesta = QMessageBox::question(this, "Cancelar turno",
        QString("¿Cancelar el turno de %1 del %2?\n\n%3")
            .arg(t.paciente, t.inicio.toString("dd/MM/yy HH:mm"), regla));
    if (respuesta != QMessageBox::Yes)
        return;

    if (enModoBase) {   /* la base aplica la regla de las 24 horas y devuelve la seña */
        const Respuesta r = repositorio->cancelarTurno(t.id, "gestion", idUsuario);
        if (!r.ok) {
            QMessageBox::warning(this, "No se pudo cancelar", r.mensaje);
            return;
        }
        QString error;
        DatosBase::cargarAvisos(*repositorio, QDate::currentDate(), 60, avisos, &error);
        paginaAvisos->recargar();
        actualizarHorarios();
        buscarTurnos();
        QMessageBox::information(this, "Turno cancelado",
            r.valor > 0 ? QString("Turno cancelado. Se devolvieron %1.").arg(pesos(qRound(r.valor))) : QString("Turno cancelado. %1.").arg(r.dato));
        return;
    }

    t.estado = EstadoTurno::Cancelado;
    t.reembolsado = devolver;
    avisos.anularDeTurno(t.dni, t.inicio);   /* el recordatorio ya no tiene sentido */
    paginaAvisos->recargar();
    actualizarHorarios();                    /* el horario vuelve a estar libre */
    buscarTurnos();
    if (fila < ui->tablaTurnos->rowCount())
        ui->tablaTurnos->selectRow(fila);    /* sigue a la vista, ya como cancelado */
    QMessageBox::information(this, "Turno cancelado",
        devolver > 0 ? QString("Turno cancelado. Se devolvieron %1.").arg(pesos(devolver)) : "Turno cancelado.");
}


/* ---------------------------------------------------------------------------
 * Con la base conectada: el personal ingresa, los datos salen de los stored
 * procedures y cada acción queda en el log con su usuario.
 * --------------------------------------------------------------------------- */

/* Se llama cuando hay conexión. Si el ingreso se cancela, se sigue con datos de prueba. */
void VentanaGestion::conectarBase()
{
    if (enModoBase)
        return;   /* ya estaba conectada */
    if (!repositorio)
        repositorio = new Repositorio(conexion->base());
    if (!pedirLogin())
        return;
    cargarDesdeBase();
}

/* Ingreso del personal (RF-20). Para demos y pruebas, las variables DERMALIA_USUARIO
 * y DERMALIA_CLAVE ingresan sin abrir la ventana. */
bool VentanaGestion::pedirLogin()
{
    const QString usuario = qEnvironmentVariable("DERMALIA_USUARIO");
    const QString clave = qEnvironmentVariable("DERMALIA_CLAVE");
    if (!usuario.isEmpty() && !clave.isEmpty()) {
        const Respuesta r = repositorio->login(usuario, clave, "127.0.0.1", "gestion");
        if (!r.ok)
            return false;
        idUsuario = r.id;
        rolUsuario = r.dato;
        return true;
    }
    DialogoLogin dialogo(repositorio, this);
    if (dialogo.exec() != QDialog::Accepted)
        return false;
    idUsuario = dialogo.idUsuario();
    rolUsuario = dialogo.rol();
    return true;
}

/* Lee de la base protocolos, pacientes, profesionales, turnos y avisos, y refresca todas las pantallas. */
void VentanaGestion::cargarDesdeBase()
{
    QString error;
    const QDate hoy = QDate::currentDate();
    if (!DatosBase::cargarProtocolos(*repositorio, protocolos, &error)
        || !DatosBase::cargarPacientes(*repositorio, pacientes, &error)
        || !DatosBase::cargarProfesionales(*repositorio, protocolos, profesionales, &error)
        || !DatosBase::cargarTurnos(*repositorio, hoy, 60, turnos, &error)
        || !DatosBase::cargarAvisos(*repositorio, hoy, 60, avisos, &error)) {
        QMessageBox::warning(this, "No se pudieron leer los datos", error);
        return;
    }
    enModoBase = true;
    paginaProtocolos->usarBase(repositorio, idUsuario);
    paginaProfesionales->usarBase(repositorio, idUsuario);
    paginaPacientes->usarBase(repositorio, idUsuario);
    paginaAvisos->usarBase(repositorio);
    paginaReportes->usarBase(repositorio);

    cargarProtocolos();
    paginaProtocolos->recargar();
    paginaProfesionales->recargarProfesionales(0);
    paginaPacientes->recargar();
    paginaAvisos->recargar();
    reiniciarCarga();
    buscarTurnos();
}

/* RF-04: los horarios libres de los profesionales que hacen el protocolo elegido. */
void VentanaGestion::cargarHorariosDeBase(const QDate &dia)
{
    const Protocolo *p = protocoloElegido();
    QVector<HorarioLibre> libres;
    if (p)
        libres = repositorio->horariosLibres(dia, { p->id });
    for (const HorarioLibre &h : libres) {
        auto *item = new QListWidgetItem(QString("%1 · %2").arg(h.inicio.toString("HH:mm"), h.profesional));
        item->setData(Qt::UserRole, h.inicio);               /* cuándo */
        item->setData(Qt::UserRole + 1, h.idProfesional);    /* con quién */
        ui->listaHorarios->addItem(item);
    }
    if (ui->listaHorarios->count() == 0) {
        auto *item = new QListWidgetItem(p ? "No quedan horarios libres este día" : "Elegí primero el protocolo");
        item->setFlags(Qt::NoItemFlags);
        ui->listaHorarios->addItem(item);
    }
}

int VentanaGestion::profesionalElegido() const
{
    const QListWidgetItem *item = ui->listaHorarios->currentItem();
    if (!item)
        return 0;
    return item->data(Qt::UserRole + 1).toInt();
}

/* Con texto de 3 letras o más busca en toda la base; sin texto trae la agenda de ±60 días. */
void VentanaGestion::refrescarTurnosDeBase(const QString &texto)
{
    QString error;
    if (texto.size() >= 3) {
        turnos.clear();
        for (const TurnoBD &fila : repositorio->buscarTurnos(texto))
            turnos.append(DatosBase::aTurno(fila));
    } else {
        DatosBase::cargarTurnos(*repositorio, QDate::currentDate(), 60, turnos, &error);
    }
}

/* La paciente de la carga: si el DNI ya está en la base se usa esa; si no, se la da de alta
 * pidiendo lo que la pantalla no tiene (apellido y fecha de nacimiento). */
bool VentanaGestion::buscarOCrearPaciente(int *idPaciente)
{
    const QString dni = ui->editDni->text().trimmed();
    const Resultado r = repositorio->buscarPaciente(dni);
    if (r.ok && !r.filas.isEmpty()) {
        *idPaciente = r.filas.first().value("id_paciente").toInt();
        return true;
    }

    const QStringList partes = ui->editPaciente->text().simplified().split(' ');
    const QString nombre = partes.mid(0, qMax(1, partes.size() - 1)).join(' ');
    bool ok = false;
    const QString apellido = QInputDialog::getText(this, "Paciente nueva",
        QString("%1 no está en la base. Apellido:").arg(nombre), QLineEdit::Normal,
        partes.size() > 1 ? partes.last() : QString(), &ok);
    if (!ok)
        return false;
    const QString textoNacimiento = QInputDialog::getText(this, "Paciente nueva",
        "Fecha de nacimiento (dd/mm/aaaa):", QLineEdit::Normal, QString(), &ok);
    if (!ok)
        return false;
    const QDate nacimiento = QDate::fromString(textoNacimiento.trimmed(), "dd/MM/yyyy");
    if (!nacimiento.isValid()) {
        QMessageBox::warning(this, "Fecha inválida", "Escribí la fecha así: 25/07/1990.");
        return false;
    }
    const Respuesta alta = repositorio->altaPaciente(dni, nombre, apellido.simplified(), nacimiento, QString(),
                                                     soloDigitos(ui->editTelefono->text()), "gestion", idUsuario);
    if (!alta.ok) {
        QMessageBox::warning(this, "No se pudo dar de alta la paciente", alta.mensaje);
        return false;
    }
    *idPaciente = alta.id;
    return true;
}

/* Carga el turno con los stored procedures: alta del turno y, si se marcó, seña simulada. */
void VentanaGestion::confirmarTurnoEnBase(const Protocolo *p, const QDateTime &inicio)
{
    int idPaciente = 0;
    if (!buscarOCrearPaciente(&idPaciente))
        return;

    const Respuesta turno = repositorio->altaTurno(idPaciente, profesionalElegido(), inicio, { p->id }, "gestion", idUsuario);
    if (!turno.ok) {   /* la base aplicó una regla: horario ocupado, fuera de disponibilidad, etc. */
        QMessageBox::warning(this, "No se pudo cargar el turno", turno.mensaje);
        actualizarHorarios();
        irA(PagHorario);
        return;
    }

    QString mensaje = QString("El turno quedó cargado.\n%1 · %2, %3")
                          .arg(ui->editPaciente->text().simplified(), fechaLarga(inicio.date()), inicio.toString("HH:mm"));
    if (ui->btnSena->isChecked()) {
        bool ok = false;
        const QString medio = QInputDialog::getItem(this, "Medio de pago", "¿Cómo pagó la seña?",
            { "efectivo", "transferencia", "tarjeta simulada", "tarjeta de regalo" }, 0, false, &ok);
        QString codigoTarjeta;
        if (ok && medio == "tarjeta de regalo")
            codigoTarjeta = QInputDialog::getText(this, "Tarjeta de regalo", "Código de la tarjeta:", QLineEdit::Normal, QString(), &ok);
        if (ok) {
            const Respuesta sena = repositorio->registrarSena(turno.id, medio, codigoTarjeta, "gestion", idUsuario);
            if (sena.ok)
                mensaje += QString("\nPago de la seña simulado y aprobado (código %1).").arg(sena.dato);
            else
                mensaje += QString("\nLa seña no se pudo registrar: %1").arg(sena.mensaje);
        } else {
            mensaje += "\nLa seña quedó pendiente de pago.";
        }
    }
    QMessageBox::information(this, "Turno confirmado", mensaje);

    QString error;
    DatosBase::cargarAvisos(*repositorio, QDate::currentDate(), 60, avisos, &error);
    paginaAvisos->recargar();
    const QString dni = ui->editDni->text().trimmed();
    reiniciarCarga();
    ui->editBuscar->setText(dni);   /* muestra el turno recién cargado */
    buscarTurnos();
    ui->menu->setCurrentRow(MenuBuscarTurnos);
}
