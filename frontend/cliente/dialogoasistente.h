#ifndef DIALOGOASISTENTE_H
#define DIALOGOASISTENTE_H

/* Asistente de IA de la terminal (RF-14, RF-07).
 *
 * La terminal no habla con Gemini directamente: le pregunta a la API del sitio
 * (POST /api/asistente, web/api/servidor.js), que es la que tiene la clave, arma la
 * respuesta solo con el catálogo y las reglas del instituto, borra los datos
 * personales y registra la consulta en la base (asistente.sp_registrar_consulta).
 * Así la terminal y el sitio responden exactamente lo mismo.
 *
 * Dirección de la API: variable DERMALIA_API_URL o, en dermalia.ini, la clave
 * "url" de la sección [asistente]. Por defecto http://127.0.0.1:3000. */

#include <QDialog>
#include <QJsonArray>

class QLabel;
class QLineEdit;
class QPushButton;
class QTextBrowser;
class QNetworkAccessManager;
class QWidget;
class QMediaRecorder;
class QTimer;

class DialogoAsistente : public QDialog
{
    Q_OBJECT

public:
    explicit DialogoAsistente(QWidget *parent = nullptr, const QString &urlApi = QString());

    /* Dirección de la API: entorno, dermalia.ini o la de por defecto. */
    static QString urlPorDefecto(const QString &archivoIni = QStringLiteral("dermalia.ini"));

    /* Para las pruebas: hace una pregunta como si la paciente la escribiera. */
    void preguntar(const QString &pregunta);
    /* Nota de voz: la API la pasa a texto (como el bot de Telegram) y responde. */
    void preguntarConAudio(const QByteArray &audio, const QString &mime);
    QString conversacionEnTexto() const;
    bool esperando() const { return enCurso; }

signals:
    void respondio();   /* llegó la respuesta (o el aviso de que no hay asistente) */

private:
    void agregar(const QString &rol, const QString &html);
    void pintar();
    void terminar(const QString &html);
    void enviarPedido(const QJsonObject &cuerpo, const QString &pregunta);
    void alternarGrabacion();

    QString url;
    QNetworkAccessManager *red = nullptr;
    QTextBrowser *conversacion = nullptr;
    QWidget *sugerencias = nullptr;
    QLineEdit *campo = nullptr;
    QPushButton *btnEnviar = nullptr;
    QPushButton *btnVoz = nullptr;
    QMediaRecorder *grabador = nullptr;
    QTimer *corte = nullptr;
    QString archivoAudio;
    QStringList mensajesHtml;
    QJsonArray historial;
    bool enCurso = false;
};

#endif
