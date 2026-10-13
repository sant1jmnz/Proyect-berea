#include "ventanagestion.h"
#include "ui_ventanagestion.h"

#include "reglas.h"

#include <QGraphicsDropShadowEffect>
#include <QHeaderView>
#include <QInputDialog>
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
    turnos = DatosPrueba::turnos(ahora);
    cargarProtocolos();
    ui->lblFechaHoy->setText(QLocale().toString(ahora.date(), "dddd d 'de' MMMM 'de' yyyy"));
    ui->calendario->setMinimumDate(ahora.date());   /* no se cargan turnos en el pasado */
    ui->lblReglaSena->setText(
        QString("%1% del protocolo (%2% en cirugías), mínimo %3 y nunca más que el precio. "
                "Se reembolsa si se cancela con más de %4 h de anticipación (RF-10).")
            .arg(Reglas::PorcentajeSena).arg(Reglas::PorcentajeSenaCirugia)
            .arg(pesos(Reglas::SenaMinima)).arg(Reglas::HorasParaReembolso));

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
    connect(ui->btnSena, &QPushButton::clicked, this, &VentanaGestion::registrarSena);
    connect(ui->btnConfirmar, &QPushButton::clicked, this, &VentanaGestion::confirmarTurno);

    /* Buscar turnos: con el botón o con Enter. */
    connect(ui->btnBuscar, &QPushButton::clicked, this, &VentanaGestion::buscarTurnos);
    connect(ui->editBuscar, &QLineEdit::returnPressed, this, &VentanaGestion::buscarTurnos);
    connect(ui->tablaTurnos, &QTableWidget::itemSelectionChanged, this, &VentanaGestion::mostrarRecordatorio);
    connect(ui->btnCancelarTurno, &QPushButton::clicked, this, &VentanaGestion::cancelarTurno);

    connect(ui->btnAyuda, &QPushButton::clicked, this, [this] {
        QMessageBox::information(this, "Ayuda",
            "Cargar turno: paciente y protocolo, después horario, después confirmar.\n"
            "Buscar turnos: por nombre, DNI o teléfono; desde ahí se cancela.");
    });

    actualizarBotonSena();
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
            return t.estado == EstadoTurno::Confirmado && t.fechaHora == inicio;
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
    ui->lblSena->setText(pesos(Reglas::calcularSena(p->precio, p->esCirugia)));
    irA(PagConfirmar);
}

void VentanaGestion::actualizarBotonSena()
{
    ui->btnSena->setChecked(senaPagada);
    ui->btnSena->setText(senaPagada ? QString("✓  Seña pagada · %1").arg(medioPago)
                                    : "Registrar pago de la seña");
}

/* RF-09 y RNF-05: pago simulado. Imita el registro de un pago real (medio de
 * pago y comprobante) pero no mueve dinero ni pide datos de tarjeta. */
void VentanaGestion::registrarSena()
{
    if (senaPagada) {
        const auto respuesta = QMessageBox::question(this, "Anular el pago",
            QString("¿Anular el registro del pago de la seña (comprobante %1)?").arg(comprobante));
        if (respuesta == QMessageBox::Yes) {
            senaPagada = false;
            medioPago.clear();
            comprobante.clear();
        }
        actualizarBotonSena();
        return;
    }

    bool ok = false;
    const QString medio = QInputDialog::getItem(this, "Registrar pago de la seña",
        QString("Seña a cobrar: %1\n\n¿Con qué medio pagó la paciente?").arg(ui->lblSena->text()),
        DatosPrueba::mediosDePago(), 0, false, &ok);
    if (ok) {
        senaPagada = true;
        medioPago = medio;
        comprobante = QString("SIM-%1").arg(proximoComprobante++, 6, 10, QChar('0'));
        QMessageBox::information(this, "Pago registrado",
            QString("Seña de %1 registrada como pagada.\nMedio: %2\nComprobante: %3\n\n"
                    "Es un registro simulado: no se procesó dinero real.")
                .arg(ui->lblSena->text(), medioPago, comprobante));
    }
    actualizarBotonSena();
}

void VentanaGestion::confirmarTurno()
{
    const Protocolo *p = protocoloElegido();
    const QDateTime inicio = horarioElegido();
    if (!p || !inicio.isValid()) {   /* no debería pasar: los pasos 1 y 2 ya lo revisan */
        irA(PagProtocolo);
        return;
    }

    if (!senaPagada) {
        const auto respuesta = QMessageBox::question(this, "Seña sin pagar",
            "La seña todavía no está pagada.\n¿Confirmar el turno igual? Queda con la seña pendiente.");
        if (respuesta != QMessageBox::Yes)
            return;
    }

    Turno t;
    t.paciente = ui->editPaciente->text().simplified();
    t.dni = ui->editDni->text().trimmed();
    t.telefono = Reglas::sinSeparadores(ui->editTelefono->text());
    t.protocolo = p->nombre;
    t.fechaHora = inicio;
    t.duracionMin = p->duracionMin;
    t.sena = Reglas::calcularSena(p->precio, p->esCirugia);
    t.estadoSena = senaPagada ? EstadoSena::Pagada : EstadoSena::Pendiente;
    t.medioPago = medioPago;
    t.comprobante = comprobante;
    t.estado = EstadoTurno::Confirmado;
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
    senaPagada = false;
    medioPago.clear();
    comprobante.clear();
    actualizarBotonSena();
    actualizarHorarios();
}

/* RF-13: busca por nombre (si hay letras) o por DNI o teléfono (si son números). */
void VentanaGestion::buscarTurnos()
{
    const QString texto = ui->editBuscar->text().simplified();
    const QString numeros = Reglas::sinSeparadores(texto);
    const bool esNumero = !numeros.isEmpty() && std::all_of(numeros.cbegin(), numeros.cend(),
                                                            [](QChar c) { return c.isDigit(); });

    filasTabla.clear();
    for (int i = 0; i < turnos.size(); ++i) {
        const Turno &t = turnos[i];
        const bool coincide = texto.isEmpty()
            || (esNumero && (t.dni.contains(numeros) || t.telefono.contains(numeros)))
            || (!esNumero && t.paciente.contains(texto, Qt::CaseInsensitive));
        if (coincide)
            filasTabla.append(i);
    }
    std::sort(filasTabla.begin(), filasTabla.end(),
              [this](int a, int b) { return turnos[a].fechaHora < turnos[b].fechaHora; });

    ui->tablaTurnos->clearContents();
    ui->tablaTurnos->setRowCount(filasTabla.size());
    for (int fila = 0; fila < filasTabla.size(); ++fila) {
        const Turno &t = turnos[filasTabla[fila]];
        const QString columnas[] = {
            t.paciente, t.dni, t.telefono, t.protocolo,
            t.fechaHora.toString("dd/MM/yy HH:mm"), DatosPrueba::texto(t.estado),
            QString("%1 (%2)").arg(pesos(t.sena), DatosPrueba::texto(t.estadoSena)),
        };
        for (int col = ColPaciente; col <= ColSena; ++col) {
            auto *item = new QTableWidgetItem(columnas[col]);
            if (t.estado == EstadoTurno::Realizado)
                item->setForeground(QColor(122, 106, 100));   /* gris: ya pasó */
            else if (t.estado == EstadoTurno::Cancelado)
                item->setForeground(QColor(163, 58, 58));     /* rojo: cancelado */
            ui->tablaTurnos->setItem(fila, col, item);
        }
    }

    const int cantidad = filasTabla.size();
    ui->lblCuenta->setText(cantidad == 1 ? "1 turno" : QString("%1 turnos").arg(cantidad));
    mostrarRecordatorio();
}

/* RF-11: muestra cuándo sale el recordatorio del turno elegido. */
void VentanaGestion::mostrarRecordatorio()
{
    const int fila = ui->tablaTurnos->currentRow();
    const bool haySeleccion = fila >= 0 && fila < filasTabla.size()
                              && !ui->tablaTurnos->selectedItems().isEmpty();
    if (!haySeleccion) {
        ui->lblRecordatorio->setText("Elegí un turno de la tabla para ver su recordatorio o cancelarlo.");
        return;
    }

    const Turno &t = turnos[filasTabla[fila]];
    const QDateTime aviso = t.fechaHora.addDays(-1);
    if (t.estado != EstadoTurno::Confirmado)
        ui->lblRecordatorio->setText(QString("Turno %1: no tiene recordatorio.").arg(DatosPrueba::texto(t.estado).toLower()));
    else if (aviso <= QDateTime::currentDateTime())
        ui->lblRecordatorio->setText("El recordatorio de este turno ya se envió (RF-11).");
    else
        ui->lblRecordatorio->setText(QString("Recordatorio programado para el %1 · %2 (RF-11).")
                                         .arg(fechaLarga(aviso.date()), aviso.toString("HH:mm")));
}

/* RF-13 y RF-10: cancela el turno elegido. Si la seña estaba pagada, se
 * reembolsa con más de 24 h de anticipación; si no, el instituto la retiene. */
void VentanaGestion::cancelarTurno()
{
    const int fila = ui->tablaTurnos->currentRow();
    if (fila < 0 || fila >= filasTabla.size() || ui->tablaTurnos->selectedItems().isEmpty()) {
        QMessageBox::information(this, "Cancelar turno", "Primero elegí un turno de la tabla.");
        return;
    }

    Turno &t = turnos[filasTabla[fila]];
    if (t.estado != EstadoTurno::Confirmado) {
        QMessageBox::warning(this, "Cancelar turno",
            QString("Este turno ya está %1: no se puede cancelar.").arg(DatosPrueba::texto(t.estado).toLower()));
        return;
    }

    const QDateTime ahora = QDateTime::currentDateTime();
    const bool reembolsa = Reglas::senaReembolsable(t.fechaHora, ahora);
    QString detalleSena;
    if (t.estadoSena != EstadoSena::Pagada)
        detalleSena = "La seña no estaba pagada: no hay nada que devolver.";
    else if (reembolsa)
        detalleSena = QString("Faltan más de %1 h: se reembolsa la seña completa (%2).")
                          .arg(Reglas::HorasParaReembolso).arg(pesos(t.sena));
    else
        detalleSena = QString("Faltan menos de %1 h: la seña de %2 no se reembolsa.")
                          .arg(Reglas::HorasParaReembolso).arg(pesos(t.sena));

    const auto respuesta = QMessageBox::question(this, "Cancelar turno",
        QString("¿Cancelar el turno de %1?\n%2 · %3, %4\n\n%5")
            .arg(t.paciente, t.protocolo, fechaLarga(t.fechaHora.date()), t.fechaHora.toString("HH:mm"),
                 detalleSena));
    if (respuesta != QMessageBox::Yes)
        return;

    t.estado = EstadoTurno::Cancelado;
    if (t.estadoSena == EstadoSena::Pagada)
        t.estadoSena = reembolsa ? EstadoSena::Reembolsada : EstadoSena::Retenida;

    buscarTurnos();
    actualizarHorarios();   /* el horario vuelve a quedar libre */
}
