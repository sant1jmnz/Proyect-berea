/* Pantalla Reportes (administración): los 8 reportes de la base y el reporte de
 * auditoría (backend/05_reportes_semana5.sql). Se elige el reporte y el rango de
 * fechas, y el resultado se muestra en una tabla. Solo funciona con la base
 * conectada (los reportes se calculan en los stored procedures). */
#ifndef PAGINAREPORTES_H
#define PAGINAREPORTES_H

#include <QWidget>

class QComboBox;
class QDateEdit;
class QLabel;
class QPushButton;
class QTableWidget;
class Repositorio;

class PaginaReportes : public QWidget
{
    Q_OBJECT

public:
    explicit PaginaReportes(QWidget *parent = nullptr);

    /* Con la base conectada se habilita el botón Consultar. */
    void usarBase(Repositorio *repositorio);

private slots:
    void on_btnConsultar_clicked();

private:
    Repositorio *repo = nullptr;
    QComboBox *comboReporte;
    QDateEdit *editDesde, *editHasta;
    QPushButton *btnConsultar;
    QTableWidget *tabla;
    QLabel *lblCuenta;
};

#endif
