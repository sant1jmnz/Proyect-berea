#include "ventanacliente.h"
#include "ui_ventanacliente.h"

#include <QGraphicsDropShadowEffect>
#include <QMessageBox>
#include <QTextCharFormat>

/* Orden de las páginas dentro del QStackedWidget `paginas` del .ui. */
enum Pagina { PagInicio, PagProtocolo, PagHorario, PagConfirmar, PagBuscador, PagMiTurno };

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
    connect(ui->btnContinuar1, &QPushButton::clicked, this, [this] { irA(PagHorario); });
    connect(ui->btnVolver2, &QPushButton::clicked, this, [this] { irA(PagProtocolo); });
    connect(ui->btnContinuar2, &QPushButton::clicked, this, [this] { irA(PagConfirmar); });
    connect(ui->btnVolver3, &QPushButton::clicked, this, [this] { irA(PagHorario); });
    connect(ui->btnConfirmar, &QPushButton::clicked, this, [this] {
        QMessageBox::information(this, "Turno confirmado",
            "¡Listo! Tu turno quedó reservado.\njueves 8 de octubre, 09:00");
        irA(PagMiTurno);
    });

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
