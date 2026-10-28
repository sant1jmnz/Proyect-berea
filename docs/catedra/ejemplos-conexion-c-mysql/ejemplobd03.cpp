#include <iostream>
#include <mysql/mysql.h>

MYSQL_RES* ejecutar_sp(MYSQL *conn) {
    mysql_query(conn, "CALL sp_obtener_alumnos();");
    return mysql_store_result(conn);
}

int main() {
    MYSQL *conn = mysql_init(NULL);

    if (mysql_real_connect(conn, "127.0.0.1", "root", "TU_CLAVE", "CuartoAnio_2026", 3306, NULL, 0)) {
        
        MYSQL_RES *result = ejecutar_sp(conn);

        if (result) {
            MYSQL_ROW fila;

            // Recorremos los registros
            while ((fila = mysql_fetch_row(result))) {
                std::cout << fila[0] << " - " 
                          << fila[1] << " " 
                          << fila[2] << " (" 
                          << fila[3] << ")\n";
            }

            mysql_free_result(result);
        }

        mysql_close(conn);
    } else {
        std::cout << "Error de conexión: " << mysql_error(conn) << "\n";
    }

    return 0;
}
