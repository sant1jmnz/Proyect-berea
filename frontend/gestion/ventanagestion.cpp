#include "ventanagestion.h"
#include "ui_ventanagestion.h"

#include "db.h"

#include <QHeaderView>
#include <QLocale>
#include <QMessageBox>
#include <QTextCharFormat>

#include <algorithm>

/* Orden de las páginas dentro del QStackedWidget `paginas` del .ui. */
enum Pagina { PagInicio, PagProtocolo, PagHorario, PagConfirmar, PagBuscador, PagBuscarTurnos };

/* A qué página lleva cada fila del menú lateral. Los pasos 2 y 3 no están
 * en el menú: se llega con "Continuar". */
static const int paginaDeMenu[] = { PagInicio, PagProtocolo, PagBuscador, PagBuscarTurnos };
enum { MenuCargarTurno = 1, MenuBuscarTurnos = 3 };
enum { ColProtocolo = 3, ColEstado = 5 };   /* columnas de `tablaTurnos` */

/* Datos de ejemplo, los mismos de db/seed.sql.
 * Semana 2: se reemplazan por db_buscar_protocolos(). */
static const Protocolo protocolos[] = {
    { 1, "Limpieza facial profunda", 60, 25000 },
    { 2, "Peeling químico", 45, 40000 },
    { 3, "Mesoterapia facial", 45, 55000 },
    { 4, "Depilación láser (zona chica)", 30, 18000 },
};
static const char *const horarios[] = { "09:00", "10:30", "13:00", "15:30", "17:00" };

static QString pesos(long monto)
{
    return "$" + QLocale().toString(static_cast<qlonglong>(monto));
}

static QString fechaLarga(const QDateTime &f)
{
    return QLocale().toString(f, "dddd d 'de' MMMM · HH:mm");
}

static QString textoEstado(EstadoTurno e)
{
    switch (e) {
    case TURNO_CONFIRMADO: return "Confirmado";
    case TURNO_REALIZADO:  return "Realizado";
    case TURNO_CANCELADO:  return "Cancelado";
    case TURNO_AUSENTE:    return "Ausente";
    }
    return "";
}

static QColor colorEstado(EstadoTurno e)
{
    switch (e) {
    case TURNO_CONFIRMADO: return QColor("#16a34a");   /* verde */
    case TURNO_CANCELADO:  return QColor("#b91c1c");   /* rojo */
    case TURNO_AUSENTE:    return QColor("#b45309");   /* naranja */
    case TURNO_REALIZADO:  break;
    }
    return QColor("#6b7280");                          /* gris */
}

/* Arma un turno completo: el fin sale de la duración del protocolo y la
 * seña la calcula el backend en C (RF-10), no la interfaz. */
static Turno armarTurno(const QString &paciente, const QString &dni, const QString &telefono,
                        const Protocolo &p, const QDateTime &inicio, bool senaPagada)
{
    return Turno{ paciente, dni, telefono, QString::fromUtf8(p.nombre), p.precio,
                  inicio, inicio.addSecs(p.duracion_min * 60),
                  dermalia_calcular_sena(p.precio), senaPagada,
                  inicio > QDateTime::currentDateTime() ? TURNO_CONFIRMADO : TURNO_REALIZADO };
}

VentanaGestion::VentanaGestion(QWidget *parent)
    : QMainWindow(parent), ui(new Ui::VentanaGestion)
{
    ui->setupUi(this);   /* crea todos los widgets dibujados en el .ui */

    for (const Protocolo &p : protocolos)
        ui->listaProtocolos->addItem(QString("%1\n%2 min · %3")
            .arg(QString::fromUtf8(p.nombre)).arg(p.duracion_min).arg(pesos(p.precio)));

    QDate hoy = QDate::currentDate();
    ui->calendario->setMinimumDate(hoy);
    ui->calendario->setSelectedDate(hoy.addDays(1));
    /* Sábado y domingo vienen en rojo: los dejamos como el resto. */
    ui->calendario->setWeekdayTextFormat(Qt::Saturday, QTextCharFormat());
    ui->calendario->setWeekdayTextFormat(Qt::Sunday, QTextCharFormat());

    /* Cada columna del ancho de su texto; "Protocolo" ocupa lo que sobra. */
    ui->tablaTurnos->horizontalHeader()->setSectionResizeMode(QHeaderView::ResizeToContents);
    ui->tablaTurnos->horizontalHeader()->setSectionResizeMode(ColProtocolo, QHeaderView::Stretch);

    /* Turnos de ejemplo, para que el prototipo no arranque vacío. */
    turnos.append(armarTurno("María Sosa", "30111222", "1155550102", protocolos[0],
                             QDateTime(hoy.addDays(-20), QTime(16, 0)), true));
    turnos.append(armarTurno("Lucía Fernández", "28444555", "1155550144", protocolos[1],
                             QDateTime(hoy, QTime(17, 0)), true));
    turnos.append(armarTurno("Carla Gómez", "33222111", "1155550177", protocolos[2],
                             QDateTime(hoy.addDays(1), QTime(13, 0)), false));
    turnos.append(armarTurno("Julieta Díaz", "35666777", "1155550190", protocolos[3],
                             QDateTime(hoy.addDays(3), QTime(9, 0)), true));

    /* Señales y slots: connect(quién avisa, qué pasó, quién reacciona, qué hace). */
    connect(ui->menu, &QListWidget::currentRowChanged, this, &VentanaGestion::cambiarSeccion);
    connect(ui->btnIrCargar, &QPushButton::clicked, this, [this] { ui->menu->setCurrentRow(MenuCargarTurno); });
    connect(ui->btnIrBuscar, &QPushButton::clicked, this, [this] { ui->menu->setCurrentRow(MenuBuscarTurnos); });

    connect(ui->editPaciente, &QLineEdit::textChanged, this, &VentanaGestion::actualizarBotones);
    connect(ui->editDni, &QLineEdit::textChanged, this, &VentanaGestion::actualizarBotones);
    connect(ui->editTelefono, &QLineEdit::textChanged, this, &VentanaGestion::actualizarBotones);
    connect(ui->listaProtocolos, &QListWidget::currentRowChanged, this, &VentanaGestion::actualizarBotones);
    connect(ui->listaHorarios, &QListWidget::currentRowChanged, this, &VentanaGestion::actualizarBotones);

    /* Navegación de los 3 pasos. */
    connect(ui->btnContinuar1, &QPushButton::clicked, this, [this] { cargarHorarios(); irA(PagHorario); });
    connect(ui->calendario, &QCalendarWidget::selectionChanged, this, &VentanaGestion::cargarHorarios);
    connect(ui->btnVolver2, &QPushButton::clicked, this, [this] { irA(PagProtocolo); });
    connect(ui->btnContinuar2, &QPushButton::clicked, this, &VentanaGestion::mostrarResumen);
    connect(ui->btnVolver3, &QPushButton::clicked, this, [this] { irA(PagHorario); });
    connect(ui->btnConfirmar, &QPushButton::clicked, this, &VentanaGestion::confirmarTurno);
    /* El botón de la seña queda apretado (checkable): cambia el texto. */
    connect(ui->btnSena, &QPushButton::toggled, this, [this](bool pagada) {
        ui->btnSena->setText(pagada ? "✓  Seña pagada" : "Marcar seña como pagada");
    });

    connect(ui->btnBuscar, &QPushButton::clicked, this, &VentanaGestion::buscarTurnos);
    connect(ui->editBuscar, &QLineEdit::returnPressed, this, &VentanaGestion::buscarTurnos);
    connect(ui->tablaTurnos, &QTableWidget::itemSelectionChanged, this, &VentanaGestion::mostrarSeleccion);
    connect(ui->btnCancelarTurno, &QPushButton::clicked, this, &VentanaGestion::cancelarTurno);

    connect(ui->btnAyuda, &QPushButton::clicked, this, [this] {
        QMessageBox::information(this, "Ayuda",
            "Cargar turno: paciente y protocolo, después horario, después confirmar.\n"
            "Buscar turnos: por nombre, DNI o teléfono; desde ahí se cancela.");
    });

    actualizarBotones();
    actualizarInicio();
}

VentanaGestion::~VentanaGestion()
{
    delete ui;
}

void VentanaGestion::irA(int pagina)
{
    ui->paginas->setCurrentIndex(pagina);
}

void VentanaGestion::cambiarSeccion(int fila)
{
    if (fila < 0)
        return;
    irA(paginaDeMenu[fila]);
    if (paginaDeMenu[fila] == PagInicio)
        actualizarInicio();
    if (paginaDeMenu[fila] == PagBuscarTurnos)
        buscarTurnos();
}

/* Pantalla de inicio: los tres números y la lista de próximos turnos. */
void VentanaGestion::actualizarInicio()
{
    QDateTime ahora = QDateTime::currentDateTime();
    int deHoy = 0, sinSena = 0;
    QVector<Turno> proximos;

    for (const Turno &t : turnos) {
        if (t.estado != TURNO_CANCELADO && t.inicio.date() == ahora.date())
            deHoy++;
        if (t.estado == TURNO_CONFIRMADO && t.inicio > ahora) {
            proximos.append(t);
            if (!t.senaPagada)
                sinSena++;
        }
    }
    std::sort(proximos.begin(), proximos.end(),
              [](const Turno &a, const Turno &b) { return a.inicio < b.inicio; });

    ui->lblFechaHoy->setText("Hoy es " + QLocale().toString(ahora.date(), "dddd d 'de' MMMM"));
    ui->lblNumHoy->setText(QString::number(deHoy));
    ui->lblNumProximos->setText(QString::number(proximos.size()));
    ui->lblNumSinSena->setText(QString::number(sinSena));

    ui->listaProximos->clear();
    for (const Turno &t : proximos)
        ui->listaProximos->addItem(QString("%1      %2  —  %3")
            .arg(QLocale().toString(t.inicio, "ddd d/M · HH:mm"), t.paciente, t.protocolo));
    if (proximos.isEmpty())
        ui->listaProximos->addItem("No hay turnos próximos.");
}

void VentanaGestion::actualizarBotones()
{
    bool datos = !ui->editPaciente->text().trimmed().isEmpty()
              && !ui->editDni->text().trimmed().isEmpty()
              && !ui->editTelefono->text().trimmed().isEmpty();
    ui->btnContinuar1->setEnabled(datos && ui->listaProtocolos->currentRow() >= 0);
    ui->btnContinuar2->setEnabled(ui->listaHorarios->currentRow() >= 0);
}

QDateTime VentanaGestion::inicioElegido() const
{
    return QDateTime(ui->calendario->selectedDate(),
                     QTime::fromString(ui->listaHorarios->currentItem()->text(), "HH:mm"));
}

/* RF-04: solo se listan horarios futuros que no pisan un turno confirmado. */
void VentanaGestion::cargarHorarios()
{
    int fila = ui->listaProtocolos->currentRow();
    if (fila < 0)
        return;
    const Protocolo &p = protocolos[fila];
    QDate dia = ui->calendario->selectedDate();

    ui->listaHorarios->clear();
    for (const char *h : horarios) {
        QDateTime ini(dia, QTime::fromString(h, "HH:mm"));
        QDateTime fin = ini.addSecs(p.duracion_min * 60);
        bool libre = ini > QDateTime::currentDateTime();
        for (const Turno &t : turnos)
            if (t.estado == TURNO_CONFIRMADO
                && dermalia_superpone(ini.toSecsSinceEpoch(), fin.toSecsSinceEpoch(),
                                      t.inicio.toSecsSinceEpoch(), t.fin.toSecsSinceEpoch()))
                libre = false;
        if (libre)
            ui->listaHorarios->addItem(h);
    }
    ui->lblPasoHorario->setText(QString("%1 · %2 (%3 min)")
        .arg(ui->editPaciente->text().trimmed(), QString::fromUtf8(p.nombre)).arg(p.duracion_min));
    ui->lblHorarios->setText((ui->listaHorarios->count() > 0 ? "Horarios disponibles — "
                                                             : "Sin horarios libres — ")
                             + QLocale().toString(dia, "dddd d 'de' MMMM"));
    actualizarBotones();
}

void VentanaGestion::mostrarResumen()
{
    const Protocolo &p = protocolos[ui->listaProtocolos->currentRow()];
    QDateTime ini = inicioElegido();

    ui->lblResPaciente->setText(ui->editPaciente->text().trimmed());
    ui->lblResDni->setText(ui->editDni->text().trimmed());
    ui->lblResTelefono->setText(ui->editTelefono->text().trimmed());
    ui->lblResProtocolo->setText(QString::fromUtf8(p.nombre));
    ui->lblResPrecio->setText(pesos(p.precio));
    ui->lblResFecha->setText(QLocale().toString(ini.date(), "dddd d 'de' MMMM"));
    ui->lblResHora->setText(QString("%1 (%2 min)").arg(ini.toString("HH:mm")).arg(p.duracion_min));
    ui->lblSena->setText(pesos(dermalia_calcular_sena(p.precio)));
    ui->btnSena->setChecked(false);
    irA(PagConfirmar);
}

void VentanaGestion::confirmarTurno()
{
    QString paciente = ui->editPaciente->text().trimmed();

    turnos.append(armarTurno(paciente, ui->editDni->text().trimmed(),
                             ui->editTelefono->text().trimmed(),
                             protocolos[ui->listaProtocolos->currentRow()],
                             inicioElegido(), ui->btnSena->isChecked()));

    /* Formulario limpio para el próximo llamado y a ver el turno cargado. */
    ui->editPaciente->clear();
    ui->editDni->clear();
    ui->editTelefono->clear();
    ui->listaProtocolos->setCurrentRow(-1);
    ui->editBuscar->setText(paciente);
    ui->menu->setCurrentRow(MenuBuscarTurnos);   /* dispara cambiarSeccion() */
}

void VentanaGestion::buscarTurnos()
{
    QString texto = ui->editBuscar->text().trimmed();

    ui->tablaTurnos->setRowCount(0);
    for (int i = 0; i < turnos.size(); i++) {
        const Turno &t = turnos[i];
        if (!t.paciente.contains(texto, Qt::CaseInsensitive)
            && !t.dni.contains(texto) && !t.telefono.contains(texto))
            continue;
        const QStringList celdas = {
            t.paciente, t.dni, t.telefono, t.protocolo, t.inicio.toString("dd/MM/yyyy HH:mm"),
            textoEstado(t.estado),
            QString("%1 (%2)").arg(pesos(t.sena), t.senaPagada ? "pagada" : "sin pagar"),
        };
        int fila = ui->tablaTurnos->rowCount();
        ui->tablaTurnos->insertRow(fila);
        for (int c = 0; c < celdas.size(); c++)
            ui->tablaTurnos->setItem(fila, c, new QTableWidgetItem(celdas[c]));
        ui->tablaTurnos->item(fila, ColEstado)->setForeground(colorEstado(t.estado));
        /* Guardamos qué turno es cada fila, para cancelar el correcto. */
        ui->tablaTurnos->item(fila, 0)->setData(Qt::UserRole, i);
    }
    ui->lblSinTurnos->setVisible(ui->tablaTurnos->rowCount() == 0);
    mostrarSeleccion();
}

void VentanaGestion::mostrarSeleccion()
{
    int fila = ui->tablaTurnos->currentRow();
    bool confirmado = false;
    if (fila >= 0) {
        const Turno &t = turnos[ui->tablaTurnos->item(fila, 0)->data(Qt::UserRole).toInt()];
        confirmado = t.estado == TURNO_CONFIRMADO;
        ui->lblRecordatorio->setText("Recordatorio programado para el "
            + fechaLarga(t.inicio.addSecs(-RECORDATORIO_HORAS * 3600)) + " (RF-11).");
    }
    ui->lblRecordatorio->setVisible(confirmado);
    ui->btnCancelarTurno->setEnabled(confirmado);
}

void VentanaGestion::cancelarTurno()
{
    int fila = ui->tablaTurnos->currentRow();
    if (fila < 0)
        return;
    Turno &t = turnos[ui->tablaTurnos->item(fila, 0)->data(Qt::UserRole).toInt()];
    if (QMessageBox::question(this, "Cancelar turno",
            QString("¿Cancelar el turno de %1 del %2?").arg(t.paciente, fechaLarga(t.inicio)))
        != QMessageBox::Yes)
        return;
    t.estado = TURNO_CANCELADO;
    buscarTurnos();
}
