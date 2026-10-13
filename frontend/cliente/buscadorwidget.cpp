#include "buscadorwidget.h"
#include "ui_buscadorwidget.h"
#include <QLabel>
#include <QPushButton>
#include <QDesktopServices>
#include <QUrl>
#include <QMessageBox>

BuscadorWidget::BuscadorWidget(QWidget *parent) :
    QWidget(parent),
    ui(new Ui::BuscadorWidget)
{
    ui->setupUi(this);

    inicializarCatalogo();
    filtrarResultados("");
}

BuscadorWidget::~BuscadorWidget() {
    delete ui;
}

void BuscadorWidget::inicializarCatalogo() {
    m_catalogo = {
        {"Láser Diodo Facial", 45, 22000.0, "Láser", "Depilación médica definitiva con sistema de enfriamiento de zafiro para máxima seguridad epidérmica."},
        {"Radiofrecuencia Fraccionada", 60, 28000.0, "Aparatología", "Estimulación profunda de colágeno, tensado dérmico y reducción de líneas de expresión."},
        {"Peeling Químico Médico", 40, 18000.0, "Facial", "Renovación celular con ácidos glicólico y mandélico para manchas, tono y textura dérmica."},
        {"Limpieza Profunda + Hidratación Médica", 50, 16000.0, "Facial", "Higiene facial profunda con espátula ultrasónica, extracciones y máscara bio-hidratante."},
        {"Mesoterapia Facial Rejuvenecedora", 45, 24000.0, "Inyectables", "Microinyecciones de ácido hialurónico no reticulado y vitaminas revitalizantes."},
        {"Dermapen / Microneedling", 50, 20000.0, "Aparatología", "Inducción percutánea de colágeno para poros dilatados, cicatrices y revitalización."}
    };
}

void BuscadorWidget::refrescarBusqueda() {
    filtrarResultados(ui->txtBuscar->text());
}

void BuscadorWidget::on_txtBuscar_textChanged(const QString &texto) {
    filtrarResultados(texto);
}

void BuscadorWidget::filtrarResultados(const QString &termino) {
    QLayoutItem *item;
    while ((item = ui->layoutResultados->takeAt(0)) != nullptr) {
        delete item->widget();
        delete item;
    }

    QString t = termino.trimmed().toLower();
    QList<ProtocoloItem> filtrados;

    for (const auto &p : m_catalogo) {
        if (t.isEmpty() || p.nombre.toLower().contains(t) ||
            p.descripcion.toLower().contains(t) ||
            p.categoria.toLower().contains(t)) {
            filtrados.append(p);
        }
    }

    if (filtrados.isEmpty()) {
        ui->frameWhatsApp->setVisible(true); // RF-07 Derivación a WhatsApp
        QLabel *lblSinResultados = new QLabel("<b>No se encontraron protocolos médicos que coincidan con la búsqueda.</b>", this);
        lblSinResultados->setAlignment(Qt::AlignCenter);
        lblSinResultados->setStyleSheet("color: #777; font-size: 14px; margin: 24px;");
        ui->layoutResultados->addWidget(lblSinResultados);
    } else {
        ui->frameWhatsApp->setVisible(false);

        for (const auto &p : filtrados) {
            QFrame *card = new QFrame(this);
            card->setStyleSheet("QFrame { background-color: #ffffff; border: 1px solid #e0e0e0; border-radius: 10px; padding: 14px; } "
                                "QFrame:hover { border: 1px solid #8e2a59; }");
            QVBoxLayout *vl = new QVBoxLayout(card);

            QHBoxLayout *hlHeader = new QHBoxLayout();
            QLabel *lblNombre = new QLabel(QString("<b style='font-size:15px;'>%1</b>").arg(p.nombre), card);
            QLabel *lblCat = new QLabel(QString("<span style='background-color:#fbebf1; color:#8e2a59; font-weight:bold; padding:4px 8px; border-radius:6px;'>%1</span>").arg(p.categoria), card);

            hlHeader->addWidget(lblNombre);
            hlHeader->addStretch();
            hlHeader->addWidget(lblCat);
            vl->addLayout(hlHeader);

            QLabel *lblDesc = new QLabel(p.descripcion, card);
            lblDesc->setWordWrap(true);
            lblDesc->setStyleSheet("color: #444; font-size: 13px; margin-top: 4px; margin-bottom: 6px;");
            vl->addWidget(lblDesc);

            double senia = p.precio * 0.30;
            if (senia < 5000.0) senia = 5000.0;

            QHBoxLayout *hlFooter = new QHBoxLayout();
            QLabel *lblInfo = new QLabel(QString("⏱ Duración: <b>%1 min</b>   |   💰 Precio: <b style='color:#2e7d32; font-size:14px;'>$%2</b>   |   💳 Seña (30%, mín $5.000): <b style='color:#8e2a59;'>$%3</b>")
                                         .arg(p.duracion)
                                         .arg(QString::number(p.precio, 'f', 0))
                                         .arg(QString::number(senia, 'f', 0)), card);
            hlFooter->addWidget(lblInfo);
            hlFooter->addStretch();

            QPushButton *btnSeleccionar = new QPushButton("Seleccionar", card);
            btnSeleccionar->setStyleSheet("QPushButton { background-color: #8e2a59; color: white; font-weight: bold; border-radius: 6px; padding: 6px 14px; } "
                                         "QPushButton:hover { background-color: #6d1f43; }");
            QString nombre = p.nombre;
            double precio = p.precio;
            int duracion = p.duracion;
            connect(btnSeleccionar, &QPushButton::clicked, this, [this, nombre, precio, duracion](){
                emit protocoloSeleccionado(nombre, precio, duracion);
            });
            hlFooter->addWidget(btnSeleccionar);

            vl->addLayout(hlFooter);
            ui->layoutResultados->addWidget(card);
        }
    }
    ui->layoutResultados->addStretch();
}

void BuscadorWidget::on_btnWhatsApp_clicked() {
    QDesktopServices::openUrl(QUrl("https://wa.me/5491123456789"));
    QMessageBox::information(this, "Derivación a WhatsApp (RF-07)",
                             "Se abrió el enlace a wa.me/5491123456789 para resolver la consulta de manera directa.");
}
