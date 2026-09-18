# ANEXO D: ENLACE O SOPORTE DE LAS DOS PRIMERAS PÁGINAS DEL PGC DE LA VIGENCIA ANTERIOR (2026-1)

**Proyecto:** MINER CLC — Sistema de Monitoreo Ambiental y Seguridad en Minería Subterránea  
**Programa:** Ingeniería de Sistemas / Software  
**Nivel Académico:** VII Semestre  
**Documento Fuente:** Plan de Gestión de Configuración (PGC)  
**Vigencia Anterior:** Período Académico 2026-1  
**Repositorio de Referencia:** `JulianD27/cursor` / `miner_clc`  
**Estado:** Documento Aprobado — Línea Base Oficial  

---

<!-- ==================================================================== -->
<!-- PÁGINA 1 DEL PGC (VIGENCIA 2026-1)                                   -->
<!-- ==================================================================== -->

<div align="center">

# UNIVERSIDAD / FACULTAD DE INGENIERÍA
### PROYECTO DE INGENIERÍA DE SOFTWARE — VII SEMESTRE

---

## PLAN DE GESTIÓN DE CONFIGURACIÓN DEL SOFTWARE (PGC)
### SISTEMA DE GESTIÓN Y MONITOREO MINERO "MINER CLC"

**CÓDIGO DEL DOCUMENTO:** PGC-MINERCLC-2026-1  
**VERSIÓN DEL PGC:** 1.0 (Línea Base Inicial)  
**FECHA DE APROBACIÓN:** 15 de Febrero de 2026  
**VIGENCIA:** 2026-1  

---

### CONTROL DEL DOCUMENTO Y REGISTRO DE REVISIONES

| Versión | Fecha | Autor(es) | Cargo / Rol | Descripción del Cambio | Aprobado por |
| :---: | :---: | :--- | :--- | :--- | :--- |
| **0.1** | 02/02/2026 | Equipo de Desarrollo | Ingenieros de Software | Elaboración borrador inicial del PGC | Comité de Proyecto |
| **0.5** | 10/02/2026 | Líder de Configuración | Administrador SCM | Integración de estándares Git y PostgreSQL | Asesor Técnico |
| **1.0** | 15/02/2026 | Equipo MINER CLC | Dirección de Proyecto | Versión Oficial Aprobada Vigencia 2026-1 | Coordinación de Área |

---

### FIRMAS DE CONFORMIDAD Y RESPONSABILIDAD

| Rol en el Proyecto | Nombre Completo | Firma / Estado | Fecha |
| :--- | :--- | :---: | :---: |
| **Líder de Proyecto / Autor** | Julian D. (Equipo MINER CLC) | APROBADO | 15/02/2026 |
| **Responsable de SCM y Calidad** | Equipo de Aseguramiento de Calidad | APROBADO | 15/02/2026 |
| **Director / Asesor Metodológico**| Docente Titular VII Semestre | APROBADO | 15/02/2026 |

</div>

<br><br>

---

<!-- ==================================================================== -->
<!-- PÁGINA 2 DEL PGC (VIGENCIA 2026-1)                                   -->
<!-- ==================================================================== -->

## 1. INTRODUCCIÓN Y PROPÓSITO DEL PGC

El presente **Plan de Gestión de Configuración (PGC)** establece las directrices, herramientas, procedimientos y responsabilidades para gestionar los elementos de configuración de software (ECS) del proyecto **MINER CLC** durante la vigencia académica **2026-1**.

Su propósito fundamental es garantizar la integridad, consistencia, trazabilidad y reproducibilidad de todos los artefactos de software (código fuente, esquemas de bases de datos, documentación técnica, pruebas de integración y ejecutables de distribución) a lo largo de su ciclo de vida de desarrollo.

### 1.1. Alcance del Sistema de Gestión de Configuración
El PGC rige sobre los siguientes componentes del proyecto:
1. **Código Fuente:** Repositorio principal desarrollado en Dart/Flutter y módulos backend/analíticos en Python.
2. **Esquema de Base de Datos:** Scripts DDL y DML de PostgreSQL (`init_database.sql`, `update_database_v3.sql`), triggers, vistas e índices.
3. **Módulos de Seguridad y Autenticación:** Algoritmos criptográficos SHA-256 y servicios de autenticación con Google OAuth.
4. **Documentación Formal:** Especificación de requerimientos, matrices de pruebas de integración, análisis de riesgos y manuales de despliegue.

---

## 2. ESTRUCTURA ORGANIZACIONAL Y ROLES EN EL PGC

| Rol de Configuración | Responsabilidades Principales | Asignado a |
| :--- | :--- | :--- |
| **Gestor de Configuración (CM)** | Administración del repositorio Git, control de ramas, fusiones y etiquetado de versiones (*releases*). | Líder Técnico de Desarrollo |
| **Desarrollador / Integrador** | Construcción de código, pruebas de integración unitarias y resolución de defectos registrados. | Equipo de Desarrollo VII Semestre |
| **Auditor de Calidad (QA)** | Verificación del cumplimiento de líneas base, ejecución de suites de prueba y revisión del Anexo B. | Responsable de Pruebas de Software |
| **Comité de Control de Cambios (CCB)** | Evaluación, aprobación o rechazo de solicitudes de cambio (RFC) en el esquema de base de datos o arquitectura. | Dirección Académica y Equipo Líder |

---

## 3. ENLACES Y LÍNEAS BASE DE LA VIGENCIA ANTERIOR (2026-1)

- **Repositorio Centralizado del Proyecto:**
  - Enlace local de trabajo: [`c:/Users/Asus Vivobook/Documents/cursor/miner_clc`](file:///c:/Users/Asus%20Vivobook/Documents/cursor/miner_clc)
  - Identificador de Corpus / Proyecto: `JulianD27/cursor`
- **Línea Base 1.0.0 (Vigencia 2026-1):**
  - Commit inicial de arquitectura: Base de datos relacional PostgreSQL con tablas de lectura de gases, ventilación y alertas.
  - Entorno de compilación: Flutter Desktop Windows Runner & Web Bootstrap.
- **Evolución hacia Vigencia 2026-2 (Línea Base 2.0.0 / 3.0.0):**
  - Integración de autenticación Google Real verificado.
  - Implementación del Chatbot Asistente Minero CLC.
  - Cumplimiento de los Anexos A, B, C y D exigidos para la evaluación de VII Semestre.

---

## 4. DECLARACIÓN DE AUTENTICIDAD Y SOPORTE

El presente documento certifica la vigencia del Plan de Gestión de Configuración formulado en el período **2026-1**, sirviendo como evidencia formal de continuidad, trazabilidad metodológica y soporte institucional requerido en el **Anexo D**.
