#include <iostream>
#include <string>
#include <mysql/mysql.h>

// Función que ejecuta el SP pasando el rango de fechas
MYSQL_RES* buscar_por_rango_fechas(MYSQL *conn, const std::string &fecha_desde, const std::string &fecha_hasta) {
    // Armamos la consulta concatenando las fechas entre comillas simples: 
    // CALL sp_buscar_alumnos_por_fecha('1990-01-01', '2000-12-31');
    std::string sql = "CALL sp_obtener_alumnos_Fecha('" 
                      + fecha_desde + "', '" 
                      + fecha_hasta + "');";

    if (mysql_query(conn, sql.c_str()) != 0) {
        std::cout << "Error al ejecutar SP: " << mysql_error(conn) << "\n";
        return NULL;
    }
    return mysql_store_result(conn);
}

int main() {
    MYSQL *conn = mysql_init(NULL);

    if (mysql_real_connect(conn, "127.0.0.1", "root", "TU_CLAVE", "CuartoAnio_2026", 3306, NULL, 0)) {
        
        // Definimos el rango de búsqueda en variables
        std::string desde = "1960-01-01";
        std::string hasta = "1975-01-01";

        MYSQL_RES *result = buscar_por_rango_fechas(conn, desde, hasta);

        if (result != NULL) {
            MYSQL_ROW fila;

            std::cout << "--- ALUMNOS NACIDOS ENTRE " << desde << " Y " << hasta << " ---\n\n";

            while ((fila = mysql_fetch_row(result)) != NULL) {
                std::cout << "ID: " << fila[0] << " | "
                          << "Nombre: " << fila[2] << " " << fila[1] << " | "
                          << "Mail: " << fila[3] << " | "
                          << "F. Nac: " << fila[4] << "\n";
            }

            mysql_free_result(result);
        }

        mysql_close(conn);
    } else {
        std::cout << "Error de conexión: " << mysql_error(conn) << "\n";
    }

    return 0;
}
