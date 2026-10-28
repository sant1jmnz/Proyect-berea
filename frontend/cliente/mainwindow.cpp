#include "mainwindow.h"
#include "ui_mainwindow.h"
#include "pasoscargaturnowidget.h"
#include "buscadorwidget.h"
#include "buscarturnowidget.h"
#include "avisoconexion.h"
#include "conexionapp.h"
#include <QMessageBox>
#include <QTimer>

MainWindow::MainWindow(QWidget *parent) :
    QMainWindow(parent),
    ui(new Ui::MainWindow)
{
    ui->setupUi(this);

    // Dimensiones mínimas requeridas para terminal táctil vertical (RNF-07: 768×1024 mín.)
    configurarVentanaVertical();

    // Instanciar los widgets modulares de la interfaz
    m_pasosCargaWidget = new PasosCargaTurnoWidget(this);
    m_buscadorWidget = new BuscadorWidget(this);
    m_buscarTurnoWidget = new BuscarTurnoWidget(this);

    // Agregar las pantallas al QStackedWidget central
    ui->stackedCentral->addWidget(m_pasosCargaWidget);  // Pantallas 1, 2, 3 (Carga de turno)
    ui->stackedCentral->addWidget(m_buscadorWidget);    // Pantalla 4 (Buscador compartido)
    ui->stackedCentral->addWidget(m_buscarTurnoWidget);  // Pantalla 5 (Buscar mi turno)

    // Conectar señales y slots entre pantallas
    connect(m_buscadorWidget, &BuscadorWidget::protocoloSeleccionado,
            this, &MainWindow::onProtocoloSeleccionadoEnBuscador);

    connect(m_pasosCargaWidget, &PasosCargaTurnoWidget::turnoConfirmado,
            m_buscarTurnoWidget, &BuscarTurnoWidget::agregarTurnoDesdeFormulario);
    connect(m_buscarTurnoWidget, &BuscarTurnoWidget::turnoCancelado,
            m_pasosCargaWidget, &PasosCargaTurnoWidget::liberarHorario);

    // Aviso cuando la base no responde y modo contingencia (RNF-09): sin base, los turnos
    // confirmados se guardan en este equipo y se envían cuando vuelva la conexión.
    m_aviso = new AvisoConexion(this);
    ui->mainVerticalLayout->insertWidget(1, m_aviso);   // debajo del encabezado
    m_conexion = new ConexionApp(m_aviso, ConfigBD::desdeEntorno(), QString(), this);
    QTimer::singleShot(0, m_conexion, &ConexionApp::probar);
    connect(m_pasosCargaWidget, &PasosCargaTurnoWidget::turnoConfirmado, this,
            [this](const QString &paciente, const QString &dni, const QString &telefono,
                   const QString &protocolo, const QString &fecha, const QString &hora,
                   const QString &, double senia) {
                if (m_conexion->hayConexion())
                    return;
                TurnoPendiente t;
                t.paciente = paciente;
                t.dni = dni;
                t.telefono = telefono;
                t.protocolo = protocolo;
                t.inicio = QDateTime(QDate::fromString(fecha, "dd/MM/yyyy"), QTime::fromString(hora, "HH:mm"));
                t.sena = qRound(senia);
                t.senaPagada = true;    // en la terminal la seña se paga (simulada) al confirmar
                t.origen = "Terminal";
                m_conexion->guardarEnContingencia(t);
            });

    // Inicializar en la pantalla 1
    actualizarEstadoBotonesNav(0);
}

MainWindow::~MainWindow() {
    delete ui;
}

void MainWindow::configurarVentanaVertical() {
    setMinimumSize(768, 1024);
    resize(768, 1024);

    ui->frameHeader->setStyleSheet("QFrame#frameHeader { background-color: #ffffff; border: 1px solid #e0e0e0; border-radius: 12px; }");
    ui->frameNav->setStyleSheet("QFrame#frameNav { background-color: #ffffff; border: 1px solid #e0e0e0; border-radius: 12px; }");
}

void MainWindow::actualizarEstadoBotonesNav(int index) {
    ui->stackedCentral->setCurrentIndex(index);

    QString estiloActivo = "QPushButton { background-color: #8e2a59; color: white; border-radius: 10px; font-weight: bold; }";
    QString estiloInactivo = "QPushButton { background-color: #ffffff; color: #555; border: 1px solid #ccc; border-radius: 10px; font-weight: bold; } "
                             "QPushButton:hover { background-color: #fbebf1; color: #8e2a59; }";

    ui->btnNavCargarTurno->setStyleSheet(index == 0 ? estiloActivo : estiloInactivo);
    ui->btnNavBuscador->setStyleSheet(index == 1 ? estiloActivo : estiloInactivo);
    ui->btnNavBuscarTurno->setStyleSheet(index == 2 ? estiloActivo : estiloInactivo);
}

void MainWindow::on_btnNavCargarTurno_clicked() {
    actualizarEstadoBotonesNav(0);
}

void MainWindow::on_btnNavBuscador_clicked() {
    actualizarEstadoBotonesNav(1);
    m_buscadorWidget->refrescarBusqueda();
}

void MainWindow::on_btnNavBuscarTurno_clicked() {
    actualizarEstadoBotonesNav(2);
}

void MainWindow::onProtocoloSeleccionadoEnBuscador(const QString &nombre, double precio, int duracion) {
    m_pasosCargaWidget->setProtocoloSeleccionado(nombre, precio, duracion);
    actualizarEstadoBotonesNav(0);
    QMessageBox::information(this, "Protocolo Seleccionado",
                             QString("Seleccionaste: <b>%1</b>.<br/>Completá tus datos en el formulario para avanzar al Paso 2.").arg(nombre));
}

void MainWindow::on_btnInfoSemana1_clicked() {
    QMessageBox::information(this, "Semana 1 - Entregable Bautista",
        "<h3>Entregables Cumplidos - Bautista (Semana 1: GUI en Qt):</h3>"
        "<ul>"
        "<li><b>Ventana Principal de Cliente:</b> Formato terminal vertical de 768×1024 px mínimos (RNF-07).</li>"
        "<li><b>Pantallas Cliente 1-3:</b> Carga de turno en 3 pasos: Elegir protocolo (RF-01), Elegir horario disponible (RF-01, RF-04), Confirmar y pagar seña simulada (RF-01, RF-08, RF-10 con cálculo de 30% mín $5.000).</li>"
        "<li><b>Señales y Slots:</b> Navegación completa entre pasos 1-2-3 con botones grandes táctiles.</li>"
        "<li><b>Widget Compartido de Buscador:</b> Buscador de precios y protocolos médicos (RF-05, RF-06) con derivación a WhatsApp (RF-07). Listo para que Santiago lo reutilice en Gestión 4.</li>"
        "<li><b>Pantalla Cliente 5:</b> Buscar mi turno por DNI o Teléfono (RF-12), con recordatorio visible en el sistema (RF-11) y botón de cancelación con regla de reembolso de 24 horas (RF-10).</li>"
        "</ul>");
}
