/* Pantalla Tarjetas de regalo (RF-23): la recepción vende una tarjeta (vale 12 meses)
 * y consulta el saldo y los movimientos de una tarjeta por su código. Solo funciona
 * con la base conectada (pagos.sp_comprar_tarjeta, sp_saldo_tarjeta, sp_movimientos_tarjeta). */
#ifndef PAGINATARJETAS_H
#define PAGINATARJETAS_H

#include <QWidget>

class QComboBox;
class QLabel;
class QLineEdit;
class QPushButton;
class QTableWidget;
class Repositorio;

class PaginaTarjetas : public QWidget
{
    Q_OBJECT

public:
    explicit PaginaTarjetas(QWidget *parent = nullptr);
    void usarBase(Repositorio *repositorio, int idUsuarioActual);

private slots:
    void vender();
    void consultar();

private:
    Repositorio *repo = nullptr;
    int idUsuario = 0;
    QLineEdit *editMonto, *editComprador, *editTelefono, *editCodigo;
    QComboBox *comboMedio;
    QPushButton *btnVender, *btnConsultar;
    QLabel *lblSaldo, *lblNota;
    QTableWidget *tabla;
};

#endif
