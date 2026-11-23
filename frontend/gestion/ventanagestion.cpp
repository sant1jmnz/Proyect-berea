#include "ventanagestion.h"
#include "ui_ventanagestion.h"

#include "avisoconexion.h"
#include "datosbase.h"
#include "formato.h"
#include "reglasturno.h"
#include "dialogologin.h"
#include "repositorio.h"
#include "conexionapp.h"
#include "paginaavisos.h"
#include "paginacupones.h"
#include "paginaevaluaciones.h"
#include "paginatarjetas.h"
#include "paginausuarios.h"
#include "paginapacientes.h"
#include "paginaprofesionales.h"
#include "paginaprotocolos.h"
#include "paginareportes.h"
#include "reembolso.h"
#include "sena.h"
#include "validaciones.h"

#include <QApplication>
#include <QFileInfo>
#include <QHBoxLayout>
#include <QListWidget>
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
              PagProtocolos, PagProfesionales, PagPacientes, PagAvisos, PagCupones, PagTarjetas,
              PagEvaluaciones, PagReportes, PagUsuarios };

/* A qué página lleva cada fila del menú lateral. Los pasos 2 y 3 no están
 * en el menú: se llega con "Continuar". */
static const int paginaDeMenu[] = { PagInicio, PagProtocolo, PagBuscador, PagBuscarTurnos,
                                    PagProtocolos, PagProfesionales, PagPacientes, PagAvisos, PagCupones,
                                    PagTarjetas, PagEvaluaciones, PagReportes, PagUsuarios };
enum { MenuCargarTurno = 1, MenuBuscarTurnos = 3 };
/* Columnas de `tablaTurnos`. */
enum { ColPaciente, ColDni, ColTelefono, ColProtocolo, ColFecha, ColEstado, ColSena };

/* Constructor de la pantalla de Gestión (la de la recepción). Arma la interfaz del .ui, el formulario de carga,
 *  * las señales (botones -> funciones), las pantallas nuevas del menú, y prueba la conexión a la base.
 *  * Sin base queda en modo contingencia con datos locales. */
VentanaGestion::VentanaGestion(QWidget *parent, const QString &archivoContingencia, bool datosDeEjemplo)
    : QMainWindow(parent), ui(new Ui::VentanaGestion)
{
    ui->setupUi(this);   /* crea todos los widgets dibujados en el .ui */

    /* Ajustes de aspecto que Qt Designer no deja marcar. */
    ui->tablaTurnos->horizontalHeader()->setSectionResizeMode(QHeaderView::ResizeToContents);
    ui->tablaTurnos->horizontalHeader()->setSectionResizeMode(ColProtocolo, QHeaderView::Stretch);
    /* Sábado y domingo vienen en rojo: los dejamos como el resto. */
    ui->calendario->setWeekdayTextFormat(Qt::Saturday, QTextCharFormat());
    ui->calendario->setWeekdayTextFormat(Qt::Sunday, QTextCharFormat());

    Formato::sombrearTarjetas(this, ui->hero);   /* sombra suave debajo de cada tarjeta, para que no se vea plano */

    cargarDatosLocales(datosDeEjemplo);
    armarPantallasNuevas();
    cargarProtocolos();
    const QDate hoy = QDate::currentDate();
    ui->lblFechaHoy->setText(QLocale().toString(hoy, "dddd d 'de' MMMM 'de' yyyy"));
    ui->calendario->setMinimumDate(hoy);   /* no se cargan turnos en el pasado */
    armarFormularioCarga();
    conectarSenales();
    probarConexion(archivoContingencia);

    actualizarHorarios();
    buscarTurnos();

    /* Si la Terminal (otra aplicación) carga o cancela un turno, aparece acá sin reiniciar. */
    if (persistir) {
        auto *relojLocal = new QTimer(this);
        connect(relojLocal, &QTimer::timeout, this, &VentanaGestion::sincronizarLocal);
        relojLocal->start(1000);   /* el archivo es local: alcanza con mirarlo cada segundo */
    }
}

/* Datos locales: sin base, todo se guarda en un archivo de esta PC (AlmacenLocal)
 * y arranca vacío, salvo el catálogo de protocolos. Las pruebas piden los datos
 * de ejemplo de DatosPrueba. */
void VentanaGestion::cargarDatosLocales(bool datosDeEjemplo)
{
    const QDateTime ahora = QDateTime::currentDateTime();
    protocolos = DatosPrueba::protocolos();
    persistir = !datosDeEjemplo;
    if (datosDeEjemplo) {
        turnos = DatosPrueba::turnos(ahora.date());
        profesionales = DatosPrueba::profesionales(ahora.date());
        pacientes = DatosPrueba::pacientes();
    } else {
        archivoLocal = AlmacenLocal::rutaPorDefecto();
        AlmacenLocal::Datos guardados;
        if (AlmacenLocal::leer(archivoLocal, &guardados)) {
            if (!guardados.protocolos.isEmpty())
                protocolos = guardados.protocolos;
            turnos = guardados.turnos;
            profesionales = guardados.profesionales;
            pacientes = guardados.pacientes;
        }
        ultimaVersionLocal = QFileInfo(archivoLocal).lastModified();
    }
    for (const Turno &t : std::as_const(turnos))   /* los turnos futuros ya tienen su aviso */
        if (t.estado == EstadoTurno::Confirmado && t.inicio > ahora)
            avisos.programar(t.paciente, t.dni, t.telefono, t.protocolo, t.inicio, ahora);
}

/* Paso 1 de la carga: mientras se escribe, el DNI y el teléfono solo aceptan números
 * (el teléfono, también un + adelante). La regla completa se revisa al continuar. */
void VentanaGestion::armarFormularioCarga()
{
    ui->editDni->setValidator(new QRegularExpressionValidator(Validaciones::filtroDni(), this));
    ui->editTelefono->setValidator(new QRegularExpressionValidator(Validaciones::filtroTelefono(), this));
    ui->editTelefono->setPlaceholderText("1155550102");
    ui->editPaciente->setPlaceholderText("Nombre y apellido");
    ui->editPaciente->setMaxLength(60);
    ui->editPaciente->setValidator(new QRegularExpressionValidator(Validaciones::filtroNombre(), this));   /* sin números ni símbolos */
    for (QLineEdit *campo : { ui->editPaciente, ui->editDni, ui->editTelefono })
        connect(campo, &QLineEdit::textEdited, this, [this, campo] { marcarError(campo, false); });
}

/* Señales y slots: connect(quién avisa, qué pasó, quién reacciona, qué hace). */
void VentanaGestion::conectarSenales()
{
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
}

/* Franja de aviso y modo contingencia (RNF-09). La conexión se prueba
 * apenas se muestra la ventana, para no demorar el arranque. */
void VentanaGestion::probarConexion(const QString &archivoContingencia)
{
    conexion = new ConexionApp(franja, ConfigBD::desdeEntorno(), archivoContingencia, this);
    /* Cuando la conexión se logra (ahora o con "Reintentar"), se pide el ingreso y se leen los datos de la base. */
    connect(conexion, &ConexionApp::conectada, this, &VentanaGestion::conectarBase);
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
    connect(conexion, &ConexionApp::pendientesSincronizados, this, [this](int enviados, const QStringList &problemas) {
        QString texto = QString("Volvió la conexión: se enviaron %1 turnos guardados en este equipo.").arg(enviados);
        if (!problemas.isEmpty())
            texto += "\n\nNo se pudieron enviar (siguen guardados):\n• " + problemas.join("\n• ");
        QMessageBox::information(this, "Turnos sincronizados", texto);
    });
    QTimer::singleShot(0, conexion, &ConexionApp::probar);
}

/* Destructor: guarda los datos locales antes de cerrar y libera la interfaz. */
VentanaGestion::~VentanaGestion()
{
    guardarLocal();
    delete ui;
}

/* Sin base: guarda protocolos, turnos, profesionales y pacientes en el archivo local. */
void VentanaGestion::guardarLocal()
{
    if (!persistir || enModoBase || datosDeBase)   /* con datos de la base en memoria no se pisa el archivo local */
        return;
    AlmacenLocal::Datos datos;
    datos.protocolos = protocolos;
    datos.turnos = turnos;
    datos.profesionales = profesionales;
    datos.pacientes = pacientes;
    if (AlmacenLocal::guardar(archivoLocal, datos))
        ultimaVersionLocal = QFileInfo(archivoLocal).lastModified();
}

/* Si otra aplicación cambió el archivo, se vuelven a leer los turnos y las pacientes. */
void VentanaGestion::sincronizarLocal()
{
    if (!persistir || enModoBase || datosDeBase)   /* no reemplazar la agenda de la base por un archivo viejo */
        return;
    const QDateTime version = QFileInfo(archivoLocal).lastModified();
    if (!version.isValid() || version == ultimaVersionLocal)
        return;
    AlmacenLocal::Datos guardados;
    if (!AlmacenLocal::leer(archivoLocal, &guardados))
        return;
    ultimaVersionLocal = version;
    turnos = guardados.turnos;
    pacientes = guardados.pacientes;
    const QDateTime ahora = QDateTime::currentDateTime();
    avisos = RegistroAvisos();
    for (const Turno &t : std::as_const(turnos))
        if (t.estado == EstadoTurno::Confirmado && t.inicio > ahora)
            avisos.programar(t.paciente, t.dni, t.telefono, t.protocolo, t.inicio, ahora);
    paginaAvisos->recargar();
    paginaPacientes->recargar();
    actualizarHorarios();
    buscarTurnos();
}

/* Agrega al menú y al QStackedWidget las pantallas que se arman por código:
 * Protocolos, Profesionales, Pacientes y Avisos; y pone arriba la franja de
 * "sin conexión con la base". */
void VentanaGestion::armarPantallasNuevas()
{
    for (const char *texto : { "Protocolos", "Profesionales", "Pacientes", "Avisos", "Cupones",
                               "Tarjetas de regalo", "Consultas previas", "Reportes", "Usuarios" })
        ui->menu->addItem(texto);

    paginaProtocolos = new PaginaProtocolos(&protocolos);
    paginaProfesionales = new PaginaProfesionales(&profesionales, &protocolos);
    paginaPacientes = new PaginaPacientes(&pacientes);
    paginaAvisos = new PaginaAvisos(&avisos);
    paginaCupones = new PaginaCupones;
    paginaTarjetas = new PaginaTarjetas;
    paginaEvaluaciones = new PaginaEvaluaciones;
    paginaReportes = new PaginaReportes;
    paginaUsuarios = new PaginaUsuarios;
    /* Quedan en el QStackedWidget en el orden de Pagina; el nombre lo usan las pruebas. */
    QWidget *nuevas[] = { paginaProtocolos, paginaProfesionales, paginaPacientes, paginaAvisos, paginaCupones,
                          paginaTarjetas, paginaEvaluaciones, paginaReportes, paginaUsuarios };
    const char *nombres[] = { "pagProtocolos", "pagProfesionales", "pagPacientes", "pagAvisos", "pagCupones",
                              "pagTarjetas", "pagEvaluaciones", "pagReportes", "pagUsuarios" };
    for (int i = 0; i < 9; ++i) {
        nuevas[i]->setObjectName(nombres[i]);
        ui->paginas->addWidget(nuevas[i]);
    }

    connect(paginaProtocolos, &PaginaProtocolos::cambiaron, this, &VentanaGestion::protocolosCambiaron);
    connect(paginaPacientes, &PaginaPacientes::cargarTurnoPara, this, &VentanaGestion::cargarTurnoPara);
    connect(paginaPacientes, &PaginaPacientes::cambiaron, this, &VentanaGestion::guardarLocal);
    connect(paginaProfesionales, &PaginaProfesionales::cambiaron, this, &VentanaGestion::guardarLocal);

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

/* Cambia de página del QStackedWidget 'paginas' (PagProtocolo, PagHorario, PagConfirmar, ...). */
void VentanaGestion::irA(int pagina)
{
    ui->paginas->setCurrentIndex(pagina);
}

/* Se dispara al tocar un ítem del menú lateral: traduce la fila del menú a su página y la muestra. */
void VentanaGestion::cambiarSeccion(int fila)
{
    if (fila < 0)
        return;
    irA(paginaDeMenu[fila]);
    if (enModoBase && ui->paginas->currentWidget() == paginaPacientes)
        sincronizarPacientes();   /* al entrar, la lista ya está al día */
}

/* Llena la lista de tratamientos del paso 1: solo los activos, con nombre, duración y precio.
 *  * Para cambiar cómo se ve cada ítem (ej. el precio) se toca el QString del addItem. */
void VentanaGestion::cargarProtocolos()
{
    ui->listaProtocolos->clear();
    protocolosVisibles.clear();
    for (int i = 0; i < protocolos.size(); ++i) {
        const Protocolo &p = protocolos[i];
        if (!p.activo)
            continue;   /* los protocolos dados de baja ya no se ofrecen */
        protocolosVisibles << i;
        ui->listaProtocolos->addItem(QString("%1\n%2 min · %3").arg(p.nombre).arg(p.duracionMin).arg(Formato::pesos(p.precio)));
    }
    ui->buscador->setCatalogo(DatosPrueba::comoTratamientos(protocolos));   /* el buscador de precios usa el mismo catálogo */
}

/* Se llama cuando se edita el catálogo de protocolos: refresca la lista, la pantalla de profesionales y guarda. */
void VentanaGestion::protocolosCambiaron()
{
    cargarProtocolos();
    paginaProfesionales->recargarProtocolos();
    guardarLocal();
}

/* Salta a 'Cargar turno' con nombre, DNI y teléfono ya completados (se usa desde la pantalla de pacientes). */
void VentanaGestion::cargarTurnoPara(const QString &nombre, const QString &dni, const QString &telefono)
{
    ui->editPaciente->setText(nombre);
    ui->editDni->setText(dni);
    ui->editTelefono->setText(telefono);
    ui->menu->setCurrentRow(MenuCargarTurno);
}

/* Devuelve el protocolo marcado en la lista, o nullptr si no hay ninguno. */
const Protocolo *VentanaGestion::protocoloElegido() const
{
    const int fila = ui->listaProtocolos->currentRow();
    if (!ui->listaProtocolos->currentItem() || !ui->listaProtocolos->currentItem()->isSelected())
        return nullptr;
    return (fila >= 0 && fila < protocolosVisibles.size()) ? &protocolos[protocolosVisibles[fila]] : nullptr;
}

/* Devuelve fecha y hora del horario marcado, o un QDateTime vacío si no hay ninguno.
 *  * Con la base el horario completo viaja en el ítem (Qt::UserRole); sin base se arma con el día del calendario + el texto 'HH:mm'. */
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
    Validaciones::nombreApellidoValido(ui->editPaciente->text(), &errorNombre);
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

    ui->listaHorarios->addItems(ReglasTurno::horariosLibresSinBase(dia, turnos, QDateTime::currentDateTime()));

    if (ui->listaHorarios->count() == 0) {
        auto *item = new QListWidgetItem("No quedan horarios libres este día");
        item->setFlags(Qt::NoItemFlags);
        ui->listaHorarios->addItem(item);
    }
}

/* Botón 'Continuar' del paso 2: exige un horario, arma el resumen del paso 3 (paciente, precio, seña,
 *  * fecha, recordatorio 24 h antes) y muestra la página de confirmación. */
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
    ui->lblResPrecio->setText(Formato::pesos(p->precio));
    ui->lblSena->setText(Formato::pesos(Sena::calcular(p->precio, p->categoria.porcentajeSena)));
    ui->lblReglaSena->setText(
        QString("%1% del precio (categoría %2); se descuenta del total al pagar. "
                "Se reembolsa si se cancela con más de 24 h de anticipación (RF-10).")
            .arg(p->categoria.porcentajeSena).arg(p->categoria.nombre));
    ui->lblResFecha->setText(Formato::fechaLarga(inicio.date()));
    QString textoHora = QString("%1 (%2 min)").arg(inicio.toString("HH:mm")).arg(p->duracionMin);
    if (enModoBase && ui->listaHorarios->currentItem())   /* el ítem dice "09:00 · Apellido, Nombre" */
        textoHora += " · con " + ui->listaHorarios->currentItem()->text().section(" · ", 1);
    ui->lblResHora->setText(textoHora);
    const QDateTime aviso = inicio.addDays(-1);
    ui->lblResRecordatorio->setText(QString("%1 · %2 (RF-11)").arg(Formato::fechaLarga(aviso.date()), aviso.toString("HH:mm")));
    irA(PagConfirmar);
}

/* Botón 'Confirmar' del paso 3: con base delega en confirmarTurnoEnBase; sin base revisa que el horario
 *  * no se haya ocupado, guarda el turno, programa el recordatorio de 24 h, avisa y, si no hay conexión,
 * lo deja en contingencia (RNF-09). Al final vuelve a la búsqueda mostrando ese turno. */
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
    sincronizarLocal();   /* por si la Terminal tomó ese horario hace un instante */
    if (ReglasTurno::horarioOcupado(turnos, inicio)) {
        QMessageBox::warning(this, "Horario ocupado",
                             "Ese horario acaba de ocuparse. Elegí otro, por favor.");
        actualizarHorarios();
        irA(PagHorario);
        return;
    }

    Turno nuevo = { ui->editPaciente->text().simplified(), ui->editDni->text().trimmed(),
                    Validaciones::soloDigitos(ui->editTelefono->text()), p->nombre, p->precio,
                    Sena::calcular(p->precio, p->categoria.porcentajeSena), inicio,
                    inicio.addSecs(p->duracionMin * 60), EstadoTurno::Confirmado, "Gestión",
                    ui->btnSena->isChecked(), QString(), 0 };
    /* Seña paga (RF-09): queda con su código de operación. */
    if (nuevo.senaPagada)
        nuevo.codigoOperacion = ReglasTurno::nuevoCodigoOperacion(turnos);
    turnos.append(nuevo);
    const bool conocida = std::any_of(pacientes.cbegin(), pacientes.cend(),
                                      [&](const Paciente &x) { return x.dni == nuevo.dni; });
    if (!conocida) {   /* la paciente nueva queda en la pantalla Pacientes */
        pacientes.append({ nuevo.paciente, nuevo.dni, nuevo.telefono, QString(), QDate() });
        paginaPacientes->recargar();
    }
    guardarLocal();
    /* Recordatorio 24 h antes (RF-11): queda registrado en la pantalla Avisos. */
    const QDateTime ahora = QDateTime::currentDateTime();
    avisos.programar(nuevo.paciente, nuevo.dni, nuevo.telefono, nuevo.protocolo, nuevo.inicio, ahora);
    paginaAvisos->recargar();

    QString mensaje = QString("El turno quedó cargado.\n%1 · %2, %3")
                          .arg(nuevo.paciente, Formato::fechaLarga(inicio.date()), inicio.toString("HH:mm"));
    if (nuevo.senaPagada)
        mensaje += QString("\nPago de la seña aprobado (código %1).").arg(nuevo.codigoOperacion);
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
    if (enModoBase)
        refrescarTurnosDeBase(ui->editBuscar->text().simplified());
    mostrarTurnos();
}

/* Filtra y dibuja la tabla de turnos: si lo escrito son números busca por DNI o teléfono, si es texto por nombre.
 *  * Ordena por fecha, pinta de gris los realizados/cancelados y muestra el estado de la seña. */
void VentanaGestion::mostrarTurnos()
{
    const QString texto = ui->editBuscar->text().simplified();
    const QString numeros = Validaciones::soloDigitos(texto);
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
        QString sena = QString("%1 (%2)").arg(Formato::pesos(t.sena), t.senaPagada ? "pagada" : "sin pagar");
        if (t.estado == EstadoTurno::Cancelado && t.senaPagada)
            sena = t.reembolsado > 0 ? QString("%1 (reembolsada)").arg(Formato::pesos(t.reembolsado))
                                     : QString("%1 (no reembolsable)").arg(Formato::pesos(t.sena));
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
    if (!enModoBase || texto.size() < 3)   /* con una búsqueda en la base `turnos` es solo el resultado */
        actualizarInicio();
}

/* Inicio: el próximo turno, la agenda de hoy, los contadores y los próximos días salen de `turnos`
 * (los de la base cuando hay sesión, los locales si no). */
void VentanaGestion::actualizarInicio()
{
    const QDateTime ahora = QDateTime::currentDateTime();
    const QDate hoy = ahora.date();
    QVector<Turno> deHoy, proximos;
    int sinSena = 0;
    for (const Turno &t : std::as_const(turnos)) {
        if (t.estado == EstadoTurno::Cancelado)
            continue;
        if (t.inicio.date() == hoy)
            deHoy.append(t);
        else if (ReglasTurno::esVigente(t, ahora))
            proximos.append(t);
        if (ReglasTurno::esVigente(t, ahora) && !t.senaPagada)
            ++sinSena;
    }
    const auto porHora = [](const Turno &a, const Turno &b) { return a.inicio < b.inicio; };
    std::sort(deHoy.begin(), deHoy.end(), porHora);
    std::sort(proximos.begin(), proximos.end(), porHora);

    const auto poner = [this](QLabel *l, const char *propiedad, const QString &valor) {
        l->setProperty(propiedad, valor);
        l->style()->unpolish(l);
        l->style()->polish(l);
    };
    const QStringList colores = { "rosa", "dorado", "salvia" };
    const auto inicial = [](const QString &nombre) { return nombre.trimmed().left(1).toUpper(); };
    const QLocale es(QLocale::Spanish, QLocale::Argentina);

    /* Hero: el primer turno de hoy que todavía no empezó, o el próximo que haya. */
    const Turno *siguiente = nullptr;
    for (const Turno &t : std::as_const(deHoy))
        if (t.inicio > ahora) { siguiente = &t; break; }
    if (!siguiente && !proximos.isEmpty())
        siguiente = &proximos.first();
    if (siguiente) {
        ui->lblHeroEtiqueta->setText(QString("PRÓXIMO TURNO · %1").arg(siguiente->protocolo.toUpper()));
        ui->lblHeroTitulo->setText(QString("%1 · %2")
            .arg(siguiente->inicio.date() == hoy ? siguiente->inicio.toString("HH:mm")
                                                 : es.toString(siguiente->inicio, "ddd d · HH:mm"),
                 siguiente->paciente));
    } else {
        ui->lblHeroEtiqueta->setText("PRÓXIMO TURNO");
        ui->lblHeroTitulo->setText("Sin turnos pendientes");
    }

    /* Agenda de hoy: hasta 5 filas; las que sobran se esconden. */
    ui->lblAgenda->setText(deHoy.isEmpty() ? "Hoy en el instituto · sin turnos" : "Hoy en el instituto");
    for (int n = 1; n <= 5; ++n) {
        auto *fila = findChild<QFrame *>(QString("filaAgenda%1").arg(n));
        if (!fila)
            continue;
        const bool hay = n <= deHoy.size();
        fila->setVisible(hay);
        if (!hay)
            continue;
        const Turno &t = deHoy[n - 1];
        findChild<QLabel *>(QString("lblHora%1").arg(n))->setText(t.inicio.toString("HH:mm"));
        findChild<QLabel *>(QString("lblNombre%1").arg(n))->setText(t.paciente);
        findChild<QLabel *>(QString("lblDetalle%1").arg(n))->setText(t.protocolo);
        auto *avatar = findChild<QLabel *>(QString("avatarAgenda%1").arg(n));
        avatar->setText(inicial(t.paciente));
        poner(avatar, "avatar", colores[(n - 1) % colores.size()]);
        auto *sena = findChild<QLabel *>(QString("lblSenaFila%1").arg(n));
        sena->setText(t.senaPagada ? "Pagada" : "Sin seña");
        poner(sena, "etiqueta", t.senaPagada ? "ok" : "pendiente");
    }

    /* Contadores. */
    ui->lblNumHoy->setText(QString::number(deHoy.size()));
    ui->lblNumLibres->setText(QString::number(ReglasTurno::horariosLibresSinBase(hoy, turnos, ahora).size()));
    ui->lblNumProximos->setText(QString::number(proximos.size()));
    ui->lblNumSinSena->setText(QString::number(sinSena));

    /* Próximos días: los 3 siguientes que no son de hoy. */
    for (int n = 1; n <= 3; ++n) {
        auto *fila = findChild<QFrame *>(QString("filaProximo%1").arg(n));
        if (!fila)
            continue;
        const bool hay = n <= proximos.size();
        fila->setVisible(hay);
        if (!hay)
            continue;
        const Turno &t = proximos[n - 1];
        findChild<QLabel *>(QString("lblProximoNombre%1").arg(n))->setText(t.paciente);
        findChild<QLabel *>(QString("lblProximoDetalle%1").arg(n))->setText(
            QString("%1 · %2").arg(es.toString(t.inicio, "ddd d · HH:mm"), t.protocolo));
        auto *avatar = findChild<QLabel *>(QString("avatarProximo%1").arg(n));
        avatar->setText(inicial(t.paciente));
        poner(avatar, "avatar", colores[(n - 1) % colores.size()]);
    }
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
    const QString regla = ReglasTurno::explicacionReembolso(t, ahora);

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
        DatosBase::cargarAvisos(*repositorio, QDate::currentDate(), ReglasTurno::DIAS_AGENDA, avisos, &error);
        paginaAvisos->recargar();
        actualizarHorarios();
        buscarTurnos();
        QMessageBox::information(this, "Turno cancelado",
            r.valor > 0 ? QString("Turno cancelado. Se devolvieron %1.").arg(Formato::pesos(qRound(r.valor))) : QString("Turno cancelado. %1.").arg(r.dato));
        return;
    }

    t.estado = EstadoTurno::Cancelado;
    t.reembolsado = devolver;
    guardarLocal();
    avisos.anularDeTurno(t.dni, t.inicio);   /* el recordatorio ya no tiene sentido */
    paginaAvisos->recargar();
    actualizarHorarios();                    /* el horario vuelve a estar libre */
    buscarTurnos();
    if (fila < ui->tablaTurnos->rowCount())
        ui->tablaTurnos->selectRow(fila);    /* sigue a la vista, ya como cancelado */
    QMessageBox::information(this, "Turno cancelado",
        devolver > 0 ? QString("Turno cancelado. Se devolvieron %1.").arg(Formato::pesos(devolver)) : "Turno cancelado.");
}


/* ---------------------------------------------------------------------------
 * Con la base conectada: el personal ingresa, los datos salen de los stored
 * procedures y cada acción queda en el log con su usuario.
 * --------------------------------------------------------------------------- */

/* Se llama cuando hay conexión. Si el ingreso se cancela, se sigue con el archivo local y la franja lo avisa. */
void VentanaGestion::conectarBase()
{
    if (enModoBase)
        return;   /* ya estaba conectada */
    if (!repositorio)
        repositorio = new Repositorio(conexion->base());
    if (idUsuario == 0 && !pedirLogin()) {   /* al reconectar tras un corte no se vuelve a pedir el ingreso */
        franja->mostrarSinIngreso("No ingresaste con tu usuario y contraseña.");
        return;
    }
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
        || !DatosBase::cargarTurnos(*repositorio, hoy, ReglasTurno::DIAS_AGENDA, turnos, &error)
        || !DatosBase::cargarAvisos(*repositorio, hoy, ReglasTurno::DIAS_AGENDA, avisos, &error)) {
        QMessageBox::warning(this, "No se pudieron leer los datos", error);
        franja->mostrarSinIngreso("No se pudieron leer los datos de la base.");
        return;
    }
    enModoBase = true;
    datosDeBase = true;
    franja->hide();
    ui->lblUsuario->setText(rolUsuario == "administrador" ? "Administración" : "Recepción");
    ui->avatarUsuario->setText(rolUsuario == "administrador" ? "A" : "R");
    paginaProtocolos->usarBase(repositorio, idUsuario);
    paginaProfesionales->usarBase(repositorio, idUsuario);
    paginaPacientes->usarBase(repositorio, idUsuario);
    paginaAvisos->usarBase(repositorio);
    paginaReportes->usarBase(repositorio);
    paginaCupones->usarBase(repositorio, idUsuario);
    paginaTarjetas->usarBase(repositorio, idUsuario);
    paginaEvaluaciones->usarBase(repositorio, idUsuario);
    paginaUsuarios->usarBase(repositorio, idUsuario, rolUsuario);

    cargarProtocolos();
    paginaProtocolos->recargar();
    paginaProfesionales->recargarProfesionales(0);
    paginaPacientes->recargar();
    paginaAvisos->recargar();
    reiniciarCarga();
    buscarTurnos();

    /* Los dos programas trabajan sobre la misma base: cada 3 segundos se mira si
     * la Terminal (u otra PC) cargó, canceló o dio de alta algo, y se muestra. */
    if (!relojBase) {
        relojBase = new QTimer(this);
        relojBase->setInterval(ReglasTurno::MS_SINCRONIZAR);
        connect(relojBase, &QTimer::timeout, this, &VentanaGestion::sincronizarBase);
    }
    relojBase->start();
}

/* Con la base: si alguien dio de alta o cambió una paciente, se vuelve a mostrar la lista. */
void VentanaGestion::sincronizarPacientes()
{
    QVector<Paciente> pacientesNuevas;
    QString error;
    if (DatosBase::cargarPacientes(*repositorio, pacientesNuevas, &error)
        && DatosBase::resumen(pacientesNuevas) != DatosBase::resumen(pacientes)) {
        pacientes = pacientesNuevas;
        paginaPacientes->recargar();
    }
}

/* Con la base: si cambiaron los turnos o las pacientes (por la Terminal, otra PC o el
 * Workbench), se actualizan las pantallas sin perder lo que estaba elegido. */
void VentanaGestion::sincronizarBase()
{
    if (!enModoBase || QApplication::activeModalWidget())
        return;   /* con un cartel abierto se espera a la próxima vuelta */
    QString error;

    if (ui->paginas->currentWidget() == paginaPacientes)   /* la lista completa solo hace falta si se está viendo */
        sincronizarPacientes();

    const QVector<Turno> antes = turnos;
    refrescarTurnosDeBase(ui->editBuscar->text().simplified());
    if (DatosBase::resumen(turnos) == DatosBase::resumen(antes))
        return;

    /* Turno elegido en la tabla (DNI y fecha) para volver a marcarlo. */
    QString dniElegido, fechaElegida;
    const int fila = ui->tablaTurnos->currentRow();
    if (fila >= 0 && !ui->tablaTurnos->selectedItems().isEmpty()) {
        dniElegido = ui->tablaTurnos->item(fila, ColDni)->text();
        fechaElegida = ui->tablaTurnos->item(fila, ColFecha)->text();
    }
    mostrarTurnos();
    for (int f = 0; f < ui->tablaTurnos->rowCount(); ++f) {
        if (ui->tablaTurnos->item(f, ColDni)->text() == dniElegido
            && ui->tablaTurnos->item(f, ColFecha)->text() == fechaElegida) {
            ui->tablaTurnos->selectRow(f);
            break;
        }
    }
    turnoElegido();

    /* Los horarios libres cambiaron: se recalculan sin perder el elegido (si sigue libre). */
    const QListWidgetItem *horario = ui->listaHorarios->currentItem();
    const QString horarioElegido = horario && horario->isSelected() ? horario->text() : QString();
    actualizarHorarios();
    Formato::volverAElegir(ui->listaHorarios, horarioElegido);

    DatosBase::cargarAvisos(*repositorio, QDate::currentDate(), ReglasTurno::DIAS_AGENDA, avisos, &error);
    paginaAvisos->recargar();
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

/* Devuelve el id del profesional del horario marcado (guardado en el ítem), o 0 si no hay. */
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
        DatosBase::cargarTurnos(*repositorio, QDate::currentDate(), ReglasTurno::DIAS_AGENDA, turnos, &error);
    }
}

/* La paciente de la carga: si el DNI ya está en la base se usa esa; si no, se la da de alta
 * pidiendo lo que la pantalla no tiene (apellido y fecha de nacimiento). */
bool VentanaGestion::buscarOCrearPaciente(int *idPaciente)
{
    const QString dni = ui->editDni->text().trimmed();
    const Resultado r = repositorio->buscarPaciente(dni);
    if (!r.ok) {   /* si la base falló no se puede asumir que la paciente no existe (se duplicaría el alta) */
        QMessageBox::warning(this, "No se pudo buscar la paciente", r.error);
        return false;
    }
    for (const QVariantMap &fila : r.filas) {   /* el SP también busca por nombre y teléfono: se exige el mismo DNI */
        if (fila.value("dni").toString() == dni) {
            *idPaciente = fila.value("id_paciente").toInt();
            return true;
        }
    }

    const QStringList partes = ui->editPaciente->text().simplified().split(' ');
    const QString nombre = partes.mid(0, qMax(1, partes.size() - 1)).join(' ');
    /* Se vuelve a preguntar hasta que el dato sea válido o se cancele. */
    bool ok = false;
    QString apellido = partes.size() > 1 ? partes.last() : QString();
    for (;;) {
        apellido = QInputDialog::getText(this, "Paciente nueva",
            QString("%1 no está en la base. Apellido:").arg(nombre), QLineEdit::Normal, apellido, &ok);
        if (!ok)
            return false;
        QString errorApellido;
        if (Validaciones::apellidoValido(apellido, &errorApellido))
            break;
        QMessageBox::warning(this, "Apellido incorrecto", errorApellido);
    }
    QDate nacimiento;
    QString textoNacimiento;
    for (;;) {
        textoNacimiento = QInputDialog::getText(this, "Paciente nueva",
            "Fecha de nacimiento (dd/mm/aaaa):", QLineEdit::Normal, textoNacimiento, &ok);
        if (!ok)
            return false;
        QString errorFecha;
        nacimiento = Validaciones::fechaDesdeTexto(textoNacimiento, &errorFecha);
        if (nacimiento.isValid() && Validaciones::fechaNacimientoValida(nacimiento, QDate::currentDate(), &errorFecha))
            break;
        QMessageBox::warning(this, "Fecha inválida", errorFecha);
    }
    const Respuesta alta = repositorio->altaPaciente(dni, nombre, apellido.simplified(), nacimiento, QString(),
                                                     Validaciones::soloDigitos(ui->editTelefono->text()), "gestion", idUsuario);
    if (!alta.ok) {
        QMessageBox::warning(this, "No se pudo dar de alta la paciente", alta.mensaje);
        return false;
    }
    *idPaciente = alta.id;
    return true;
}

/* Carga el turno con los stored procedures: alta del turno y, si se marcó, la seña. */
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
                          .arg(ui->editPaciente->text().simplified(), Formato::fechaLarga(inicio.date()), inicio.toString("HH:mm"));
    if (ui->btnSena->isChecked()) {
        bool ok = false;
        const QString medio = QInputDialog::getItem(this, "Medio de pago", "¿Cómo pagó la seña?",
            { "efectivo", "transferencia", "tarjeta", "tarjeta de regalo" }, 0, false, &ok);
        QString codigoTarjeta;
        while (ok && medio == "tarjeta de regalo") {
            codigoTarjeta = QInputDialog::getText(this, "Tarjeta de regalo", "Código de la tarjeta:", QLineEdit::Normal, codigoTarjeta, &ok);
            QString errorCodigo;
            if (!ok || Validaciones::codigoTarjetaValido(codigoTarjeta, &errorCodigo))
                break;
            QMessageBox::warning(this, "Código incorrecto", errorCodigo);
        }
        if (ok) {
            const Respuesta sena = repositorio->registrarSena(turno.id, medio, codigoTarjeta.trimmed(), "gestion", idUsuario);
            if (sena.ok)
                mensaje += QString("\nPago de la seña aprobado (código %1).").arg(sena.dato);
            else
                mensaje += QString("\nLa seña no se pudo registrar: %1").arg(sena.mensaje);
        } else {
            mensaje += "\nLa seña quedó pendiente de pago.";
        }
    }
    QMessageBox::information(this, "Turno confirmado", mensaje);

    QString error;
    DatosBase::cargarAvisos(*repositorio, QDate::currentDate(), ReglasTurno::DIAS_AGENDA, avisos, &error);
    paginaAvisos->recargar();
    const QString dni = ui->editDni->text().trimmed();
    reiniciarCarga();
    ui->editBuscar->setText(dni);   /* muestra el turno recién cargado */
    buscarTurnos();
    ui->menu->setCurrentRow(MenuBuscarTurnos);
}
