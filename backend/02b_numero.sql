-- Dermalia: tabla auxiliar de números (0 a 47) del backend.
-- Reemplaza a las consultas recursivas (WITH RECURSIVE), que el material de la cátedra no enseña:
-- los stored procedures la usan para partir una franja horaria en turnos de 30 minutos
-- (agenda.sp_horarios_libres) y para emitir un cupón por cada múltiplo del gasto
-- (beneficios.sp_emitir_cupones). No es una entidad del modelo: vive con el backend.
-- Se puede correr varias veces: solo agrega los números que faltan.

CREATE TABLE IF NOT EXISTS agenda.Numero (
    n INT PRIMARY KEY
);

INSERT INTO agenda.Numero (n)
SELECT v.n
  FROM (SELECT 0 AS n
    UNION ALL SELECT 1
    UNION ALL SELECT 2
    UNION ALL SELECT 3
    UNION ALL SELECT 4
    UNION ALL SELECT 5
    UNION ALL SELECT 6
    UNION ALL SELECT 7
    UNION ALL SELECT 8
    UNION ALL SELECT 9
    UNION ALL SELECT 10
    UNION ALL SELECT 11
    UNION ALL SELECT 12
    UNION ALL SELECT 13
    UNION ALL SELECT 14
    UNION ALL SELECT 15
    UNION ALL SELECT 16
    UNION ALL SELECT 17
    UNION ALL SELECT 18
    UNION ALL SELECT 19
    UNION ALL SELECT 20
    UNION ALL SELECT 21
    UNION ALL SELECT 22
    UNION ALL SELECT 23
    UNION ALL SELECT 24
    UNION ALL SELECT 25
    UNION ALL SELECT 26
    UNION ALL SELECT 27
    UNION ALL SELECT 28
    UNION ALL SELECT 29
    UNION ALL SELECT 30
    UNION ALL SELECT 31
    UNION ALL SELECT 32
    UNION ALL SELECT 33
    UNION ALL SELECT 34
    UNION ALL SELECT 35
    UNION ALL SELECT 36
    UNION ALL SELECT 37
    UNION ALL SELECT 38
    UNION ALL SELECT 39
    UNION ALL SELECT 40
    UNION ALL SELECT 41
    UNION ALL SELECT 42
    UNION ALL SELECT 43
    UNION ALL SELECT 44
    UNION ALL SELECT 45
    UNION ALL SELECT 46
    UNION ALL SELECT 47
       ) v
 WHERE NOT EXISTS (SELECT 1 FROM agenda.Numero x WHERE x.n = v.n);
