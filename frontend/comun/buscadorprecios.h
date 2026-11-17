/* Buscador de precios y protocolos (RF-05, RF-06, RF-07).
 * Es un widget aparte porque lo usan los dos apartados: Cliente y Gestión
 * lo ponen dentro de su página `pagBuscador` y le pasan su catálogo (el de la
 * base, o el del archivo local sin conexión). Busca por nombre o descripción,
 * sin importar mayúsculas ni tildes; cada resultado tiene "Ver resumen" (la misma
 * ficha que la web). Si no aparece lo que se busca, se consulta por WhatsApp.
 * No trae colores propios: toma el estilo de la ventana que lo contiene. */
#ifndef BUSCADORPRECIOS_H
#define BUSCADORPRECIOS_H

#include "resumentratamiento.h"

#include <QVector>
#include <QWidget>

namespace Ui { class BuscadorPrecios; }
class QVBoxLayout;

class BuscadorPrecios : public QWidget
{
    Q_OBJECT

public:
    explicit BuscadorPrecios(QWidget *parent = nullptr);
    ~BuscadorPrecios();

    /* Los tratamientos que se pueden buscar (solo los activos). */
    void setCatalogo(const QVector<Tratamiento> &tratamientos);
    /* Los que coinciden con `texto` (vacío: todos), ordenados por nombre. */
    static QVector<int> buscar(const QVector<Tratamiento> &tratamientos, const QString &texto);

private:
    void mostrarResultados();
    void consultarPorWhatsApp();

    Ui::BuscadorPrecios *ui;
    QVector<Tratamiento> catalogo;
    QVBoxLayout *filas = nullptr;   /* una fila por resultado, dentro de un área con scroll */
};

#endif
