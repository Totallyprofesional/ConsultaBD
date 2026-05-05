-- Usando Oracle XE, comando para crear usuarios
ALTER SESSION SET CONTAINER = XEPDB1;

-- CASO 1
-- Crear usuarios, asignar roles y privilegios

-- Creación PRY2205_USER1
CREATE USER PRY2205_USER1 IDENTIFIED BY "Usuario12345"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION TO PRY2205_USER1 WITH ADMIN OPTION;

-- Otorgar rol PRY2205_ROL_D a PRY2205_USER1
CREATE ROLE PRY2205_ROL_D;
GRANT PRY2205_ROL_D TO PRY2205_USER1;

-- Privilegios para rol PRY2205_ROL_D 
GRANT CREATE TABLE, CREATE VIEW, CREATE SYNONYM, CREATE PUBLIC SYNONYM 
TO PRY2205_ROL_D WITH ADMIN OPTION;

-- Creación PRY2205_USER2
CREATE USER PRY2205_USER2 IDENTIFIED BY "Usuario32154"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP 
QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION TO PRY2205_USER2 WITH ADMIN OPTION;

-- Otorgar rol PRY2205_ROL_P a PRY2205_USER2
CREATE ROLE PRY2205_ROL_P;
GRANT PRY2205_ROL_P TO PRY2205_USER2;

-- Privilegios para PRY2205_ROL_P
GRANT CREATE VIEW, CREATE PROFILE, CREATE USER
TO PRY2205_ROL_P WITH ADMIN OPTION;


-- Caso 2

-- Creación sinonimos públicos con PRY2205_USER1
CREATE OR REPLACE PUBLIC SYNONYM synpaciente FOR PRY2205_USER1.paciente;
CREATE OR REPLACE PUBLIC SYNONYM synsalud FOR PRY2205_USER1.salud;
CREATE OR REPLACE PUBLIC SYNONYM synbono FOR PRY2205_USER1.bono_consulta;

-- Permisos a sinonimos publicos especificos para Caso 2
GRANT SELECT ON PRY2205_USER1.paciente TO PRY2205_USER2;
GRANT SELECT ON PRY2205_USER1.salud TO PRY2205_USER2;
GRANT SELECT ON PRY2205_USER1.bono_consulta TO PRY2205_USER2;


-- Caso 3

-- Creación sinonimos privados con PRY2205_USER1
CREATE OR REPLACE SYNONYM synmedico FOR PRY2205_USER1.medico;
CREATE OR REPLACE SYNONYM syncargo FOR PRY2205_USER1.cargo;

-- Permisos para sinonimos privados
GRANT SELECT ON PRY2205_USER1.medico TO PRY2205_USER1;
GRANT SELECT ON PRY2205_USER1.cargo TO PRY2205_USER1;

--------------------------------------------------------------------------------

-- CASO 2
-- consulta con PRY2205_USER2 
-- solo puede acceder a sinonimos publicos específicos

-- Crear tabla vista VW_RECALCULO_COSTOS    
CREATE VIEW VW_RECALCULO_COSTOS
AS
SELECT 

-- Rut concatenados con DV
TO_CHAR(p.pac_run, '99G999G999') ||'-'|| p.dv_run AS "RUT_PACIENTE",

-- Nombres concatenados en mayúscula, desde apellido paterno, materno y primer nombre 
UPPER(p.apaterno ||' '|| p.amaterno ||' '|| p.pnombre) AS "NOMBRE_PACIENTE",
 
-- Nombre de sistema de salud
s.descripcion AS "SISTEMA_SALUD",

TO_CHAR(NVL(bc.costo, 0), '$99G999') AS "COSTO",

-- Hora de consulta
bc.hr_consulta AS "HORARIO ATENCION",

-- Fecha de bono formateado a mes y año
TO_CHAR(bc.fecha_bono, 'MM-YYYY') AS "FECHA_CONSULTA",

-- Calculo de reajustes para sueldos, con CASE para distintos casos
TO_CHAR(
CASE
WHEN bc.costo BETWEEN 15000 AND 25000 THEN bc.costo * 1.15
WHEN bc.costo > 25000 THEN bc.costo * 1.20
ELSE bc.costo
END, '$99G999') AS "REAJUSTE"

FROM synpaciente p
-- Subconsulta para trabajar con datos específicos de tabla salud
JOIN (SELECT sal_id, descripcion, tipo_sal_id FROM synsalud 
WHERE tipo_sal_id IN('I', 'F')) s on p.sal_id = s.sal_id
JOIN synbono bc ON p.pac_run = bc.pac_run

-- Filtros para año y horas de atención
WHERE EXTRACT(YEAR FROM bc.fecha_bono) = EXTRACT(YEAR FROM SYSDATE) -1
AND bc.hr_consulta > '17:15';

-- Revisar vista construida con PRY2205_USER2
SELECT * FROM VW_RECALCULO_COSTOS
ORDER BY "FECHA_CONSULTA", "RUT_PACIENTE";

-- DROP VIEW para pruebas de construcción de vista
-- DROP VIEW VW_RECALCULO_COSTOS;

--------------------------------------------------------------------------------

-- CASO 3
-- Construcción con PRY2205_USER1 

-- Creacion de vista editable 
CREATE VIEW VW_AUM_MEDICO_X_CARGO
AS
SELECT 

-- Rut concatenado con dv y formateado
TO_CHAR(m.rut_med, '99G999G999') ||'-'|| m.dv_run AS "RUT_MEDICO",

-- Nombre de cargo médico
c.nombre AS "CARGO",

-- Sueldo formateado 
TO_CHAR(sueldo_base, '$9G999G999') AS "SUELDO ACTUAL",

-- Aumento de sueldo con porcentaje
TO_CHAR(sueldo_base *1.15, '$9G999G999') AS "SUELDO_AUMENTADO"

FROM synmedico m
JOIN syncargo c ON m.car_id = c.car_id

-- Filtro de cargos médicos que contienen la palabra "atención"
WHERE c.nombre LIKE '%atención%';

-- Ver vista creada
SELECT * FROM VW_AUM_MEDICO_X_CARGO
ORDER BY "SUELDO_AUMENTADO" DESC;

-- DROP VIEW para pruebas de vista
-- DROP VIEW VW_AUM_MEDICO_X_CARGO;

-- Creación de Index 
-- con usuario PRY2205_USER1 

-- Index para tabla synmedico
CREATE INDEX idx_synmedico
ON synmedico (car_id);

-- Index para tabla syncargo
CREATE INDEX idx_syncargo
ON syncargo (car_id, nombre);