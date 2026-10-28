#include "paginaavisos.h"

#include <QApplication>
#include <QClipboard>
#include <QDesktopServices>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QInputDialog>
#include <QLabel>
#include <QMessageBox>
#include <QPushButton>
#include <QTableWidget>
#include <QUrl>
#include <QVBoxLayout>

enum { ColPaciente, ColCanal, ColEstado, ColTurno, ColProgramado, ColEnviado };

PaginaAvisos::PaginaAvisos(RegistroAvisos *registro, QWidget *parent)
    : QWidget(parent), avisos(registro)
{
    auto *raiz = new QVBoxLayout(this);
    raiz->setContentsMargins(28, 24, 28, 24);
    raiz->setSpacing(14);

    auto *titulo = new QLabel("Avisos de turno");
    titulo->setProperty("rol", "titulo");
    auto *subtitulo = new QLabel("Cada turno cargado programa un recordatorio 24 horas antes (RF-11). "
                                 "Sin Telegram vinculado, la recepción lo envía por WhatsApp asistido.");
    subtitulo->setProperty("rol", "subtitulo");
    subtitulo->setWordWrap(true);
    raiz->addWidget(titulo);
    raiz->addWidget(subtitulo);

    tabla = new QTableWidget(0, 6);
    tabla->setObjectName("tablaAvisos");
    tabla->setHorizontalHeaderLabels({ "PACIENTE", "CANAL", "ESTADO", "TURNO", "PROGRAMADO", "ENVIADO" });
    tabla->setSelectionBehavior(QAbstractItemView::SelectRows);
    tabla->setSelectionMode(QAbstractItemView::SingleSelection);
    tabla->setEditTriggers(QAbstractItemView::NoEditTriggers);
    tabla->setAlternatingRowColors(true);
    tabla->verticalHeader()->hide();
    tabla->horizontalHeader()->setSectionResizeMode(QHeaderView::Stretch);
    raiz->addWidget(tabla, 1);

    auto *fila = new QHBoxLayout;
    lblCuenta = new QLabel;
    lblCuenta->setProperty("rol", "nota");
    btnWhatsApp = new QPushButton("Abrir WhatsApp con el mensaje");
    btnWhatsApp->setProperty("primario", true);
    btnFallido = new QPushButton("Marcar como fallido");
    btnFallido->setProperty("peligro", true);
    fila->addWidget(lblCuenta, 1);
    fila->addWidget(btnFallido);
    fila->addWidget(btnWhatsApp);
    raiz->addLayout(fila);

    connect(btnWhatsApp, &QPushButton::clicked, this, &PaginaAvisos::abrirWhatsApp);
    connect(btnFallido, &QPushButton::clicked, this, &PaginaAvisos::marcarFallido);
    connect(tabla, &QTableWidget::itemSelectionChanged, this, &PaginaAvisos::actualizarBotones);
    recargar();
}

void PaginaAvisos::recargar()
{
    const QVector<Aviso> &lista = avisos->todos();
    tabla->clearContents();
    tabla->setRowCount(lista.size());
    int pendientes = 0;
    for (int i = 0; i < lista.size(); ++i) {
        const Aviso &a = lista[i];
        const QString columnas[] = {
            a.paciente, Recordatorios::nombre(a.canal),
            a.estado == EstadoAviso::Fallido && !a.detalleError.isEmpty()
                ? Recordatorios::nombre(a.estado) + " (" + a.detalleError + ")" : Recordatorios::nombre(a.estado),
            a.inicioTurno.toString("dd/MM/yy HH:mm"), a.programado.toString("dd/MM/yy HH:mm"),
            a.enviado.isValid() ? a.enviado.toString("dd/MM/yy HH:mm") : QString("—") };
        for (int col = ColPaciente; col <= ColEnviado; ++col)
            tabla->setItem(i, col, new QTableWidgetItem(columnas[col]));
        if (a.estado == EstadoAviso::Pendiente)
            ++pendientes;
    }
    lblCuenta->setText(QString("%1 avisos · %2 pendientes").arg(lista.size()).arg(pendientes));
    actualizarBotones();
}

void PaginaAvisos::actualizarBotones()
{
    const int fila = tabla->currentRow();
    const bool hay = fila >= 0 && fila < avisos->todos().size() && !tabla->selectedItems().isEmpty();
    const bool pendiente = hay && avisos->todos()[fila].estado != EstadoAviso::Enviado;
    btnWhatsApp->setEnabled(pendiente);
    btnFallido->setEnabled(pendiente);
}

void PaginaAvisos::abrirWhatsApp()
{
    const int fila = tabla->currentRow();
    if (fila < 0 || fila >= avisos->todos().size())
        return;
    const Aviso &a = avisos->todos()[fila];
    const QString enlace = Recordatorios::enlaceWhatsApp(a.telefono, a.mensaje);
    QApplication::clipboard()->setText(enlace);   /* por si no hay navegador configurado */
    QDesktopServices::openUrl(QUrl(enlace));
    const auto r = QMessageBox::question(this, "¿Se envió?",
        "Se abrió WhatsApp con el mensaje (el enlace también quedó copiado).\n¿Lo enviaste?");
    if (r == QMessageBox::Yes)
        avisos->marcarEnviado(fila, QDateTime::currentDateTime());
    recargar();
    tabla->selectRow(fila);
}

void PaginaAvisos::marcarFallido()
{
    const int fila = tabla->currentRow();
    if (fila < 0 || fila >= avisos->todos().size())
        return;
    bool ok = false;
    const QString motivo = QInputDialog::getText(this, "Aviso fallido", "¿Qué pasó?", QLineEdit::Normal,
                                                 "La paciente no tiene WhatsApp", &ok);
    if (!ok)
        return;
    avisos->marcarFallido(fila, motivo.simplified());
    recargar();
    tabla->selectRow(fila);
}
