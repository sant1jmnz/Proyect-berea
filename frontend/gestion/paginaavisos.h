/* Avisos (RF-11): registro de cada recordatorio de turno con su canal,
 * estado y fecha programada. Con "WhatsApp asistido" la recepción abre el
 * enlace wa.me con el mensaje ya escrito y solo toca Enviar. */
#ifndef PAGINAAVISOS_H
#define PAGINAAVISOS_H

#include "recordatorios.h"

#include <QWidget>

class QLabel;
class QPushButton;
class QTableWidget;

class Repositorio;

class PaginaAvisos : public QWidget
{
    Q_OBJECT

public:
    explicit PaginaAvisos(RegistroAvisos *registro, QWidget *parent = nullptr);

    /* Con la base conectada, marcar un aviso como enviado o fallido también lo guarda ahí. */
    void usarBase(Repositorio *repositorio) { repo = repositorio; }

public slots:
    void recargar();

private slots:
    void abrirWhatsApp();
    void marcarFallido();
    void actualizarBotones();

private:
    Repositorio *repo = nullptr;
    RegistroAvisos *avisos;
    QTableWidget *tabla;
    QLabel *lblCuenta;
    QPushButton *btnWhatsApp, *btnFallido;
};

#endif
