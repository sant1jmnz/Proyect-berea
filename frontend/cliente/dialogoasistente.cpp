#include "dialogoasistente.h"

#include "basedatos.h"

#include <QAudioInput>
#include <QDir>
#include <QFile>
#include <QMediaCaptureSession>
#include <QMediaFormat>
#include <QMediaRecorder>
#include <QTimer>
#include <QGridLayout>
#include <QHBoxLayout>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDialog>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QLabel>
#include <QLocale>
#include <QLineEdit>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPushButton>
#include <QScrollBar>
#include <QSettings>
#include <QTextBrowser>
#include <QUrl>
#include <QVBoxLayout>

namespace {
const QStringList SUGERENCIAS = {
    "¿Cuánto sale el peeling?",
    "¿Cómo cancelo un turno?",
    "¿Cómo funcionan las cirugías?",
    "¿Tienen algo para la celulitis?",
};
const QString SALUDO = "¡Hola! Soy el asistente de Dermalia. Preguntame por precios, duración de un protocolo, "
                       "la seña, cómo cancelar o cómo funcionan las cirugías.";
}

// Dirección de la API: variable DERMALIA_API_URL, si no el archivo ini, si no localhost:3000. Sin barra final.
QString DialogoAsistente::urlPorDefecto(const QString &nombreIni)
{
    const QString archivoIni = ConfigBD::rutaIni(nombreIni);
    QString valor = qEnvironmentVariable("DERMALIA_API_URL");
    if (valor.isEmpty() && QFile::exists(archivoIni))
        valor = QSettings(archivoIni, QSettings::IniFormat).value("asistente/url").toString();
    if (valor.isEmpty())
        valor = "http://127.0.0.1:3000";
    while (valor.endsWith('/'))
        valor.chop(1);
    return valor;
}

// Arma el chat del asistente: conversación, sugerencias, caja de texto y botón de voz.
DialogoAsistente::DialogoAsistente(QWidget *parent, const QString &urlApi)
    : QDialog(parent), url(urlApi.isEmpty() ? urlPorDefecto() : urlApi)
{
    setObjectName("dialogoAsistente");
    setWindowTitle("Asistente Dermalia");
    setModal(true);
    resize(680, 860);
    setStyleSheet(
        "QDialog#dialogoAsistente { background: #FCF8F2; }"
        "QLabel#tituloAsistente { font-family: 'Playfair Display'; font-size: 28px; color: #3A2B2B; }"
        "QLabel#subAsistente { font-size: 16px; color: #7A6A64; }"
        "QTextBrowser { background: #FFFDFA; border: 1px solid #F0E7DC; border-radius: 16px; padding: 10px; font-size: 18px; }"
        "QPushButton[sugerencia=\"true\"] { background: #FBF3E6; color: #8A6A3B; border: 1px solid #E5D2B0;"
        "  border-radius: 22px; padding: 12px 16px; font-size: 16px; }"
        "QLineEdit { background: white; border: 1px solid #E8DCCF; border-radius: 26px; padding: 0 18px;"
        "  min-height: 52px; font-size: 18px; color: #3A2B2B; }"
        "QPushButton#btnEnviarAsistente, QPushButton#btnCerrarAsistente { min-height: 52px; border-radius: 26px;"
        "  padding: 0 24px; font-size: 17px; font-weight: bold; }"
        "QPushButton#btnEnviarAsistente { background: #A8475F; color: white; border: 0; }"
        "QPushButton#btnEnviarAsistente:disabled { background: #D9A9B5; }"
        "QPushButton#btnVozAsistente { min-height: 52px; border-radius: 26px; padding: 0 20px; font-size: 17px;"
        "  font-weight: bold; background: #E8DCCF; color: #3A2B2B; border: 0; }"
        "QPushButton#btnVozAsistente:checked { background: #C62F3A; color: white; }"
        "QPushButton#btnCerrarAsistente { background: transparent; color: #3A2B2B; border: 1px solid #E8DCCF; }"
        "QLabel#avisoAsistente { color: #A89C95; font-size: 13px; }");

    auto *titulo = new QLabel("Preguntale al asistente");
    titulo->setObjectName("tituloAsistente");
    auto *sub = new QLabel("Responde con los precios y las reglas del instituto. Si no sabe, te deriva a la recepción.");
    sub->setObjectName("subAsistente");
    sub->setWordWrap(true);

    conversacion = new QTextBrowser;
    conversacion->setOpenExternalLinks(false);
    conversacion->setFocusPolicy(Qt::NoFocus);

    sugerencias = new QWidget;
    auto *grilla = new QGridLayout(sugerencias);
    grilla->setContentsMargins(0, 0, 0, 0);
    grilla->setSpacing(10);
    for (int i = 0; i < SUGERENCIAS.size(); ++i) {
        auto *b = new QPushButton(SUGERENCIAS[i]);
        b->setProperty("sugerencia", true);
        b->setCursor(Qt::PointingHandCursor);
        connect(b, &QPushButton::clicked, this, [this, texto = SUGERENCIAS[i]] { preguntar(texto); });
        grilla->addWidget(b, i / 2, i % 2);
    }

    campo = new QLineEdit;
    campo->setObjectName("campoAsistente");
    campo->setPlaceholderText("Escribí tu pregunta…");
    campo->setMaxLength(500);
    btnEnviar = new QPushButton("Enviar");
    btnEnviar->setObjectName("btnEnviarAsistente");
    btnEnviar->setCursor(Qt::PointingHandCursor);
    auto *fila = new QHBoxLayout;
    btnVoz = new QPushButton("Voz");
    btnVoz->setObjectName("btnVozAsistente");
    btnVoz->setCheckable(true);
    btnVoz->setCursor(Qt::PointingHandCursor);
    btnVoz->setToolTip("Tocá para grabar una nota de voz y tocá de nuevo para mandarla (hasta 2 minutos).");
    fila->addWidget(campo, 1);
    fila->addWidget(btnVoz);
    fila->addWidget(btnEnviar);

    auto *aviso = new QLabel("No escribas tu DNI, teléfono ni email: no hacen falta, y si los escribís se borran.");
    aviso->setObjectName("avisoAsistente");
    aviso->setWordWrap(true);

    auto *btnCerrar = new QPushButton("Volver");
    btnCerrar->setObjectName("btnCerrarAsistente");
    btnCerrar->setCursor(Qt::PointingHandCursor);
    connect(btnCerrar, &QPushButton::clicked, this, &QDialog::accept);

    auto *columna = new QVBoxLayout(this);
    columna->setContentsMargins(28, 28, 28, 24);
    columna->setSpacing(14);
    columna->addWidget(titulo);
    columna->addWidget(sub);
    columna->addWidget(conversacion, 1);
    columna->addWidget(sugerencias);
    columna->addLayout(fila);
    columna->addWidget(aviso);
    columna->addWidget(btnCerrar, 0, Qt::AlignLeft);

    auto enviar = [this] {
        const QString texto = campo->text().trimmed();
        if (texto.isEmpty() || enCurso)
            return;
        campo->clear();
        preguntar(texto);
    };
    connect(btnEnviar, &QPushButton::clicked, this, enviar);
    connect(campo, &QLineEdit::returnPressed, this, enviar);

    red = new QNetworkAccessManager(this);

    // nota de voz: graba del micrófono a un WAV temporal (16 kHz mono, liviano para mandar)
    auto *sesion = new QMediaCaptureSession(this);
    sesion->setAudioInput(new QAudioInput(this));
    grabador = new QMediaRecorder(this);
    sesion->setRecorder(grabador);
    QMediaFormat formato(QMediaFormat::Wave);
    formato.setAudioCodec(QMediaFormat::AudioCodec::Wave);
    grabador->setMediaFormat(formato);
    grabador->setAudioSampleRate(16000);
    grabador->setAudioChannelCount(1);
    archivoAudio = QDir::temp().filePath("dermalia-nota-de-voz.wav");
    grabador->setOutputLocation(QUrl::fromLocalFile(archivoAudio));
    corte = new QTimer(this);
    corte->setSingleShot(true);
    corte->setInterval(120000);   // máximo 2 minutos, como en Telegram y en el sitio
    connect(corte, &QTimer::timeout, this, [this] { if (btnVoz->isChecked()) btnVoz->click(); });
    connect(btnVoz, &QPushButton::clicked, this, &DialogoAsistente::alternarGrabacion);
    connect(grabador, &QMediaRecorder::recorderStateChanged, this, [this](QMediaRecorder::RecorderState estado) {
        if (estado != QMediaRecorder::StoppedState || btnVoz->isChecked())
            return;
        QFile f(grabador->actualLocation().toLocalFile());
        if (f.open(QIODevice::ReadOnly) && f.size() > 1000)
            preguntarConAudio(f.readAll(), "audio/wav");
        f.close();
        f.remove();
    });
    connect(grabador, &QMediaRecorder::errorOccurred, this, [this](QMediaRecorder::Error, const QString &) {
        btnVoz->setChecked(false);
        btnVoz->setText("Voz");
        agregar("asistente", "No pude usar el micrófono. Revisá que esté conectado o escribime.");
    });

    agregar("asistente", SALUDO.toHtmlEscaped());
}

// Suma una burbuja al chat (la paciente a la derecha, el asistente a la izquierda) y la muestra.
void DialogoAsistente::agregar(const QString &rol, const QString &html)
{
    const bool paciente = rol == "paciente";
    mensajesHtml << QString(
        "<table width='100%' cellspacing='0' cellpadding='0' style='margin: 6px 0;'><tr><td align='%1'>"
        "<table cellpadding='12' style='background: %2; color: %3; border-radius: 14px;'><tr><td>%4</td></tr></table>"
        "</td></tr></table>")
        .arg(paciente ? "right" : "left", paciente ? "#A8475F" : "#F5ECE6", paciente ? "#FFFFFF" : "#3A2B2B", html);
    pintar();
}

// Redibuja la conversación y baja hasta el último mensaje.
void DialogoAsistente::pintar()
{
    conversacion->setHtml(mensajesHtml.join(QString()));
    conversacion->verticalScrollBar()->setValue(conversacion->verticalScrollBar()->maximum());
}

// Reemplaza el aviso 'Escribiendo…' por la respuesta y deja volver a escribir.
void DialogoAsistente::terminar(const QString &html)
{
    mensajesHtml.removeLast();   /* el "Escribiendo…" */
    agregar("asistente", html);
    enCurso = false;
    btnEnviar->setEnabled(true);
    btnVoz->setEnabled(true);
    emit respondio();
}

// Empieza a grabar la nota de voz o la corta para mandarla; no graba si hay una respuesta en curso.
void DialogoAsistente::alternarGrabacion()
{
    if (btnVoz->isChecked()) {
        if (enCurso) {
            btnVoz->setChecked(false);
            return;
        }
        btnVoz->setText("Mandar");
        grabador->record();
        corte->start();
    } else {
        btnVoz->setText("Voz");
        corte->stop();
        grabador->stop();   // al terminar de escribir el archivo, recorderStateChanged lo manda
    }
}

// Manda una pregunta escrita (con la elección de un botón, si la hay) a la API.
void DialogoAsistente::preguntar(const QString &pregunta, const QJsonObject &eleccion)
{
    if (enCurso)
        return;
    agregar("paciente", pregunta.toHtmlEscaped());
    QJsonObject cuerpo{{"pregunta", pregunta}, {"origen", "terminal"}, {"historial", historial}, {"reserva", reserva}};
    if (!eleccion.isEmpty())
        cuerpo["eleccion"] = eleccion;
    enviarPedido(cuerpo, pregunta);
}

// Botones de la reserva en el chat: cada uno trae el estado siguiente (lo manda de vuelta a la API al tocarlo).
void DialogoAsistente::mostrarOpciones(const QJsonArray &opciones)
{
    auto *grilla = qobject_cast<QGridLayout *>(sugerencias->layout());
    while (QLayoutItem *item = grilla->takeAt(0)) {
        delete item->widget();
        delete item;
    }
    for (int i = 0; i < opciones.size(); ++i) {
        const QJsonObject o = opciones[i].toObject();
        auto *b = new QPushButton(o.value("texto").toString());
        b->setProperty("sugerencia", true);
        b->setCursor(Qt::PointingHandCursor);
        connect(b, &QPushButton::clicked, this, [this, o] { preguntar(o.value("texto").toString(), o.value("reserva").toObject()); });
        grilla->addWidget(b, i / 2, i % 2);
    }
    sugerencias->setVisible(!opciones.isEmpty());
}

// Último paso: datos de la persona (no pasan por la IA) y POST /api/turnos.
void DialogoAsistente::pedirDatosReserva(const QString &nombre, const QString &dni, const QString &telefono)
{
    QDialog d(this);
    d.setWindowTitle("Confirmar turno");
    auto *form = new QFormLayout(&d);
    auto *eNombre = new QLineEdit(nombre);
    auto *eDni = new QLineEdit(dni);
    auto *eTel = new QLineEdit(telefono);
    auto *eNac = new QLineEdit;
    eNac->setPlaceholderText("AAAA-MM-DD (solo si es tu primera vez)");
    form->addRow("Nombre y apellido", eNombre);
    form->addRow("DNI", eDni);
    form->addRow("Teléfono", eTel);
    form->addRow("Nacimiento", eNac);
    auto *botones = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel);
    botones->button(QDialogButtonBox::Ok)->setText("Confirmar turno");
    botones->button(QDialogButtonBox::Cancel)->setText("Ahora no");
    form->addRow(botones);
    connect(botones, &QDialogButtonBox::accepted, &d, &QDialog::accept);
    connect(botones, &QDialogButtonBox::rejected, &d, &QDialog::reject);
    if (d.exec() != QDialog::Accepted) {
        reserva = QJsonObject();
        agregar("asistente", "Dejé el turno sin confirmar. Cuando quieras, pedime uno de nuevo.");
        return;
    }
    QJsonObject cuerpo{{"nombre", eNombre->text().trimmed()}, {"dni", eDni->text().trimmed()}, {"telefono", eTel->text().trimmed()},
                       {"protocolos", QJsonArray{reserva.value("protocolo")}}, {"profesional", reserva.value("profesional")},
                       {"inicio", reserva.value("inicio")}};
    if (!eNac->text().trimmed().isEmpty())
        cuerpo["nacimiento"] = eNac->text().trimmed();
    QNetworkRequest pedido(QUrl(url + "/api/turnos"));
    pedido.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    pedido.setTransferTimeout(30000);
    QNetworkReply *r = red->post(pedido, QJsonDocument(cuerpo).toJson(QJsonDocument::Compact));
    connect(r, &QNetworkReply::finished, this, [this, r, cuerpo] {
        r->deleteLater();
        const int estado = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QJsonObject datos = QJsonDocument::fromJson(r->readAll()).object();
        if (estado == 201) {
            reserva = QJsonObject();
            sugerencias->hide();
            agregar("asistente", QString("¡Listo, tu turno quedó reservado! Seña: $%1.<br>Lo ves en <b>Mi turno</b>.")
                                     .arg(QLocale(QLocale::Spanish, QLocale::Argentina).toString(datos.value("sena").toDouble(), 'f', 0)));
            return;
        }
        const QString error = datos.value("error").toString(r->error() == QNetworkReply::NoError ? "No pude reservar." : "No pude conectar con el servidor.");
        agregar("asistente", error.toHtmlEscaped());
        pedirDatosReserva(cuerpo.value("nombre").toString(), cuerpo.value("dni").toString(), cuerpo.value("telefono").toString());
    });
}

// Manda una nota de voz (en base64) a la API.
void DialogoAsistente::preguntarConAudio(const QByteArray &audio, const QString &mime)
{
    if (enCurso)
        return;
    agregar("paciente", "🎤 <i>Nota de voz…</i>");
    enviarPedido(QJsonObject{{"audio", QString::fromLatin1(audio.toBase64())}, {"mime", mime},
                             {"origen", "terminal"}, {"historial", historial}, {"reserva", reserva}}, QString());
}

// Bloquea los botones, muestra 'Escribiendo…' y hace el POST al asistente.
void DialogoAsistente::enviarPedido(const QJsonObject &cuerpo, const QString &preguntaEscrita)
{
    enCurso = true;
    btnEnviar->setEnabled(false);
    btnVoz->setEnabled(false);
    sugerencias->hide();
    agregar("asistente", "<i>Escribiendo…</i>");

    QNetworkRequest pedido(QUrl(url + "/api/asistente"));
    pedido.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    pedido.setTransferTimeout(40000);   // con audio tarda más (transcribir + responder)
    QNetworkReply *respuesta = red->post(pedido, QJsonDocument(cuerpo).toJson(QJsonDocument::Compact));

    connect(respuesta, &QNetworkReply::finished, this, [this, respuesta, preguntaEscrita] {
        respuesta->deleteLater();
        const QJsonObject datos = QJsonDocument::fromJson(respuesta->readAll()).object();
        const QString texto = datos.value("respuesta").toString();
        QString pregunta = preguntaEscrita;
        if (pregunta.isEmpty()) {
            // nota de voz: la burbuja "Nota de voz…" pasa a mostrar lo que se entendió
            pregunta = datos.value("transcripcion").toString();
            if (!pregunta.isEmpty() && mensajesHtml.size() >= 2) {
                mensajesHtml.removeLast();   // "Escribiendo…"
                mensajesHtml.removeLast();   // "Nota de voz…"
                agregar("paciente", "🎤 " + pregunta.toHtmlEscaped());
                agregar("asistente", "<i>Escribiendo…</i>");   // terminar() lo reemplaza por la respuesta
            }
            if (pregunta.isEmpty() && respuesta->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() == 422) {
                terminar(datos.value("error").toString().toHtmlEscaped());
                return;
            }
        }
        if (respuesta->error() != QNetworkReply::NoError || texto.isEmpty()) {
            terminar("El asistente no está disponible en este momento. Podés usar <b>Consultar precios y "
                     "protocolos</b> o preguntar en la recepción.");
            return;
        }
        QString html = texto.toHtmlEscaped().replace('\n', "<br>");
        if (datos.value("derivada").toBool())
            html += "<br><br><b>Acercate a la recepción</b> o escribinos por WhatsApp y te responde una persona del equipo.";
        historial.append(QJsonObject{{"rol", "paciente"}, {"texto", pregunta}});
        historial.append(QJsonObject{{"rol", "asistente"}, {"texto", texto}});
        while (historial.size() > 6)
            historial.removeFirst();
        reserva = datos.value("reserva").toObject();
        terminar(html);
        mostrarOpciones(datos.value("opciones").toArray());
        if (datos.value("formulario").toBool())
            pedirDatosReserva();
    });
}

// Devuelve la conversación como texto plano.
QString DialogoAsistente::conversacionEnTexto() const
{
    return conversacion->toPlainText();
}
