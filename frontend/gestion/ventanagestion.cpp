#include "ventanagestion.h"
#include "ui_ventanagestion.h"

#include "reglas.h"

#include <QGraphicsDropShadowEffect>
#include <QHeaderView>
#include <QMessageBox>
#include <QRegularExpressionValidator>
#include <QStyle>
#include <QTextCharFormat>
#include <algorithm>

/* Orden de las páginas dentro del QStackedWidget `paginas` del .ui. */
enum Pagina { PagInicio, PagProtocolo, PagHorario, PagConfirmar, PagBuscador, PagBuscarTurnos };

/* A qué página lleva cada fila del menú lateral. Los pasos 2 y 3 no están
 * en el menú: se llega con "Continuar". */
static const int paginaDeMenu[] = { PagInicio, PagProtocolo, PagBuscador, PagBuscarTurnos };
enum { MenuCargarTurno = 1, MenuBuscarTurnos = 3 };
/* Columnas de `tablaTurnos`. */
enum { ColPaciente, ColDni, ColTelefono, ColProtocolo, ColFecha, ColEstado, ColSena };

static QString pesos(int monto)
{
    return "$" + QLocale().toString(monto);   /* $25.000 */
}

static QString fechaLarga(const QDate &fecha)
{
    return QLocale().toString(fecha, "dddd d 'de' MMMM");   /* jueves 8 de octubre */
}

VentanaGestion::VentanaGestion(QWidget *parent)
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
    cargarProtocolos();
    ui->lblFechaHoy->setText(QLocale().toString(ahora.date(), "dddd d 'de' MMMM 'de' yyyy"));
    ui->calendario->setMinimumDate(ahora.date());   /* no se cargan turnos en el pasado */

    /* Mientras se escribe, el DNI solo acepta números y el teléfono números,
     * espacios, guiones y paréntesis. La regla completa se revisa al continuar. */
    ui->editDni->setValidator(new QRegularExpressionValidator(QRegularExpression("\\d{0,8}"), this));
    ui->editTelefono->setValidator(
        new QRegularExpressionValidator(QRegularExpression("[\\d \\-()]{0,20}"), this));
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

    actualizarHorarios();
    buscarTurnos();
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
    if (fila >= 0)
        irA(paginaDeMenu[fila]);
}

void VentanaGestion::cargarProtocolos()
{
    ui->listaProtocolos->clear();
    for (const Protocolo &p : protocolos)
        ui->listaProtocolos->addItem(QString("%1\n%2 min · %3").arg(p.nombre).arg(p.duracionMin).arg(pesos(p.precio)));
}

const Protocolo *VentanaGestion::protocoloElegido() const
{
    const int fila = ui->listaProtocolos->currentRow();
    if (!ui->listaProtocolos->currentItem() || !ui->listaProtocolos->currentItem()->isSelected())
        return nullptr;
    return (fila >= 0 && fila < protocolos.size()) ? &protocolos[fila] : nullptr;
}

QDateTime VentanaGestion::horarioElegido() const
{
    const QListWidgetItem *item = ui->listaHorarios->currentItem();
    if (!item || !item->isSelected() || !(item->flags() & Qt::ItemIsSelectable))
        return {};
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
    struct Revision { QLineEdit *campo; QString error; };
    const Revision revisiones[] = {
        { ui->editPaciente, Reglas::validarNombre(ui->editPaciente->text()) },
        { ui->editDni, Reglas::validarDni(ui->editDni->text()) },
        { ui->editTelefono, Reglas::validarTelefono(ui->editTelefono->text()) },
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
            return t.fechaHora == inicio;
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
    ui->lblResFecha->setText(fechaLarga(inicio.date()));
    ui->lblResHora->setText(QString("%1 (%2 min)").arg(inicio.toString("HH:mm")).arg(p->duracionMin));
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

    const Turno t = { ui->editPaciente->text().simplified(), ui->editDni->text().trimmed(),
                      Reglas::sinSeparadores(ui->editTelefono->text()), p->nombre, inicio,
                      ui->btnSena->isChecked() };
    turnos.append(t);

    QMessageBox::information(this, "Turno confirmado",
        QString("El turno quedó cargado.\n%1 · %2, %3")
            .arg(t.paciente, fechaLarga(inicio.date()), inicio.toString("HH:mm")));

    reiniciarCarga();
    ui->editBuscar->setText(t.dni);   /* muestra el turno recién cargado */
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
    const QString numeros = Reglas::sinSeparadores(texto);
    const bool esNumero = !numeros.isEmpty() && std::all_of(numeros.cbegin(), numeros.cend(),
                                                            [](QChar c) { return c.isDigit(); });

    QVector<Turno> encontrados;
    for (const Turno &t : turnos) {
        if (texto.isEmpty()
            || (esNumero && (t.dni.contains(numeros) || t.telefono.contains(numeros)))
            || (!esNumero && t.paciente.contains(texto, Qt::CaseInsensitive)))
            encontrados.append(t);
    }
    std::sort(encontrados.begin(), encontrados.end(),
              [](const Turno &a, const Turno &b) { return a.fechaHora < b.fechaHora; });

    const QDateTime ahora = QDateTime::currentDateTime();
    ui->tablaTurnos->clearContents();
    ui->tablaTurnos->setRowCount(encontrados.size());
    for (int fila = 0; fila < encontrados.size(); ++fila) {
        const Turno &t = encontrados[fila];
        const bool realizado = t.fechaHora < ahora;
        const QString columnas[] = {
            t.paciente, t.dni, t.telefono, t.protocolo, t.fechaHora.toString("dd/MM/yy HH:mm"),
            realizado ? "Realizado" : "Confirmado", t.senaPagada ? "Pagada" : "Sin pagar",
        };
        for (int col = ColPaciente; col <= ColSena; ++col) {
            auto *item = new QTableWidgetItem(columnas[col]);
            if (realizado)
                item->setForeground(QColor(122, 106, 100));   /* gris: ya pasó */
            ui->tablaTurnos->setItem(fila, col, item);
        }
    }

    const int cantidad = encontrados.size();
    ui->lblCuenta->setText(cantidad == 1 ? "1 turno" : QString("%1 turnos").arg(cantidad));
}
