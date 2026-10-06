#include "ventanagestion.h"
#include "ui_ventanagestion.h"

#include <QHeaderView>
#include <QMessageBox>
#include <QTextCharFormat>

/* Orden de las páginas dentro del QStackedWidget `paginas` del .ui. */
enum Pagina { PagInicio, PagProtocolo, PagHorario, PagConfirmar, PagBuscador, PagBuscarTurnos };

/* A qué página lleva cada fila del menú lateral. Los pasos 2 y 3 no están
 * en el menú: se llega con "Continuar". */
static const int paginaDeMenu[] = { PagInicio, PagProtocolo, PagBuscador, PagBuscarTurnos };
enum { MenuCargarTurno = 1, MenuBuscarTurnos = 3 };
enum { ColProtocolo = 3 };   /* columna de `tablaTurnos` */

VentanaGestion::VentanaGestion(QWidget *parent)
    : QMainWindow(parent), ui(new Ui::VentanaGestion)
{
    ui->setupUi(this);   /* crea todos los widgets dibujados en el .ui */

    /* Ajustes de aspecto que Qt Designer no deja marcar. */
    ui->tablaAgenda->horizontalHeader()->setSectionResizeMode(QHeaderView::ResizeToContents);
    ui->tablaAgenda->horizontalHeader()->setSectionResizeMode(1, QHeaderView::Stretch);
    ui->tablaTurnos->horizontalHeader()->setSectionResizeMode(QHeaderView::ResizeToContents);
    ui->tablaTurnos->horizontalHeader()->setSectionResizeMode(ColProtocolo, QHeaderView::Stretch);
    /* Sábado y domingo vienen en rojo: los dejamos como el resto. */
    ui->calendario->setWeekdayTextFormat(Qt::Saturday, QTextCharFormat());
    ui->calendario->setWeekdayTextFormat(Qt::Sunday, QTextCharFormat());

    /* Señales y slots: connect(quién avisa, qué pasó, quién reacciona, qué hace). */

    /* Menú lateral y accesos del inicio. */
    connect(ui->menu, &QListWidget::currentRowChanged, this, &VentanaGestion::cambiarSeccion);
    connect(ui->btnIrCargar, &QPushButton::clicked, this, [this] { ui->menu->setCurrentRow(MenuCargarTurno); });
    connect(ui->btnIrBuscar, &QPushButton::clicked, this, [this] { ui->menu->setCurrentRow(MenuBuscarTurnos); });

    /* Los 3 pasos de cargar un turno: Continuar avanza, Volver retrocede. */
    connect(ui->btnContinuar1, &QPushButton::clicked, this, [this] { irA(PagHorario); });
    connect(ui->btnVolver2, &QPushButton::clicked, this, [this] { irA(PagProtocolo); });
    connect(ui->btnContinuar2, &QPushButton::clicked, this, [this] { irA(PagConfirmar); });
    connect(ui->btnVolver3, &QPushButton::clicked, this, [this] { irA(PagHorario); });
    connect(ui->btnConfirmar, &QPushButton::clicked, this, [this] { ui->menu->setCurrentRow(MenuBuscarTurnos); });

    /* El botón de la seña queda apretado (checkable): cambia el texto. */
    connect(ui->btnSena, &QPushButton::toggled, this, [this](bool pagada) {
        ui->btnSena->setText(pagada ? "✓  Seña pagada" : "Marcar seña como pagada");
    });

    connect(ui->btnAyuda, &QPushButton::clicked, this, [this] {
        QMessageBox::information(this, "Ayuda",
            "Cargar turno: paciente y protocolo, después horario, después confirmar.\n"
            "Buscar turnos: por nombre, DNI o teléfono; desde ahí se cancela.");
    });
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
