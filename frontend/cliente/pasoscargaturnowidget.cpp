#include "pasoscargaturnowidget.h"
#include "ui_pasoscargaturnowidget.h"
#include "validaciones.h"
#include <QMessageBox>
#include <QRadioButton>
#include <QLabel>
#include <QRegularExpression>
#include <QRegularExpressionValidator>

PasosCargaTurnoWidget::PasosCargaTurnoWidget(QWidget *parent) :
    QWidget(parent),
    ui(new Ui::PasosCargaTurnoWidget)
{
    ui->setupUi(this);

    // Semana 3: máscaras de entrada (solo se pueden tipear los caracteres válidos)
    ui->txtDni->setMaxLength(8);
    ui->txtDni->setValidator(new QRegularExpressionValidator(QRegularExpression("^[0-9]{0,8}$"), this));
    ui->txtTelefono->setMaxLength(14);
    ui->txtTelefono->setValidator(new QRegularExpressionValidator(QRegularExpression("^\\+?[0-9]{0,13}$"), this));
    ui->txtNombre->setMaxLength(60);

    // Inicializar controles de Paso 2
    ui->dateEdit->setDate(QDate::currentDate().addDays(1));
    ui->dateEdit->setMinimumDate(QDate::currentDate());

    ui->comboProf->addItem("Dra. Sofía Martínez");
    ui->comboProf->addItem("Dr. Lucas Benítez");

    inicializarProtocolos();
    inicializarHorarios();

    connect(ui->dateEdit, &QDateEdit::dateChanged, this, [this]() {
        m_hora.clear();
        actualizarDisponibilidad();
    });
    connect(ui->comboProf, &QComboBox::currentTextChanged, this, [this]() {
        m_hora.clear();
        actualizarDisponibilidad();
    });

    ui->stackedPasos->setCurrentIndex(0);
}

PasosCargaTurnoWidget::~PasosCargaTurnoWidget() {
    delete ui;
}

void PasosCargaTurnoWidget::inicializarProtocolos() {
    struct ProtoItem {
        const char* nombre;
        int duracion;
        double precio;
        const char* categoria;
        const char* desc;
    };

    QList<ProtoItem> catalogo = {
        {"Láser Diodo Facial", 45, 22000.0, "Láser", "Depilación médica definitiva con enfriamiento de zafiro para máxima seguridad epidérmica."},
        {"Radiofrecuencia Fraccionada", 60, 28000.0, "Aparatología", "Estimulación profunda de colágeno, tensado dérmico y reducción de líneas de expresión."},
        {"Peeling Químico Médico", 40, 18000.0, "Facial", "Renovación celular con ácidos glicólico y mandélico para manchas, tono y textura dérmica."},
        {"Limpieza Profunda + Hidratación Médica", 50, 16000.0, "Facial", "Higiene facial profunda con espátula ultrasónica, extracciones y máscara bio-hidratante."},
        {"Mesoterapia Facial Rejuvenecedora", 45, 24000.0, "Inyectables", "Microinyecciones de ácido hialurónico no reticulado y vitaminas revitalizantes."},
        {"Dermapen / Microneedling", 50, 20000.0, "Aparatología", "Inducción percutánea de colágeno para poros dilatados, cicatrices y revitalización."}
    };

    // Selección por defecto del primer protocolo
    m_protocoloNombre = catalogo[0].nombre;
    m_protocoloPrecio = catalogo[0].precio;
    m_protocoloDuracion = catalogo[0].duracion;

    for (int i = 0; i < catalogo.size(); ++i) {
        const auto &p = catalogo[i];
        QFrame *card = new QFrame(this);
        card->setStyleSheet("QFrame { background-color: #ffffff; border: 1px solid #dcdcdc; border-radius: 10px; padding: 12px; } "
                            "QFrame:hover { border: 2px solid #8e2a59; }");
        QHBoxLayout *hl = new QHBoxLayout(card);

        QRadioButton *rb = new QRadioButton(card);
        rb->setMinimumHeight(32);
        rb->setStyleSheet("QRadioButton::indicator { width: 22px; height: 22px; }");

        if (i == 0) {
            rb->setChecked(true);
        }

        QString nombre = p.nombre;
        double precio = p.precio;
        int duracion = p.duracion;

        connect(rb, &QRadioButton::toggled, this, [this, nombre, precio, duracion](bool checked){
            if (checked) {
                m_protocoloNombre = nombre;
                m_protocoloPrecio = precio;
                m_protocoloDuracion = duracion;
            }
        });

        QVBoxLayout *vl = new QVBoxLayout();
        QLabel *lblNombre = new QLabel(QString("<b style='font-size:15px;'>%1</b>  <span style='background-color:#fbebf1; color:#8e2a59; padding:2px 6px; border-radius:4px;'>%2</span>")
                                       .arg(p.nombre, p.categoria), card);
        QLabel *lblDesc = new QLabel(p.desc, card);
        lblDesc->setWordWrap(true);
        lblDesc->setStyleSheet("color: #555; font-size: 12px;");

        double senia = precio * 0.30;
        if (senia < 5000.0) senia = 5000.0;

        QLabel *lblDetalles = new QLabel(QString("⏱ Duración: <b>%1 min</b>   |   💰 Precio Total: <b>$%2</b>   |   💳 Seña (30%, mín $5.000): <b style='color:#8e2a59;'>$%3</b>")
                                         .arg(duracion)
                                         .arg(QString::number(precio, 'f', 0))
                                         .arg(QString::number(senia, 'f', 0)), card);
        lblDetalles->setStyleSheet("font-size: 13px;");

        vl->addWidget(lblNombre);
        vl->addWidget(lblDesc);
        vl->addWidget(lblDetalles);

        hl->addWidget(rb);
        hl->addLayout(vl);
        hl->setStretch(1, 1);

        ui->layoutListaProto->addWidget(card);
    }
    ui->layoutListaProto->addStretch();
}

void PasosCargaTurnoWidget::inicializarHorarios() {
    QStringList horariosList = {"09:00", "10:00", "11:00", "12:00", "14:00", "15:00", "16:00", "17:00", "18:00"};

    int row = 0, col = 0;
    for (const QString &slot : horariosList) {
        QPushButton *btn = new QPushButton(slot + " hs", this);
        btn->setMinimumHeight(54); // Botón grande táctil
        btn->setMinimumWidth(130);
        btn->setFont(QFont("Arial", 12, QFont::Bold));

        btn->setStyleSheet("QPushButton { background-color: #ffffff; color: #8e2a59; border: 2px solid #8e2a59; border-radius: 10px; } "
                           "QPushButton:hover { background-color: #fbebf1; }");

        connect(btn, &QPushButton::clicked, this, [this, btn](){
            onHorarioSeleccionado(btn);
        });

        m_botonesHorarios.append(btn);
        ui->gridHorarios->addWidget(btn, row, col);

        col++;
        if (col >= 3) {
            col = 0;
            row++;
        }
    }
}

void PasosCargaTurnoWidget::onHorarioSeleccionado(QPushButton *btn) {
    m_hora = btn->text().replace(" hs", "");
    ui->lblHorarioSeleccionado->setText(QString("<b style='color:#8e2a59; font-size:14px;'>✓ Horario seleccionado: %1 hs</b>").arg(m_hora));

    for (QPushButton *b : m_botonesHorarios) {
        b->setStyleSheet("QPushButton { background-color: #ffffff; color: #8e2a59; border: 2px solid #8e2a59; border-radius: 10px; } "
                         "QPushButton:hover { background-color: #fbebf1; }");
    }
    btn->setStyleSheet("QPushButton { background-color: #8e2a59; color: white; border: 2px solid #8e2a59; border-radius: 10px; }");
}

QString PasosCargaTurnoWidget::claveHorario(const QString &hora) const {
    return ui->dateEdit->date().toString(Qt::ISODate) + "|" +
           ui->comboProf->currentText() + "|" + hora;
}

void PasosCargaTurnoWidget::actualizarDisponibilidad() {
    ui->lblHorarioSeleccionado->setText(
        "<span style='color:#777;'>Por favor seleccioná un horario disponible de la grilla táctil.</span>");

    for (QPushButton *btn : m_botonesHorarios) {
        const QString hora = btn->text().section(' ', 0, 0);
        const bool ocupado = m_horariosReservados.contains(claveHorario(hora));
        btn->setEnabled(!ocupado);
        btn->setText(ocupado ? hora + " hs\nOcupado" : hora + " hs");
        btn->setStyleSheet(ocupado
            ? "QPushButton { background-color: #eeeeee; color: #888888; border: 2px solid #cccccc; border-radius: 10px; }"
            : "QPushButton { background-color: #ffffff; color: #8e2a59; border: 2px solid #8e2a59; border-radius: 10px; } "
              "QPushButton:hover { background-color: #fbebf1; }");
    }
}

void PasosCargaTurnoWidget::setProtocoloSeleccionado(const QString &nombre, double precio, int duracion) {
    m_protocoloNombre = nombre;
    m_protocoloPrecio = precio;
    m_protocoloDuracion = duracion;
    ui->stackedPasos->setCurrentIndex(0);
}

void PasosCargaTurnoWidget::liberarHorario(const QString &fecha, const QString &hora,
                                           const QString &profesional) {
    const QDate fechaTurno = QDate::fromString(fecha, "dd/MM/yyyy");
    const QString clave = fechaTurno.toString(Qt::ISODate) + "|" + profesional + "|" + hora;
    m_horariosReservados.remove(clave);
    actualizarDisponibilidad();
}

void PasosCargaTurnoWidget::reiniciarFormulario() {
    ui->txtNombre->clear();
    ui->txtDni->clear();
    ui->txtTelefono->clear();
    m_hora.clear();
    actualizarDisponibilidad();
    ui->stackedPasos->setCurrentIndex(0);
}

void PasosCargaTurnoWidget::on_btnPaso1Siguiente_clicked() {
    m_pacienteNombre = ui->txtNombre->text().trimmed();
    m_pacienteDni = ui->txtDni->text().trimmed();
    m_pacienteTelefono = ui->txtTelefono->text().trimmed();

    QString error;
    if (!Validaciones::nombreValido(m_pacienteNombre, &error)) {
        QMessageBox::warning(this, "Dato incorrecto: Nombre", error);
        ui->txtNombre->setFocus();
        return;
    }
    if (!Validaciones::dniValido(m_pacienteDni, &error)) {
        QMessageBox::warning(this, "Dato incorrecto: DNI", error);
        ui->txtDni->setFocus();
        return;
    }
    if (!Validaciones::telefonoValido(m_pacienteTelefono, &error)) {
        QMessageBox::warning(this, "Dato incorrecto: Teléfono", error);
        ui->txtTelefono->setFocus();
        return;
    }
    m_pacienteDni = Validaciones::normalizar(m_pacienteDni);
    m_pacienteTelefono = Validaciones::normalizar(m_pacienteTelefono);

    ui->stackedPasos->setCurrentIndex(1); // Paso 2: Horarios
}

void PasosCargaTurnoWidget::on_btnPaso2Volver_clicked() {
    ui->stackedPasos->setCurrentIndex(0); // Volver a Paso 1
}

void PasosCargaTurnoWidget::on_btnPaso2Siguiente_clicked() {
    if (m_hora.isEmpty()) {
        QMessageBox::warning(this, "Horario Requerido", "Por favor tocá un horario disponible en la grilla antes de continuar.");
        return;
    }

    m_fecha = ui->dateEdit->date();
    m_profesional = ui->comboProf->currentText();

    actualizarResumenPaso3();
    ui->stackedPasos->setCurrentIndex(2); // Paso 3: Confirmación y seña
}

void PasosCargaTurnoWidget::on_btnPaso3Volver_clicked() {
    ui->stackedPasos->setCurrentIndex(1); // Volver a Paso 2
}

void PasosCargaTurnoWidget::actualizarResumenPaso3() {
    QString resumen = QString(
        "<table width='100%' cellpadding='6'>"
        "<tr><td width='25%'><b>Paciente:</b></td><td>%1</td><td width='15%'><b>DNI:</b></td><td>%2</td></tr>"
        "<tr><td><b>Teléfono:</b></td><td>%3</td><td><b>Profesional:</b></td><td>%4</td></tr>"
        "<tr><td><b>Protocolo:</b></td><td colspan='3'><b style='color:#8e2a59; font-size:14px;'>%5</b> (Duración: %6 min)</td></tr>"
        "<tr><td><b>Fecha y Hora:</b></td><td colspan='3'><span style='color:#2e7d32; font-size:15px;'><b>%7 a las %8 hs</b></span></td></tr>"
        "<tr><td><b>Precio Total:</b></td><td colspan='3'><b style='font-size:14px;'>$%9</b></td></tr>"
        "</table>"
    ).arg(m_pacienteNombre,
          m_pacienteDni,
          m_pacienteTelefono,
          m_profesional,
          m_protocoloNombre)
     .arg(m_protocoloDuracion)
     .arg(m_fecha.toString("dd/MM/yyyy"))
     .arg(m_hora)
     .arg(QString::number(m_protocoloPrecio, 'f', 0));

    ui->lblResumenTexto->setText(resumen);

    // RF-10: Seña del 30%, mínimo $5.000
    double senia = m_protocoloPrecio * 0.30;
    if (senia < 5000.0) senia = 5000.0;

    ui->lblMontoSenia->setText(QString("<h1 style='color:#8e2a59; margin:4px;'>Monto de Seña: $%1</h1>")
                               .arg(QString::number(senia, 'f', 0)));
}

void PasosCargaTurnoWidget::on_btnPaso3Confirmar_clicked() {
    const double senia = qMax(5000.0, m_protocoloPrecio * 0.30);
    m_horariosReservados.insert(claveHorario(m_hora));
    emit turnoConfirmado(m_pacienteNombre, m_pacienteDni, m_pacienteTelefono,
                         m_protocoloNombre, m_fecha.toString("dd/MM/yyyy"), m_hora,
                         m_profesional, senia);
    ui->stackedPasos->setCurrentIndex(3); // Paso 4: Éxito
}

void PasosCargaTurnoWidget::on_btnNuevoTurno_clicked() {
    reiniciarFormulario();
}
