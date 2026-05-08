
-- Usuario SYS

-- Usando Oracle XE, comando para crear usuarios
ALTER SESSION SET CONTAINER = XEPDB1;

-- CASO 1
-- Estrategia de seguridad
-- Crear usuarios, asignar roles y privilegios

-- Creación usuario PRY2205_EFT
CREATE USER PRY2205_EFT IDENTIFIED BY "TareaFinal987654"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA 10M ON USERS;

GRANT CREATE SESSION TO PRY2205_EFT WITH ADMIN OPTION;

-- Privilegios para PRY2205_EFT
GRANT CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE SYNONYM, CREATE PUBLIC SYNONYM 
TO PRY2205_EFT WITH ADMIN OPTION;

-- Creación usuario PRY2205_EFT_DES
CREATE USER PRY2205_EFT_DES IDENTIFIED BY "FinalTarea987654"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA 10M ON USERS;

GRANT CREATE SESSION TO PRY2205_EFT_DES WITH ADMIN OPTION;

-- Otorgar rol PRY2205_ROL_D a PRY2205_EFT_DES
CREATE ROLE PRY2205_ROL_D;
GRANT PRY2205_ROL_D TO PRY2205_EFT_DES;

-- Privilegios para PRY2205_EFT
GRANT CREATE SEQUENCE, CREATE PROCEDURE, CREATE VIEW 
TO PRY2205_ROL_D WITH ADMIN OPTION;

-- Creación usuario PRY2205_EFT_CON
CREATE USER PRY2205_EFT_CON IDENTIFIED BY "ActividadFinal987"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION TO PRY2205_EFT_CON WITH ADMIN OPTION;

-- Otorgar rol PRY2205_ROL_D a PRY2205_USER1
CREATE ROLE PRY2205_ROL_C;
GRANT PRY2205_ROL_C TO PRY2205_EFT_CON;

--------------------------------------------------------------------------------

-- Usuario PRY2205_EFT
SHOW USER;

-- CASO 1
-- Crear sinonimos publicos y privados

-- Sinonimos públicos para CASO 2
CREATE OR REPLACE PUBLIC SYNONYM syndeudor FOR PRY2205_EFT.deudor;
CREATE OR REPLACE PUBLIC SYNONYM synocupacion FOR PRY2205_EFT.ocupacion;
CREATE OR REPLACE PUBLIC SYNONYM syncuota FOR PRY2205_EFT.cuota_tarjetas;
CREATE OR REPLACE PUBLIC SYNONYM syntarjeta FOR PRY2205_EFT.tarjeta_deudor;

-- Grant SELECT sobre tablas de sinonimos publicos CASO 2
GRANT SELECT ON syndeudor TO PRY2205_EFT_DES WITH GRANT OPTION;
GRANT SELECT ON synocupacion TO PRY2205_EFT_DES WITH GRANT OPTION;
GRANT SELECT ON syncuota TO PRY2205_EFT_DES WITH GRANT OPTION;
GRANT SELECT ON syntarjeta TO PRY2205_EFT_DES WITH GRANT OPTION;

-- Sinonimos privados para CASO 3
CREATE OR REPLACE SYNONYM syntrans FOR PRY2205_EFT.transaccion_tarjeta_deudor;
CREATE OR REPLACE SYNONYM synsucursal FOR PRY2205_EFT.sucursal;

-- Grant SELECT sobre tablas de sinonimos privados CASO 3
GRANT SELECT ON syntrans TO PRY2205_EFT WITH GRANT OPTION;
GRANT SELECT ON synsucursal TO PRY2205_EFT WITH GRANT OPTION;


-- CASO 3.1
-- Con usuario PRY2205_EFT
SHOW USER;

-- Creacion de secuencia 
CREATE SEQUENCE SEQ_T_ANALISIS 
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

-- Insertar datos de consulta en tabla T_ANALISIS_TARJETAS
INSERT INTO T_ANALISIS_TARJETAS
SELECT

-- Trigger de secuencia
SEQ_T_ANALISIS .NEXTVAL AS "NUM_ANALISIS", 

-- Numero de tarjeta sin formato
ttd.nro_tarjeta AS "NRO_TARJETA",

-- Total de cuotas transacción
ttd.total_cuotas_transaccion AS "TOTAL_CUOTAS",

-- Monto total de transacción sin formato
ttd.monto_total_transaccion AS "MONTO_TOTAL_TRANSA",

-- Fecha de transaccion
TO_CHAR(ttd.fecha_transaccion, 'DD/MM/YYYY') AS "FECHA_TRANSACCION",

-- Direccion de sucursal, donde se hicieron las transacciones
s.direccion AS "DIRECCION",

-- Monto ajustado de la transacción según reglas de negocio
ROUND(
CASE
WHEN ttd.monto_total_transaccion BETWEEN 200000 AND 300000 THEN ttd.monto_total_transaccion *1.05
WHEN ttd.monto_total_transaccion BETWEEN 300001 AND 500000 THEN ttd.monto_total_transaccion *1.07
ELSE ttd.monto_total_transaccion
END) 
AS "MONTO_REAJUSTADO"

FROM syntrans ttd
JOIN synsucursal s ON ttd.id_sucursal = s.id_sucursal

-- Filtro de dirección por inicial A
WHERE s.direccion LIKE 'A%'
AND ttd.monto_total_transaccion > 200000;

-- EFT Otorga permiso a EFT_CON para seleccion de vista
GRANT SELECT ON T_ANALISIS_TARJETAS TO PRY2205_EFT_CON;


-- CASO 3.2
-- Creación de Index con usuario PRY2205_EFT
SHOW USER;

-- Index para tabla synmedico
CREATE INDEX idx_syntrans   
ON syntrans (nro_tarjeta);

-- La tabla synsucursal ya tiene Index

--------------------------------------------------------------------------------

-- Usuario PRY2205_EFT_DES

-- CASO 2
-- Con usuario EFT_DES
SHOW USER;

-- Creando vista a partir de tablas con sinonimos publicos 
CREATE VIEW VW_ANALISIS_DEUDORES_PERIODO
AS
SELECT 

-- Rut concatenado con DV
TO_CHAR(d.numrun, '99G999G999') ||'-'|| d.dvrun AS "RUT_DEUDOR",

-- Nombre + Apellidos deudor, con iniciales en mayúscula
INITCAP(d.pnombre ||' '|| d.appaterno ||' '|| d.apmaterno) AS "NOMBRE_DEUDOR",

-- Numero de cuotas por tarjeta
COUNT(ct.nro_cuota) AS "TOTAL_CUOTAS",

-- Promedio de cuotas
ROUND(AVG(ct.valor_cuota)) AS "PROMEDIO_VALOR_CUOTAS",
  
-- Fecha de vencimiento de cuota mas antigua
TO_CHAR(MIN(ct.fecha_venc_cuota), 'DD-MM-YYYY') AS "FECHA_MAS_ANTIGUA",

-- Numero de contacto con mensaje de nulos
NVL(TO_CHAR(d.fono_contacto), 'Sin Información') AS "TELÉFONO",

-- Nombre de profesión en mayúsculas
UPPER(o.nombre_prof_ofic) AS "OCUPACION",

-- Cupo disponible en tarjeta asociada
td.cupo_disp_compra AS "CUPO_DISP_COMPRA" 

FROM syndeudor d
JOIN syntarjeta td ON d.numrun = td.numrun 
JOIN syncuota ct ON td.nro_tarjeta = ct.nro_tarjeta 
JOIN synocupacion o ON d.cod_ocupacion = o.cod_ocupacion

-- Filtro de profesiones por palabra Ingeniero
WHERE o.nombre_prof_ofic NOT LIKE '%Ingeniero%'
-- Fechas por año pasado
AND EXTRACT(YEAR FROM ct.fecha_venc_cuota) = EXTRACT(YEAR FROM SYSDATE) -1

GROUP BY d.numrun, d.dvrun, d.pnombre, d.appaterno, d.apmaterno, 
d.fono_contacto, o.nombre_prof_ofic, td.cupo_disp_compra

-- Subconsulta:
-- Promedio de cuotas es inferior al máximo de cuotas, de todas las tarjetas
HAVING ROUND(AVG(ct.valor_cuota)) < 
(SELECT MAX(ROUND(AVG(valor_cuota))) FROM syncuota
GROUP BY nro_tarjeta);

-- EFT_DES Otorga permiso a EFT_CON para seleccion de vista
GRANT SELECT ON VW_ANALISIS_DEUDORES_PERIODO TO PRY2205_EFT_CON;

--------------------------------------------------------------------------------

-- Usuario PRY2205_EFT_CON

-- CASO 2 
-- Select de vista con order by para EFT_CON
-- Mostrar Usuario
SHOW USER;
-- Consulta
SELECT * FROM PRY2205_EFT_DES.VW_ANALISIS_DEUDORES_PERIODO 
ORDER BY "TOTAL_CUOTAS", "CUPO_DISP_COMPRA";

-- CASO 3.1
-- Select de vista con Order By para EFT_CON
-- Mostrar Usuario
SHOW USER;
-- Consulta
SELECT * FROM PRY2205_EFT.T_ANALISIS_TARJETAS
ORDER BY "NRO_TARJETA", "MONTO_REAJUSTADO" DESC;
