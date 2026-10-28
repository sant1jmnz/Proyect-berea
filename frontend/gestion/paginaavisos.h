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

class PaginaAvisos : public QWidget
{
    Q_OBJECT

public:
    explicit PaginaAvisos(RegistroAvisos *registro, QWidget *parent = nullptr);

public slots:
    void recargar();

private slots:
    void abrirWhatsApp();
    void marcarFallido();
    void actualizarBotones();

private:
    RegistroAvisos *avisos;
    QTableWidget *tabla;
    QLabel *lblCuenta;
    QPushButton *btnWhatsApp, *btnFallido;
};

#endif
