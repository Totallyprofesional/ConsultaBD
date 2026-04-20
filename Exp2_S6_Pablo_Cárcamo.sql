
-- Tabla 1 

-- Creación de tabla mediante consulta
CREATE TABLE RECAUDACION_BONOS_MEDICOS 
AS 
SELECT 
-- Rut formateado y concatenado, con relleno de 0 a la izquierda 
TO_CHAR(m.rut_med, '09G999G999') ||'-'|| m.dv_run AS "RUT_MÉDICO",

-- Nombre con apellidos en mayúscula
UPPER(m.pnombre ||' '|| m.apaterno ||' '|| m.amaterno) AS "NOMBRE MÉDICO", 

-- Calculo total de costo, con formato de dinero
TO_CHAR(SUM(bc.costo), '$9G999G999') AS "TOTAL RECAUDADO",

INITCAP(uc.nombre) AS "UNIDAD_MÉDICA"

FROM medico m
JOIN bono_consulta bc ON m.rut_med = bc.rut_med
JOIN unidad_consulta uc ON m.uni_id = uc.uni_id

-- Filtro para fecha al año pasado 
WHERE EXTRACT(YEAR FROM bc.fecha_bono) = EXTRACT(YEAR FROM SYSDATE) -1     
-- Exclusión de 3 valores con NOT IN
AND car_id NOT IN(100, 500, 600)

GROUP BY m.rut_med, m.dv_run, m.pnombre, m.apaterno, m.amaterno, uc.nombre
     
-- Ordenar por Total Recaudado
ORDER BY "TOTAL RECAUDADO";

-- Revisión de tabla construida 
SELECT * FROM RECAUDACION_BONOS_MEDICOS;

--------------------------------------------------------------------------------


-- Tabla 2

SELECT 

-- Nombre de especialidad en mayúsculas
UPPER(em.nombre) AS "ESPECIALIDAD MEDICA",

-- COUNT para calculo de cantidad de bonos
COUNT(bc.id_bono) AS "CANTIDAD BONOS",

-- Suma de costos de bonos
TO_CHAR(SUM(bc.costo), '$999G999') AS "MONTO PÉRDIDA",

-- Fecha formateada
TO_CHAR(MIN(bc.fecha_bono), 'DD-MM-YYYY') AS "FECHA BONO",

-- Calculo de fechas de cobro entre fecha actual, año pasado y anteriores
CASE 
WHEN EXTRACT(YEAR FROM MIN(bc.fecha_bono)) < (EXTRACT(YEAR FROM SYSDATE) -1) 
THEN 'INCOBRABLE'
ELSE 'COBRABLE' 
END 
AS "ESTADO DE COBRO" 

FROM bono_consulta bc
JOIN especialidad_medica em ON bc.esp_id = em.esp_id

-- Filtro para restar bonos fuera de la tabla pagos
WHERE bc.id_bono IN (
SELECT id_bono FROM bono_consulta
MINUS 
SELECT id_bono FROM pagos
)

GROUP BY em.nombre

ORDER BY "CANTIDAD BONOS", "MONTO PÉRDIDA" DESC;

--------------------------------------------------------------------------------


-- Tabla 3

-- Borrar datos de tabla a modificar
DELETE FROM CANT_BONOS_PACIENTES_ANNIO;

-- Insert de datos mediante consulta
INSERT INTO CANT_BONOS_PACIENTES_ANNIO (ANNIO_CALCULO, PAC_RUN, DV_RUN, EDAD,
CANTIDAD_BONOS, MONTO_TOTAL_BONOS, SISTEMA_SALUD)

SELECT 

-- Año de ejecución actual
EXTRACT(YEAR FROM SYSDATE) AS "ANNIO_CALCULO",

-- Run paciente
p.pac_run AS "PAC_RUN", 

-- Digito verificador run paciente
p.dv_run AS "DV_RUN",
 
-- Cálculo de edad dividido con 12 meses por año y redondeo 
ROUND(MONTHS_BETWEEN(SYSDATE, p.fecha_nacimiento) / 12) AS "EDAD",

-- Count para contar cantidad de bonos
COUNT(bc.id_bono) AS "CANTIDAD_BONOS",

-- SUM para suma total de bonos, con reemplazso de null por 0
NVL(SUM(bc.costo), 0) AS "MONTO_TOTAL_BONOS",

UPPER(ss.descripcion) AS "SISTEMA_SALUD"

FROM paciente p
LEFT JOIN bono_consulta bc ON p.pac_run = bc.pac_run
JOIN salud s ON p.sal_id = s.sal_id
JOIN sistema_salud ss ON s.tipo_sal_id = ss.tipo_sal_id

-- Filtro de nombres entre 3 elementos
WHERE ss.descripcion IN('FONASA', 'PARTICULAR', 'Fuerzas Armadas')

GROUP BY p.pac_run, p.dv_run, p.fecha_nacimiento, ss.descripcion 

-- Calculo para cantidad de bonos, que no superen promedio redondeado 
-- de cantidad de bonos del año pasado
HAVING COUNT(bc.id_bono) <= (
SELECT ROUND(AVG(COUNT(id_bono))) 
FROM bono_consulta 
WHERE EXTRACT(YEAR FROM fecha_bono) = EXTRACT(YEAR FROM SYSDATE) -1
GROUP BY pac_run
)

ORDER BY "MONTO_TOTAL_BONOS", "EDAD" DESC;

-- Confirmar datos insertados
COMMIT;

-- Consulta para verificar datos insertados
SELECT * FROM CANT_BONOS_PACIENTES_ANNIO;

