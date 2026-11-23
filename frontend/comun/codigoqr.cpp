#include "codigoqr.h"

#include <QPainter>

#include <algorithm>
#include <vector>

namespace {

using Bytes = std::vector<quint8>;

/* Corrección de errores M: bytes de corrección por bloque y cantidad de bloques, por versión (1 a 10). */
const int ECC_POR_BLOQUE[] = { 0, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26 };
const int CANT_BLOQUES[]   = { 0,  1,  1,  1,  2,  2,  4,  4,  4,  5,  5 };

int bitsDeDatos(int version)    /* módulos que guardan datos o corrección (sin patrones fijos) */
{
    int r = (16 * version + 128) * version + 64;
    if (version >= 2) {
        const int alineaciones = version / 7 + 2;
        r -= (25 * alineaciones - 10) * alineaciones - 55;
        if (version >= 7)
            r -= 36;
    }
    return r;
}

int bytesDeDatos(int version)
{
    return bitsDeDatos(version) / 8 - ECC_POR_BLOQUE[version] * CANT_BLOQUES[version];
}

/* Multiplicación en GF(256) con el polinomio 0x11D. */
quint8 multiplicar(quint8 a, quint8 b)
{
    int r = 0;
    for (int i = 7; i >= 0; --i) {
        r = (r << 1) ^ ((r >> 7) * 0x11D);
        r ^= ((b >> i) & 1) * a;
    }
    return quint8(r);
}

Bytes divisorReedSolomon(int grado)
{
    Bytes r(size_t(grado), 0);
    r[size_t(grado - 1)] = 1;
    quint8 raiz = 1;
    for (int i = 0; i < grado; ++i) {
        for (int j = 0; j < grado; ++j) {
            r[size_t(j)] = multiplicar(r[size_t(j)], raiz);
            if (j + 1 < grado)
                r[size_t(j)] ^= r[size_t(j + 1)];
        }
        raiz = multiplicar(raiz, 0x02);
    }
    return r;
}

Bytes restoReedSolomon(const Bytes &datos, const Bytes &divisor)
{
    Bytes r(divisor.size(), 0);
    for (quint8 b : datos) {
        const quint8 factor = b ^ r.front();
        r.erase(r.begin());
        r.push_back(0);
        for (size_t i = 0; i < r.size(); ++i)
            r[i] ^= multiplicar(divisor[i], factor);
    }
    return r;
}

/* Matriz de módulos mientras se arma: `funcion` marca los que no llevan datos. */
struct Matriz
{
    int lado;
    std::vector<bool> oscuro, funcion;
    explicit Matriz(int l) : lado(l), oscuro(size_t(l * l), false), funcion(size_t(l * l), false) {}
    bool dentro(int x, int y) const { return x >= 0 && y >= 0 && x < lado && y < lado; }
    void fijar(int x, int y, bool o)
    {
        if (!dentro(x, y))
            return;
        oscuro[size_t(y * lado + x)] = o;
        funcion[size_t(y * lado + x)] = true;
    }
    bool es(int x, int y) const { return oscuro[size_t(y * lado + x)]; }
};

void dibujarBuscador(Matriz &m, int cx, int cy)
{
    for (int dy = -4; dy <= 4; ++dy)
        for (int dx = -4; dx <= 4; ++dx) {
            const int d = std::max(qAbs(dx), qAbs(dy));
            m.fijar(cx + dx, cy + dy, d != 2 && d != 4);
        }
}

void dibujarAlineacion(Matriz &m, int cx, int cy)
{
    for (int dy = -2; dy <= 2; ++dy)
        for (int dx = -2; dx <= 2; ++dx)
            m.fijar(cx + dx, cy + dy, std::max(qAbs(dx), qAbs(dy)) != 1);
}

std::vector<int> posicionesAlineacion(int version, int lado)
{
    if (version == 1)
        return {};
    const int cantidad = version / 7 + 2;
    const int paso = (version * 4 + cantidad * 2 + 1) / (cantidad * 2 - 2) * 2;
    std::vector<int> r;
    for (int i = 0, pos = lado - 7; i < cantidad - 1; ++i, pos -= paso)
        r.insert(r.begin(), pos);
    r.insert(r.begin(), 6);
    return r;
}

void dibujarFormato(Matriz &m, int mascara)
{
    const int datos = (0 << 3) | mascara;   /* nivel M = 0 */
    int resto = datos;
    for (int i = 0; i < 10; ++i)
        resto = (resto << 1) ^ ((resto >> 9) * 0x537);
    const int bits = ((datos << 10) | resto) ^ 0x5412;
    auto bit = [bits](int i) { return ((bits >> i) & 1) != 0; };
    const int n = m.lado;
    for (int i = 0; i <= 5; ++i)
        m.fijar(8, i, bit(i));
    m.fijar(8, 7, bit(6));
    m.fijar(8, 8, bit(7));
    m.fijar(7, 8, bit(8));
    for (int i = 9; i < 15; ++i)
        m.fijar(14 - i, 8, bit(i));
    for (int i = 0; i < 8; ++i)
        m.fijar(n - 1 - i, 8, bit(i));
    for (int i = 8; i < 15; ++i)
        m.fijar(8, n - 15 + i, bit(i));
    m.fijar(8, n - 8, true);   /* módulo oscuro fijo */
}

void dibujarVersion(Matriz &m, int version)
{
    if (version < 7)
        return;
    int resto = version;
    for (int i = 0; i < 12; ++i)
        resto = (resto << 1) ^ ((resto >> 11) * 0x1F25);
    const int bits = (version << 12) | resto;
    for (int i = 0; i < 18; ++i) {
        const bool b = ((bits >> i) & 1) != 0;
        const int a = m.lado - 11 + i % 3, c = i / 3;
        m.fijar(a, c, b);
        m.fijar(c, a, b);
    }
}

Matriz patronesFijos(int version)
{
    const int lado = version * 4 + 17;
    Matriz m(lado);
    for (int i = 0; i < lado; ++i) {
        m.fijar(6, i, i % 2 == 0);
        m.fijar(i, 6, i % 2 == 0);
    }
    dibujarBuscador(m, 3, 3);
    dibujarBuscador(m, lado - 4, 3);
    dibujarBuscador(m, 3, lado - 4);
    const std::vector<int> pos = posicionesAlineacion(version, lado);
    const size_t n = pos.size();
    for (size_t i = 0; i < n; ++i)
        for (size_t j = 0; j < n; ++j)
            if (!((i == 0 && j == 0) || (i == 0 && j == n - 1) || (i == n - 1 && j == 0)))
                dibujarAlineacion(m, pos[i], pos[j]);
    dibujarFormato(m, 0);   /* reserva el lugar; después se redibuja con la máscara elegida */
    dibujarVersion(m, version);
    return m;
}

void colocarDatos(Matriz &m, const Bytes &datos)
{
    size_t i = 0;
    for (int derecha = m.lado - 1; derecha >= 1; derecha -= 2) {
        if (derecha == 6)
            derecha = 5;
        for (int vert = 0; vert < m.lado; ++vert)
            for (int j = 0; j < 2; ++j) {
                const int x = derecha - j;
                const bool subiendo = ((derecha + 1) & 2) == 0;
                const int y = subiendo ? m.lado - 1 - vert : vert;
                if (!m.funcion[size_t(y * m.lado + x)] && i < datos.size() * 8) {
                    m.oscuro[size_t(y * m.lado + x)] = ((datos[i >> 3] >> (7 - (i & 7))) & 1) != 0;
                    ++i;
                }
            }
    }
}

void aplicarMascara(Matriz &m, int mascara)
{
    for (int y = 0; y < m.lado; ++y)
        for (int x = 0; x < m.lado; ++x) {
            bool invertir = false;
            switch (mascara) {
            case 0: invertir = (x + y) % 2 == 0; break;
            case 1: invertir = y % 2 == 0; break;
            case 2: invertir = x % 3 == 0; break;
            case 3: invertir = (x + y) % 3 == 0; break;
            case 4: invertir = (x / 3 + y / 2) % 2 == 0; break;
            case 5: invertir = x * y % 2 + x * y % 3 == 0; break;
            case 6: invertir = (x * y % 2 + x * y % 3) % 2 == 0; break;
            default: invertir = ((x + y) % 2 + x * y % 3) % 2 == 0; break;
            }
            if (invertir && !m.funcion[size_t(y * m.lado + x)])
                m.oscuro[size_t(y * m.lado + x)] = !m.oscuro[size_t(y * m.lado + x)];
        }
}

/* Puntaje de penalización de la norma (cuanto menor, mejor se lee). */
int penalizacion(const Matriz &m)
{
    const int n = m.lado;
    int total = 0;
    for (int eje = 0; eje < 2; ++eje) {   /* filas y después columnas */
        for (int a = 0; a < n; ++a) {
            int corrida = 1;
            quint32 ventana = 0;   /* últimos 11 módulos */
            for (int b = 0; b < n; ++b) {
                const bool actual = eje == 0 ? m.es(b, a) : m.es(a, b);
                if (b > 0) {
                    const bool previo = eje == 0 ? m.es(b - 1, a) : m.es(a, b - 1);
                    if (actual == previo) {
                        ++corrida;
                        if (corrida == 5) total += 3;
                        else if (corrida > 5) total += 1;
                    } else {
                        corrida = 1;
                    }
                }
                ventana = ((ventana << 1) | (actual ? 1 : 0)) & 0x7FF;
                if (b >= 10 && (ventana == 0x5D || ventana == 0x5D0))   /* 00001011101 y 10111010000 */
                    total += 40;
            }
        }
    }
    for (int y = 0; y + 1 < n; ++y)
        for (int x = 0; x + 1 < n; ++x) {
            const bool c = m.es(x, y);
            if (c == m.es(x + 1, y) && c == m.es(x, y + 1) && c == m.es(x + 1, y + 1))
                total += 3;
        }
    int oscuros = 0;
    for (bool o : m.oscuro)
        oscuros += o ? 1 : 0;
    const int modulos = n * n;
    const int k = (qAbs(oscuros * 20 - modulos * 10) + modulos - 1) / modulos - 1;
    return total + std::max(k, 0) * 10;
}

} // namespace

CodigoQr CodigoQr::codificar(const QString &texto)
{
    CodigoQr r;
    const QByteArray utf8 = texto.toUtf8();

    int version = 1;
    for (; version <= VERSION_MAXIMA; ++version) {
        const int bitsCuenta = version < 10 ? 8 : 16;
        if (4 + bitsCuenta + utf8.size() * 8 <= bytesDeDatos(version) * 8)
            break;
    }
    if (version > VERSION_MAXIMA || utf8.isEmpty())
        return r;

    /* Bits de datos: modo byte (0100), cantidad de caracteres, bytes, terminador y relleno. */
    std::vector<bool> bits;
    auto agregar = [&bits](quint32 valor, int cantidad) {
        for (int i = cantidad - 1; i >= 0; --i)
            bits.push_back(((valor >> i) & 1) != 0);
    };
    agregar(0x4, 4);
    agregar(quint32(utf8.size()), version < 10 ? 8 : 16);
    for (char c : utf8)
        agregar(quint8(c), 8);
    const size_t capacidad = size_t(bytesDeDatos(version)) * 8;
    agregar(0, int(std::min<size_t>(4, capacidad - bits.size())));
    while (bits.size() % 8 != 0)
        bits.push_back(false);
    Bytes datos(bits.size() / 8, 0);
    for (size_t i = 0; i < bits.size(); ++i)
        datos[i >> 3] |= quint8((bits[i] ? 1 : 0) << (7 - (i & 7)));
    for (quint8 relleno = 0xEC; datos.size() < capacidad / 8; relleno ^= 0xEC ^ 0x11)
        datos.push_back(relleno);

    /* Bloques con corrección de errores, intercalados. */
    const int cantBloques = CANT_BLOQUES[version], eccLen = ECC_POR_BLOQUE[version];
    const int brutos = bitsDeDatos(version) / 8;
    const int bloquesCortos = cantBloques - brutos % cantBloques;
    const int largoCorto = brutos / cantBloques;
    const Bytes divisor = divisorReedSolomon(eccLen);
    std::vector<Bytes> bloques;
    for (int i = 0, k = 0; i < cantBloques; ++i) {
        const int largo = largoCorto - eccLen + (i < bloquesCortos ? 0 : 1);
        Bytes dat(datos.begin() + k, datos.begin() + k + largo);
        k += largo;
        const Bytes ecc = restoReedSolomon(dat, divisor);
        if (i < bloquesCortos)
            dat.push_back(0);
        dat.insert(dat.end(), ecc.begin(), ecc.end());
        bloques.push_back(dat);
    }
    Bytes todos;
    for (int i = 0; i < largoCorto + 1; ++i)
        for (int j = 0; j < cantBloques; ++j)
            if (i != largoCorto - eccLen || j >= bloquesCortos)
                todos.push_back(bloques[size_t(j)][size_t(i)]);

    /* Se prueba cada máscara y se queda con la de menor penalización. */
    Matriz base = patronesFijos(version);
    colocarDatos(base, todos);
    int mejorMascara = 0, mejorPuntaje = -1;
    Matriz mejor = base;
    for (int mascara = 0; mascara < 8; ++mascara) {
        Matriz m = base;
        aplicarMascara(m, mascara);
        dibujarFormato(m, mascara);
        const int puntaje = penalizacion(m);
        if (mejorPuntaje < 0 || puntaje < mejorPuntaje) {
            mejorPuntaje = puntaje;
            mejorMascara = mascara;
            mejor = m;
        }
    }
    Q_UNUSED(mejorMascara)

    r.lado_ = mejor.lado;
    r.modulos.resize(mejor.lado * mejor.lado);
    for (int i = 0; i < mejor.lado * mejor.lado; ++i)
        r.modulos[i] = mejor.oscuro[size_t(i)];
    return r;
}

QString CodigoQr::textoDeCupon(const QString &codigo, const QString &token)
{
    return QStringLiteral("dermalia:cupon:%1:%2").arg(codigo, token);
}

QString CodigoQr::tokenDeCupon(const QString &texto, const QString &codigo)
{
    const QString t = texto.trimmed();
    if (!t.startsWith(QLatin1String("dermalia:cupon:"), Qt::CaseInsensitive))
        return t;   /* solo el token */
    const QStringList partes = t.split(QLatin1Char(':'));
    if (partes.size() != 4 || partes[2].compare(codigo, Qt::CaseInsensitive) != 0)
        return QString();
    return partes[3].trimmed();
}

QImage CodigoQr::imagen(int pixelesPorModulo, int margen) const
{
    if (!valido())
        return QImage();
    const int lado = (lado_ + 2 * margen) * pixelesPorModulo;
    QImage img(lado, lado, QImage::Format_RGB32);
    img.fill(Qt::white);
    QPainter p(&img);
    p.setPen(Qt::NoPen);
    p.setBrush(Qt::black);
    for (int y = 0; y < lado_; ++y)
        for (int x = 0; x < lado_; ++x)
            if (modulo(x, y))
                p.drawRect((x + margen) * pixelesPorModulo, (y + margen) * pixelesPorModulo, pixelesPorModulo, pixelesPorModulo);
    return img;
}
