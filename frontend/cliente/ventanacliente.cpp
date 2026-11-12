#include "ventanacliente.h"
#include "ui_ventanacliente.h"

#include "reembolso.h"
#include "sena.h"
#include "validaciones.h"

#include <QCalendarWidget>
#include <QGraphicsDropShadowEffect>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMessageBox>
#include <QPushButton>
#include <QRandomGenerator>
#include <QRegularExpressionValidator>
#include <QStyle>
#include <QTextCharFormat>
#include <algorithm>

/* Orden de las páginas dentro del QStackedWidget `paginas` del .ui. */
enum Pagina { PagInicio, PagProtocolo, PagHorario, PagConfirmar, PagBuscador, PagMiTurno };

/* Primer año en que se pueden sacar turnos. */
static const int ANIO_INICIAL = 2026;

static QString pesos(int monto)
{
    return "$" + QLocale().toString(monto);   /* $25.000 */
}

/* "+54 11 4444-3322" → "541144443322". */
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

VentanaCliente::VentanaCliente(QWidget *parent)
    : QMainWindow(parent), ui(new Ui::VentanaCliente)
{
    ui->setupUi(this);   /* crea todos los widgets dibujados en el .ui */

    /* Sábado y domingo vienen en rojo: los dejamos como el resto. */
    ui->calendario->setWeekdayTextFormat(Qt::Saturday, QTextCharFormat());
    ui->calendario->setWeekdayTextFormat(Qt::Sunday, QTextCharFormat());

    /* Sombra suave debajo de cada tarjeta, igual que en Gestión. */
    for (QFrame *tarjeta : findChildren<QFrame *>()) {
        if (!tarjeta->property("tarjeta").toBool() && tarjeta != ui->hero)
            continue;
        auto *sombra = new QGraphicsDropShadowEffect(tarjeta);
        sombra->setBlurRadius(28);
        sombra->setOffset(0, 6);
        sombra->setColor(QColor(90, 55, 40, 26));   /* marrón casi transparente */
        tarjeta->setGraphicsEffect(sombra);
    }

    /* Máscaras de entrada: mientras se escribe solo entran los caracteres válidos
     * (sin números en el nombre, sin letras en el DNI ni en el teléfono). */
    ui->editNombre->setMaxLength(60);
    ui->editNombre->setValidator(new QRegularExpressionValidator(Validaciones::filtroNombre(), this));
    ui->editDni->setMaxLength(8);
    ui->editDni->setValidator(new QRegularExpressionValidator(QRegularExpression("[0-9]{0,8}"), this));
    ui->editTelefono->setMaxLength(14);
    ui->editTelefono->setValidator(new QRegularExpressionValidator(QRegularExpression("\\+?[0-9]{0,13}"), this));
    ui->editBuscarTurno->setMaxLength(14);
    ui->editBuscarTurno->setValidator(new QRegularExpressionValidator(QRegularExpression("\\+?[0-9]{0,13}"), this));

    /* Señales y slots: connect(quién avisa, qué pasó, quién reacciona, qué hace). */

    /* Franja de arriba: "Inicio" vuelve al principio desde cualquier pantalla. */
    connect(ui->btnInicio, &QPushButton::clicked, this, [this] { irA(PagInicio); });
    connect(ui->btnAyuda, &QPushButton::clicked, this, [this] {
        QMessageBox::information(this, "Ayuda",
            "Sacar un turno: elegí el protocolo, después el horario y confirmá.\n"
            "Buscar mi turno: con tu DNI o tu teléfono; desde ahí lo podés cancelar.\n"
            "Si necesitás una mano, acercate a la recepción.");
    });

    /* Las tres opciones de la pantalla de inicio. */
    connect(ui->btnSacarTurno, &QPushButton::clicked, this, [this] { irA(PagProtocolo); });
    connect(ui->btnVerPrecios, &QPushButton::clicked, this, [this] { irA(PagBuscador); });
    connect(ui->btnMiTurno, &QPushButton::clicked, this, [this] { irA(PagMiTurno); });

    /* Los 3 pasos de sacar un turno (RF-01): Continuar avanza, Volver retrocede. */
    connect(ui->btnVolver1, &QPushButton::clicked, this, [this] { irA(PagInicio); });
    connect(ui->btnContinuar1, &QPushButton::clicked, this, &VentanaCliente::continuarProtocolo);
    connect(ui->btnVolver2, &QPushButton::clicked, this, [this] { irA(PagProtocolo); });
    connect(ui->btnContinuar2, &QPushButton::clicked, this, &VentanaCliente::continuarHorario);
    connect(ui->btnVolver3, &QPushButton::clicked, this, [this] { irA(PagHorario); });
    connect(ui->btnConfirmar, &QPushButton::clicked, this, &VentanaCliente::confirmar);

    /* Calendario: desde 2026; si se elige un día que ya pasó, se ofrece el mismo día del año que viene. */
    notaHorarioOriginal = ui->lblNotaHorario->text();
    ui->calendario->setMinimumDate(QDate(ANIO_INICIAL, 1, 1));
    ui->calendario->setSelectedDate(QDate::currentDate());
    marcarDiasPasados();
    connect(ui->calendario, &QCalendarWidget::selectionChanged, this, &VentanaCliente::diaElegido);

    /* Buscar mi turno: con el botón o con Enter; se puede cancelar desde ahí. */
    ui->editBuscarTurno->clear();   /* no hay turnos hasta que se cargan */
    ocultarTurno();
    connect(ui->btnBuscarTurno, &QPushButton::clicked, this, &VentanaCliente::buscarMiTurno);
    connect(ui->editBuscarTurno, &QLineEdit::returnPressed, this, &VentanaCliente::buscarMiTurno);
    connect(ui->btnCancelarMiTurno, &QPushButton::clicked, this, &VentanaCliente::cancelarMiTurno);

    cargarProtocolos();
    ui->editNombre->clear();
    ui->editDni->clear();
    ui->editTelefono->clear();
    actualizarHorarios();

    /* El botón de la seña queda apretado (checkable): cambia el texto (RF-08). */
    connect(ui->btnSena, &QPushButton::toggled, this, [this](bool pagada) {
        ui->btnSena->setText(pagada ? "✓  Seña pagada" : "Pagar seña (simulado)");
    });
}

VentanaCliente::~VentanaCliente()
{
    delete ui;
}

void VentanaCliente::irA(int pagina)
{
    ui->paginas->setCurrentIndex(pagina);
}


/* ---------------------------------------------------------------------------
 * Carga de un turno en memoria
 * --------------------------------------------------------------------------- */

/* La lista de protocolos sale de los datos de prueba (los mismos de Gestión). */
void VentanaCliente::cargarProtocolos()
{
    protocolos = DatosPrueba::protocolos();
    ui->listaProtocolos->clear();
    protocolosVisibles.clear();
    for (int i = 0; i < protocolos.size(); ++i) {
        if (!protocolos[i].activo)
            continue;
        protocolosVisibles << i;
        ui->listaProtocolos->addItem(QString("%1\n%2 min · %3")
                                         .arg(protocolos[i].nombre).arg(protocolos[i].duracionMin).arg(pesos(protocolos[i].precio)));
    }
    ui->listaProtocolos->setCurrentRow(-1);
}

const Protocolo *VentanaCliente::protocoloElegido() const
{
    const QListWidgetItem *item = ui->listaProtocolos->currentItem();
    const int fila = ui->listaProtocolos->currentRow();
    if (!item || !item->isSelected() || fila < 0 || fila >= protocolosVisibles.size())
        return nullptr;
    return &protocolos[protocolosVisibles[fila]];
}

QDateTime VentanaCliente::horarioElegido() const
{
    const QListWidgetItem *item = ui->listaHorarios->currentItem();
    if (!item || !item->isSelected() || !(item->flags() & Qt::ItemIsSelectable))
        return {};
    return QDateTime(ui->calendario->selectedDate(), QTime::fromString(item->text(), "HH:mm"));
}

void VentanaCliente::continuarProtocolo()
{
    const Protocolo *p = protocoloElegido();
    if (!p) {
        QMessageBox::warning(this, "Falta el protocolo", "Tocá el tratamiento que querés hacerte para continuar.");
        return;
    }
    ui->lblPasoHorario->setText(QString("%1 (%2 min)").arg(p->nombre).arg(p->duracionMin));
    actualizarHorarios();
    irA(PagHorario);
}

/* Los días anteriores a hoy se ven en gris en el calendario. */
void VentanaCliente::marcarDiasPasados()
{
    QTextCharFormat gris;
    gris.setForeground(QColor(176, 164, 158));
    const QDate hoy = QDate::currentDate();
    for (QDate dia(ANIO_INICIAL, 1, 1); dia < hoy; dia = dia.addDays(1))
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
                                 .arg(que).arg(proxima.year()).arg(fechaLarga(proxima) + " de " + QString::number(proxima.year())),
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
    const QDateTime ahora = QDateTime::currentDateTime();
    ui->listaHorarios->clear();
    ui->lblNotaHorario->setText(notaHorarioOriginal);

    if (dia.dayOfWeek() == Qt::Sunday) {
        ui->lblNotaHorario->setText("Los domingos el instituto no atiende. Elegí otro día.");
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
    if (ui->listaHorarios->count() == 0)
        ui->lblNotaHorario->setText("No quedan horarios libres ese día. Probá con otro.");
}

void VentanaCliente::continuarHorario()
{
    const Protocolo *p = protocoloElegido();
    const QDateTime inicio = horarioElegido();
    if (!p) {
        irA(PagProtocolo);
        return;
    }
    if (!inicio.isValid()) {
        QMessageBox::warning(this, "Falta el horario", "Elegí un día y tocá un horario libre.");
        return;
    }
    ui->lblResProtocolo->setText(p->nombre);
    ui->lblResFecha->setText(fechaLarga(inicio.date()) + " de " + QString::number(inicio.date().year()));
    ui->lblResHora->setText(QString("%1 (%2 min)").arg(inicio.toString("HH:mm")).arg(p->duracionMin));
    ui->lblResPrecio->setText(pesos(p->precio));
    ui->lblSena->setText(pesos(Sena::calcular(p->precio, p->categoria.porcentajeSena)));
    ui->lblReglaSena->setText(QString("%1% del precio (categoría %2); se descuenta del total al pagar. "
                                      "Se reembolsa si se cancela con más de 24 h de anticipación.")
                                  .arg(p->categoria.porcentajeSena).arg(p->categoria.nombre));
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

QString VentanaCliente::nuevoCodigoOperacion() const
{
    for (;;) {
        const QString codigo = QString("SIM-%1").arg(QRandomGenerator::global()->bounded(100000, 1000000));
        const bool usado = std::any_of(turnos.cbegin(), turnos.cend(),
                                       [&](const Turno &t) { return t.codigoOperacion == codigo; });
        if (!usado)
            return codigo;
    }
}

/* Paso 3: se valida, se carga el turno al momento y se muestra en "Buscar mi turno". */
void VentanaCliente::confirmar()
{
    const Protocolo *p = protocoloElegido();
    const QDateTime inicio = horarioElegido();
    if (!p || !inicio.isValid()) {   /* no debería pasar: los pasos anteriores ya lo revisan */
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
    const bool ocupado = std::any_of(turnos.cbegin(), turnos.cend(), [&](const Turno &t) {
        return t.inicio == inicio && t.estado != EstadoTurno::Cancelado;
    });
    if (ocupado) {
        QMessageBox::warning(this, "Horario ocupado", "Ese horario ya no está libre. Elegí otro.");
        actualizarHorarios();
        irA(PagHorario);
        return;
    }

    Turno nuevo = { ui->editNombre->text().simplified(), soloDigitos(ui->editDni->text()),
                    soloDigitos(ui->editTelefono->text()), p->nombre, p->precio,
                    Sena::calcular(p->precio, p->categoria.porcentajeSena), inicio,
                    inicio.addSecs(p->duracionMin * 60), EstadoTurno::Confirmado, "Terminal",
                    ui->btnSena->isChecked(), QString(), 0 };
    if (nuevo.senaPagada)   /* seña simulada: imita un pago real pero no mueve dinero */
        nuevo.codigoOperacion = nuevoCodigoOperacion();
    turnos.append(nuevo);

    QString mensaje = QString("¡Listo! Tu turno quedó reservado.\n%1 · %2 de %3, %4")
                          .arg(nuevo.protocolo, fechaLarga(inicio.date()), QString::number(inicio.date().year()), inicio.toString("HH:mm"));
    mensaje += nuevo.senaPagada ? QString("\nSeña pagada (simulada): código %1.").arg(nuevo.codigoOperacion)
                                : "\nLa seña quedó sin pagar: acercate a recepción para abonarla.";
    QMessageBox::information(this, "Turno confirmado", mensaje);

    const QString dni = nuevo.dni;
    reiniciarCarga();
    ui->editBuscarTurno->setText(dni);   /* se muestra el turno recién cargado */
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
    ui->btnSena->setChecked(false);
    ajustandoFecha = true;
    ui->calendario->setSelectedDate(QDate::currentDate());
    ajustandoFecha = false;
    actualizarHorarios();
}

/* ---------------------------------------------------------------------------
 * Buscar mi turno y cancelarlo
 * --------------------------------------------------------------------------- */

void VentanaCliente::ocultarTurno()
{
    turnoMostrado = -1;
    ui->tarjetaMiTurno->setVisible(false);
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
    const QString buscado = soloDigitos(texto);
    const QDateTime ahora = QDateTime::currentDateTime();
    QVector<int> encontrados;
    for (int i = 0; i < turnos.size(); ++i)
        if (turnos[i].dni == buscado || soloDigitos(turnos[i].telefono) == buscado)
            encontrados << i;
    if (encontrados.isEmpty()) {
        ocultarTurno();
        QMessageBox::information(this, "Sin turnos", QString("No encontramos turnos para %1.").arg(buscado));
        return;
    }
    const auto vigente = [&](int i) {
        return (turnos[i].estado == EstadoTurno::Confirmado || turnos[i].estado == EstadoTurno::Pendiente)
               && turnos[i].inicio > ahora;
    };
    int elegido = -1;
    int vigentes = 0;
    for (int i : encontrados) {
        if (!vigente(i))
            continue;
        ++vigentes;
        if (elegido < 0 || turnos[i].inicio < turnos[elegido].inicio)
            elegido = i;
    }
    if (elegido < 0)   /* ninguno vigente: se muestra el más reciente */
        elegido = *std::max_element(encontrados.cbegin(), encontrados.cend(),
                                    [&](int a, int b) { return turnos[a].inicio < turnos[b].inicio; });
    mostrarTurno(elegido, vigentes);
}

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
    ui->lblResTurnoFecha->setText(fechaLarga(t.inicio.date()) + " de " + QString::number(t.inicio.date().year()));
    ui->lblResTurnoHora->setText(QString("%1 (%2 min)").arg(t.inicio.toString("HH:mm")).arg(t.inicio.secsTo(t.fin) / 60));
    QString sena = pesos(t.sena) + (t.senaPagada ? " · pagada" : " · sin pagar");
    if (t.estado == EstadoTurno::Cancelado && t.senaPagada)
        sena = t.reembolsado > 0 ? QString("%1 · reembolsada").arg(pesos(t.reembolsado)) : QString("%1 · no reembolsable").arg(pesos(t.sena));
    ui->lblResTurnoSena->setText(sena);
    if (t.estado == EstadoTurno::Cancelado) {
        ui->lblRecordatorio->setText("Turno cancelado: ya no te enviamos recordatorios.");
    } else {
        const QDateTime aviso = t.inicio.addDays(-1);
        ui->lblRecordatorio->setText(QString("Te lo vamos a recordar el %1 a las %2.").arg(fechaLarga(aviso.date()), aviso.toString("HH:mm")));
    }
    ui->btnCancelarMiTurno->setEnabled(activo);
    ui->tarjetaMiTurno->setVisible(true);
}

/* RF-10: más de 24 h de anticipación y seña pagada → se devuelve el 100%; si no, queda retenida. */
void VentanaCliente::cancelarMiTurno()
{
    if (turnoMostrado < 0 || turnoMostrado >= turnos.size())
        return;
    Turno &t = turnos[turnoMostrado];
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
        regla = QString("Faltan más de %1 horas: se te devuelve la seña completa (%2).").arg(Reembolso::HORAS_LIMITE).arg(pesos(devolver));
    else
        regla = QString("Faltan %1 horas o menos: la seña (%2) no se devuelve.").arg(Reembolso::HORAS_LIMITE).arg(pesos(t.sena));

    const auto respuesta = QMessageBox::question(this, "Cancelar turno",
        QString("¿Querés cancelar tu turno de %1 del %2?\n\n%3")
            .arg(t.protocolo, t.inicio.toString("dd/MM/yyyy HH:mm"), regla));
    if (respuesta != QMessageBox::Yes)
        return;

    t.estado = EstadoTurno::Cancelado;
    t.reembolsado = devolver;
    actualizarHorarios();              /* el horario vuelve a estar libre */
    mostrarTurno(turnoMostrado, 0);
    QMessageBox::information(this, "Turno cancelado",
                             devolver > 0 ? QString("Turno cancelado. Se te devolvieron %1.").arg(pesos(devolver)) : "Turno cancelado.");
}
