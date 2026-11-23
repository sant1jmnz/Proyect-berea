/* Código QR propio (Qt no trae generador): texto en modo byte, corrección de errores M, versiones 1 a 10
 * (hasta 213 bytes). Alcanza para el token de un cupón. Lo usa Gestión para mostrar el QR que la
 * paciente le presenta a la recepción (RF-22). */
#ifndef CODIGOQR_H
#define CODIGOQR_H

#include <QImage>
#include <QString>
#include <QVector>

class CodigoQr
{
public:
    static constexpr int VERSION_MAXIMA = 10;

    /* Codifica `texto` en UTF-8. Si no entra en la versión máxima, `valido()` es false. */
    static CodigoQr codificar(const QString &texto);

    bool valido() const { return lado_ > 0; }
    int lado() const { return lado_; }                    /* módulos por lado */
    bool modulo(int x, int y) const { return modulos.at(y * lado_ + x); }

    /* Imagen en blanco y negro con zona de silencio (`margen` módulos) alrededor. */
    QImage imagen(int pixelesPorModulo = 8, int margen = 4) const;

    /* Texto que lleva el QR de un cupón: "dermalia:cupon:<codigo>:<token>". */
    static QString textoDeCupon(const QString &codigo, const QString &token);
    /* Lo que escribió o escaneó la recepción: el texto completo o solo el token. Devuelve el token,
     * o vacío si el texto trae otro código de cupón. */
    static QString tokenDeCupon(const QString &texto, const QString &codigo);

private:
    int lado_ = 0;
    QVector<bool> modulos;
};

#endif
