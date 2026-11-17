/* Pantalla Consultas previas de cirugía (RF-25). Antes de una cirugía la paciente
 * tiene una consulta; el profesional carga si es apta o no:
 *   · no apta: el instituto retiene el 10% de la seña y devuelve el resto;
 *   · apta: tiene 6 meses para agendar la cirugía; si no, la evaluación vence;
 *   · vencida: la paciente puede reclamar una vez y se le devuelve el 50%.
 * Solo funciona con la base conectada (clinica.sp_listar_evaluaciones y los SP de 04). */
#ifndef PAGINAEVALUACIONES_H
#define PAGINAEVALUACIONES_H

#include "basedatos.h"

#include <QWidget>

class QCheckBox;
class QLabel;
class QPushButton;
class QTableWidget;
class Repositorio;

class PaginaEvaluaciones : public QWidget
{
    Q_OBJECT

public:
    explicit PaginaEvaluaciones(QWidget *parent = nullptr);
    void usarBase(Repositorio *repositorio, int idUsuarioActual);

public slots:
    void recargar();

private slots:
    void cargarResultado(const QString &resultado);
    void reclamar();
    void vencer();

private:
    int idElegido() const;   /* id_evaluacion de la fila elegida, 0 si no hay */

    Repositorio *repo = nullptr;
    int idUsuario = 0;
    Resultado evaluaciones;
    QCheckBox *checkPendientes;
    QTableWidget *tabla;
    QPushButton *btnApta, *btnNoApta, *btnReclamo, *btnVencer;
    QLabel *lblCuenta;
};

#endif
