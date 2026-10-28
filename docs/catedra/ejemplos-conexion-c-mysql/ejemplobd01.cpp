#include <iostream>
#include <mysql/mysql.h>

// Función directa que ejecuta el SELECT y devuelve el resultset
MYSQL_RES* hacer_select(MYSQL *conn) {
    mysql_query(conn, "SELECT idAlumno, apellido, nombre, mail FROM alumno;");
    return mysql_store_result(conn);
}

int main() {
    MYSQL *conn = mysql_init(NULL);

    if (mysql_real_connect(conn, "127.0.0.1", "root", "TU_CLAVE", "CuartoAnio_2026", 3306, NULL, 0)) {
        
        MYSQL_RES *result = hacer_select(conn);

        if (result) {
            MYSQL_ROW fila;

            // Recorremos las filas directamente con cout
            while ((fila = mysql_fetch_row(result))) {
                std::cout << fila[0] << " - " 
                          << fila[1] << " " 
                          << fila[2] << " (" 
                          << fila[3] << ")\n";
            }

            mysql_free_result(result);
        }

        mysql_close(conn);
    }

    return 0;
}

