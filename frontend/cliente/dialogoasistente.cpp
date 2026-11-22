#include "dialogoasistente.h"

#include "basedatos.h"

#include <QFile>
#include <QGridLayout>
#include <QHBoxLayout>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLabel>
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
    fila->addWidget(campo, 1);
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
    agregar("asistente", SALUDO.toHtmlEscaped());
}

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

void DialogoAsistente::pintar()
{
    conversacion->setHtml(mensajesHtml.join(QString()));
    conversacion->verticalScrollBar()->setValue(conversacion->verticalScrollBar()->maximum());
}

void DialogoAsistente::terminar(const QString &html)
{
    mensajesHtml.removeLast();   /* el "Escribiendo…" */
    agregar("asistente", html);
    enCurso = false;
    btnEnviar->setEnabled(true);
    emit respondio();
}

void DialogoAsistente::preguntar(const QString &pregunta)
{
    if (enCurso)
        return;
    enCurso = true;
    btnEnviar->setEnabled(false);
    sugerencias->hide();
    agregar("paciente", pregunta.toHtmlEscaped());
    agregar("asistente", "<i>Escribiendo…</i>");

    QJsonObject cuerpo{{"pregunta", pregunta}, {"origen", "terminal"}, {"historial", historial}};
    QNetworkRequest pedido(QUrl(url + "/api/asistente"));
    pedido.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    pedido.setTransferTimeout(20000);
    QNetworkReply *respuesta = red->post(pedido, QJsonDocument(cuerpo).toJson(QJsonDocument::Compact));

    connect(respuesta, &QNetworkReply::finished, this, [this, respuesta, pregunta] {
        respuesta->deleteLater();
        const QJsonObject datos = QJsonDocument::fromJson(respuesta->readAll()).object();
        const QString texto = datos.value("respuesta").toString();
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
        terminar(html);
    });
}

QString DialogoAsistente::conversacionEnTexto() const
{
    return conversacion->toPlainText();
}
