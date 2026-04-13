
-- Tabla 1

SELECT  

-- Run formateado y concatenado con DV
TO_CHAR(c.numrun, '99G999G999') ||'-'|| c.dvrun AS "RUT Cliente",

-- Primer nombre y apellido paterno, con INITCAP para cada palabra
INITCAP(c.pnombre ||' '|| c.appaterno) AS "Nombre Cliente",
 
-- Mayúsculas para nombre de profesión 
UPPER(po.nombre_prof_ofic) AS "Profesión Cliente",

-- Fecha formateada
TO_CHAR(c.fecha_inscripcion, 'DD-MM-YYYY') AS "Fecha de Inscripción",

-- Dirección
c.direccion AS "Dirección Cliente"

FROM cliente c 
JOIN profesion_oficio po ON c.cod_prof_ofic = po.cod_prof_ofic

-- Nombre de profesión entre 2 opciones
WHERE po.nombre_prof_ofic IN ('Contador', 'Vendedor')

-- Año de inscripción es mayor al promedio redondeado 
-- del año de inscripción de todos los clientes, calculado con una subcosulta
AND EXTRACT(YEAR FROM c.fecha_inscripcion) >
(SELECT ROUND(AVG(EXTRACT(YEAR FROM fecha_inscripcion))) 
FROM cliente) 

ORDER BY numrun;

--------------------------------------------------------------------------------


-- Tabla 2

-- Crear tabla con datos de Tabla 2
CREATE TABLE CLIENTES_CUPOS_COMPRA 
AS
SELECT 

-- Run concatenado con DV
c.numrun ||'-'|| c.dvrun AS "RUT_CLIENTE",

-- Calculo de edad entre datos con MONTHS_BETWEEN, y division de 12 meses
ROUND(MONTHS_BETWEEN(SYSDATE, fecha_nacimiento) / 12) AS "EDAD",

-- Formato de dinero
TO_CHAR(tc.cupo_disp_compra, '$9G999G999') AS "CUPO_DISPONIBLE_COMPRA",

UPPER(ti.nombre_tipo_cliente) AS "TIPO_CLIENTE"

FROM cliente c
JOIN tarjeta_cliente tc ON c.numrun = tc.numrun
JOIN tipo_cliente ti ON c.cod_tipo_cliente = ti.cod_tipo_cliente 

-- Filtro de máximo de cupo usando subconsulta,
-- con filtro para obtener resultados del año pasado 
WHERE tc.cupo_disp_compra >= 
(SELECT MAX(cupo_disp_compra) FROM tarjeta_cliente tj
JOIN transaccion_tarjeta_cliente ttc ON tj.nro_tarjeta = ttc.nro_tarjeta
WHERE EXTRACT(YEAR FROM fecha_transaccion) = EXTRACT(YEAR FROM SYSDATE) -1 )

ORDER BY "EDAD";

-- Consulta para nueva tabla creada
SELECT * FROM CLIENTES_CUPOS_COMPRA;
