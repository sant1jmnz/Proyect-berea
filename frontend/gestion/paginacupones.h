/* Pantalla Cupones (RF-17, RF-22): la recepción busca los cupones de una paciente
 * por DNI, ve el token del QR (cambia cada 5 minutos), valida un cupón y emite los
 * cupones que correspondan según las reglas. Solo funciona con la base conectada:
 * las reglas y el token los calcula la base (backend/04 y 09). */
#ifndef PAGINACUPONES_H
#define PAGINACUPONES_H

#include "basedatos.h"

#include <QWidget>

class QLabel;
class QLineEdit;
class QPushButton;
class QTableWidget;
class Repositorio;

class PaginaCupones : public QWidget
{
    Q_OBJECT

public:
    explicit PaginaCupones(QWidget *parent = nullptr);
    void usarBase(Repositorio *repositorio, int idUsuarioActual);

private slots:
    void buscar();
    void verToken();
    void validar();
    void emitir();

private:
    int filaElegida() const;   /* -1 si no hay un cupón elegido */

    Repositorio *repo = nullptr;
    int idUsuario = 0;
    Resultado cupones;          /* lo que devolvió la última búsqueda */
    QLineEdit *editDni;
    QPushButton *btnBuscar, *btnToken, *btnValidar, *btnEmitir;
    QTableWidget *tabla;
    QLabel *lblCuenta;
};

#endif
