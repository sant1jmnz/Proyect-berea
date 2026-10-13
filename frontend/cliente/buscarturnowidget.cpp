#include "buscarturnowidget.h"
#include "ui_buscarturnowidget.h"
#include "validaciones.h"
#include <QLabel>
#include <QPushButton>
#include <QMessageBox>
#include <QDate>
#include <QRegularExpression>
#include <QRegularExpressionValidator>

BuscarTurnoWidget::BuscarTurnoWidget(QWidget *parent) :
    QWidget(parent),
    ui(new Ui::BuscarTurnoWidget)
{
    ui->setupUi(this);

    // Semana 3: solo dígitos (y un + inicial para teléfonos con código de país)
    ui->txtDniTel->setMaxLength(14);
    ui->txtDniTel->setValidator(new QRegularExpressionValidator(QRegularExpression("^\\+?[0-9]{0,13}$"), this));

    inicializarTurnos();
}

BuscarTurnoWidget::~BuscarTurnoWidget() {
    delete ui;
}

void BuscarTurnoWidget::inicializarTurnos() {
    QDate fechaFutura = QDate::currentDate().addDays(3);
    m_turnos.append({
        "Luciana Gómez", "38123456", "1155443322",
        "Láser Diodo Facial", fechaFutura.toString("dd/MM/yyyy"), "10:00",
        "Dra. Sofía Martínez", 6600.0, "Pagada", "Confirmado"
    });

    QDate fechaManiana = QDate::currentDate().addDays(1);
    m_turnos.append({
        "Mariana Fernández", "40987654", "1144332211",
        "Peeling Químico Médico", fechaManiana.toString("dd/MM/yyyy"), "15:00",
        "Dr. Lucas Benítez", 5400.0, "Pagada", "Confirmado"
    });
}

void BuscarTurnoWidget::agregarTurnoDesdeFormulario(const QString &paciente, const QString &dni,
                                                     const QString &telefono, const QString &protocolo,
                                                     const QString &fecha, const QString &hora,
                                                     const QString &profesional, double senia) {
    m_turnos.prepend({
        paciente, dni, telefono, protocolo, fecha, hora,
        profesional, senia, "Pagada", "Confirmado"
    });
}

void BuscarTurnoWidget::on_btnBuscar_clicked() {
    const QString criterio = ui->txtDniTel->text().trimmed();
    if (!criterio.isEmpty()) {
        QString errorDni, errorTel;
        if (!Validaciones::dniValido(criterio, &errorDni) && !Validaciones::telefonoValido(criterio, &errorTel)) {
            QMessageBox::warning(this, "Dato incorrecto",
                                 "Ingresá un DNI (7 u 8 dígitos) o un teléfono (10 a 13 dígitos), solo números.");
            ui->txtDniTel->setFocus();
            return;
        }
    }
    mostrarResultados(criterio);
}

void BuscarTurnoWidget::on_txtDniTel_returnPressed() {
    on_btnBuscar_clicked();
}

void BuscarTurnoWidget::mostrarResultados(const QString &criterio) {
    QLayoutItem *item;
    while ((item = ui->layoutTurnos->takeAt(0)) != nullptr) {
        delete item->widget();
        delete item;
    }

    if (criterio.isEmpty()) {
        QLabel *lblVacio = new QLabel("Ingresá tu DNI o Teléfono en el campo de arriba y presioná 'Buscar mi Turno'.", this);
        lblVacio->setAlignment(Qt::AlignCenter);
        lblVacio->setStyleSheet("color: #777; font-size: 14px; margin: 30px;");
        ui->layoutTurnos->addWidget(lblVacio);
        ui->layoutTurnos->addStretch();
        return;
    }

    QList<int> encontrados;
    for (int indice = 0; indice < m_turnos.size(); ++indice) {
        const auto &t = m_turnos.at(indice);
        const QString buscado = Validaciones::normalizar(criterio);
        if (t.dni == buscado || t.telefono == buscado) {
            encontrados.append(indice);
        }
    }

    if (encontrados.isEmpty()) {
        QLabel *lblNo = new QLabel(QString("No se encontraron turnos agendados para '%1'.").arg(criterio), this);
        lblNo->setAlignment(Qt::AlignCenter);
        lblNo->setStyleSheet("color: #777; font-size: 14px; margin: 30px;");
        ui->layoutTurnos->addWidget(lblNo);
    } else {
        for (const int indice : encontrados) {
            const auto &t = m_turnos.at(indice);
            QFrame *card = new QFrame(this);
            card->setStyleSheet("QFrame { background-color: #ffffff; border: 1px solid #dcdcdc; border-radius: 12px; padding: 14px; } "
                                "QFrame:hover { border: 1px solid #8e2a59; }");
            QVBoxLayout *vl = new QVBoxLayout(card);

            // Cabecera: Protocolo y badge de estado
            QHBoxLayout *hlHeader = new QHBoxLayout();
            QLabel *lblProto = new QLabel(QString("<b style='font-size:16px; color:#8e2a59;'>%1</b>").arg(t.protocolo), card);

            QLabel *lblEstadoBadge = new QLabel(QString(" %1 ").arg(t.estado), card);
            if (t.estado == "Confirmado") {
                lblEstadoBadge->setStyleSheet("background-color: #2e7d32; color: white; border-radius: 6px; font-weight: bold; padding: 4px 10px; font-size: 12px;");
            } else {
                lblEstadoBadge->setStyleSheet("background-color: #c62828; color: white; border-radius: 6px; font-weight: bold; padding: 4px 10px; font-size: 12px;");
            }

            hlHeader->addWidget(lblProto);
            hlHeader->addStretch();
            hlHeader->addWidget(lblEstadoBadge);
            vl->addLayout(hlHeader);

            // Detalles del paciente y turno
            QLabel *lblDetalles = new QLabel(QString("👤 <b>Paciente:</b> %1 (DNI: %2, Tel: %3)<br/>"
                                                     "📅 <b>Fecha y Hora:</b> <span style='font-size:14px; color:#333;'><b>%4 a las %5 hs</b></span><br/>"
                                                     "🩺 <b>Profesional:</b> %6<br/>"
                                                     "💳 <b>Seña abonada:</b> $%7 (Estado: <b>%8</b>)")
                                             .arg(t.paciente, t.dni, t.telefono)
                                             .arg(t.fecha, t.hora)
                                             .arg(t.profesional)
                                             .arg(QString::number(t.seniaMonto, 'f', 0))
                                             .arg(t.seniaEstado), card);
            lblDetalles->setTextFormat(Qt::RichText);
            lblDetalles->setStyleSheet("font-size: 13px; line-height: 1.4;");
            vl->addWidget(lblDetalles);

            // Recordatorio de turno (RF-11)
            QFrame *cardRec = new QFrame(card);
            cardRec->setStyleSheet("background-color: #f1f8e9; border: 1px solid #c5e1a5; border-radius: 8px; padding: 8px; margin-top: 6px;");
            QVBoxLayout *vlRec = new QVBoxLayout(cardRec);
            QLabel *lblRec = new QLabel(QString("🔔 <b>Recordatorio activo en sistema (RF-11):</b><br/>"
                                                "Te esperamos el día %1 a las %2 hs en Av. Rivadavia 6500, Flores, CABA. "
                                                "Protocolo: %3 con %4.")
                                        .arg(t.fecha, t.hora, t.protocolo, t.profesional), cardRec);
            lblRec->setWordWrap(true);
            lblRec->setStyleSheet("color: #2e5b1e; font-size: 12px;");
            vlRec->addWidget(lblRec);
            vl->addWidget(cardRec);

            // Botón de cancelación con validación de 24 horas (RF-12, RF-10)
            if (t.estado != "Cancelado") {
                QHBoxLayout *hlBtn = new QHBoxLayout();
                hlBtn->addStretch();

                QPushButton *btnCancel = new QPushButton("❌ Cancelar Turno (RF-12)", card);
                btnCancel->setProperty("turnoIndex", indice);
                btnCancel->setMinimumHeight(40);
                btnCancel->setStyleSheet("QPushButton { background-color: #ffffff; color: #c62828; border: 2px solid #c62828; border-radius: 8px; font-weight: bold; padding: 6px 16px; } "
                                         "QPushButton:hover { background-color: #ffebee; }");

                connect(btnCancel, &QPushButton::clicked, this, &BuscarTurnoWidget::onCancelarTurno);

                hlBtn->addWidget(btnCancel);
                vl->addLayout(hlBtn);
            }

            ui->layoutTurnos->addWidget(card);
        }
    }
    ui->layoutTurnos->addStretch();
}

void BuscarTurnoWidget::onCancelarTurno() {
    const auto *boton = qobject_cast<QPushButton *>(sender());
    const int indice = boton ? boton->property("turnoIndex").toInt() : -1;
    if (indice < 0 || indice >= m_turnos.size()) {
        return;
    }

    auto reply = QMessageBox::question(this, "Confirmar Cancelación",
                                       "¿Deseás cancelar este turno?\n\n"
                                       "Política de cancelación de Dermalia (RF-10):\n"
                                       "• Más de 24 hs antes del turno: 100% de reembolso de la seña.\n"
                                       "• Menos de 24 hs antes del turno: la seña no se reembolsa.\n\n"
                                       "¿Confirmás la cancelación?",
                                       QMessageBox::Yes | QMessageBox::No);

    if (reply == QMessageBox::Yes) {
        TurnoItem &turno = m_turnos[indice];
        const QDate fecha = QDate::fromString(turno.fecha, "dd/MM/yyyy");
        const QTime hora = QTime::fromString(turno.hora, "HH:mm");
        const bool reembolsable = QDateTime::currentDateTime().secsTo(QDateTime(fecha, hora)) > 24 * 60 * 60;
        turno.estado = "Cancelado";
        turno.seniaEstado = reembolsable ? "Reembolsada (100%)" : "Sin reembolso (< 24 hs)";
        emit turnoCancelado(turno.fecha, turno.hora, turno.profesional);
        QMessageBox::information(this, "Turno Cancelado",
                                 reembolsable
                                     ? "Turno cancelado exitosamente.\nPor cancelarse con más de 24 hs de anticipación, aplica reembolso del 100% de la seña (RF-10)."
                                     : "Turno cancelado exitosamente.\nQuedan menos de 24 hs para el turno: la seña no se reembolsa (RF-10).");
        mostrarResultados(ui->txtDniTel->text().trimmed());
    }
}
