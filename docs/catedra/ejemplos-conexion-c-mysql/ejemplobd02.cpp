#include <iostream>
#include <mysql/mysql.h>

bool insertar_alumno(MYSQL *conn, const char *apellido, const char *nombre, const char *mail) {
    // Construimos la consulta SQL (idAlumno es AUTO_INCREMENT)
    std::string sql = "INSERT INTO alumno (apellido, nombre, mail) VALUES ('" 
                      + std::string(apellido) + "', '" 
                      + std::string(nombre) + "', '" 
                      + std::string(mail) + "');";

    // mysql_query devuelve 0 si la ejecución fue EXITOSA
    if (mysql_query(conn, sql.c_str()) == 0) {
        return true;
    } else {
        std::cout << "Error al insertar: " << mysql_error(conn) << "\n";
        return false;
    }
}

int main() {
    MYSQL *conn = mysql_init(NULL);

    if (mysql_real_connect(conn, "127.0.0.1", "root", "TU_CLAVE", "CuartoAnio_2026", 3306, NULL, 0)) {
        
        // Ejecutamos la función de inserción con datos de prueba
        if (insertar_alumno(conn, "IOPPOLO", "SERGIO", "sergio.iopolo@bue.edu.ar")) {
            std::cout << "¡Alumno insertado correctamente!\n";
            // Obtenemos el ID autogenerado por AUTO_INCREMENT
            std::cout << "ID generado: " << mysql_insert_id(conn) << "\n";
        }

        mysql_close(conn);
    } else {
        std::cout << "Error de conexión: " << mysql_error(conn) << "\n";
    }

    return 0;
}
