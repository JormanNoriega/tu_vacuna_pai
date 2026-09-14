# Formato Digital de Registro Diario PAI - Especificación de campos

> Documento base extraído del archivo `mi_vacuna_Formato digital de registro diario 2026 - este si.xlsm`.
> Fuente: **Ministerio de Salud y Protección Social - Dirección de Promoción y Prevención - Programa Ampliado de Inmunizaciones (PAI)**.
> Su objetivo es servir de insumo para definir los campos que se recolectan en las vistas **Registrar Paciente** y **Registrar Vacuna**.

---

## 1. Resumen de hojas del libro

| Hoja | Filas x Columnas | Contenido |
| --- | --- | --- |
| `Instructivos` | 109 x 5 | Diccionario de variables: nombre, tipo de campo, obligatoriedad y descripción de diligenciamiento. |
| `Registro Diario` | 10000 x 279 | Tabla de registro. Fila 1 = grupo/sección, Fila 2 = encabezado de columna, Fila 3+ = datos. |
| `Validador` | 1150 x 227 | Listas de valores para listas desplegables (sexo, género, etnia, régimen, tipo de identificación, municipios, jeringas, etc.). |

---

## 2. Hoja `Instructivos` - Diccionario de variables

Columnas del instructivo: **Variable**, **Tipo de Campo**, **Obligatoriedad** (SI / NO / N/A) y **Descripción del Diligenciamiento**.

### Registro

| Variable | Tipo de Campo | Obligatorio | Descripción del Diligenciamiento |
| --- | --- | --- | --- |
| Consecutivo | Numero | SI | Registre en orden de menor a mayor de acuerdo al consecutivo los usuarios vacunados |
| Fecha de atención formato de fecha en números (día/mes/año)* | Fecha | SI | Registre la fecha de la aplicación del biológico de la persona vacunada. La estructura para el registro de la fecha es día/mes/año. |

### Datos Básicos

| Variable | Tipo de Campo | Obligatorio | Descripción del Diligenciamiento |
| --- | --- | --- | --- |
| Tipo de identificación* | Selección | SI | Seleccione el tipo de identificación de la persona vacunada. CN: certificado de nacido vivo,  RC: Registro civil, TI:Tarjeta de Identidad, CC: Cédula de ciudadanía, AS: adulto sin identificación, MS: Menor sin identificación, CE: Cédula de extranjería, PA: Pasaporte, CD: Carné diplomático, SC: Salvoconducto, PE: Permiso especial de permanencia, PPT: Permiso por protección temporal  DE: documento extranjero |
| Número de identificación* | Numero | SI | Registre el número de identificación de la persona vacunada, de acuerdo al tipo de identificación. |
| Primer nombre* | Texto | SI | Registre el primer nombre de la persona vacunada. Diligencie completo  en letra mayúscula |
| Segundo nombre | Texto | NO | Registre el segundo nombre de la persona vacunada. Diligencie  completo  en letra mayúscula. |
| Primer apellido* | Texto | SI | Registre el primer apellido de la persona vacunada. Diligencie  completo  en letra mayúscula |
| Segundo apellido | Texto | NO | Registre el segundo apellido de la persona vacunada. Diligencie  completo  en letra mayúscula. |
| Fecha de nacimiento Formato de fecha en números (día/mes/año)* | Fecha | SI | Registre la fecha de nacimiento de la persona vacunada de acuerdo a la estructura:  día/mes/año. |
| AÑOS | Formulado | N/A | Formulado de acuerdo a la fecha de nacimiento |
| MESES | Formulado | N/A | Formulado de acuerdo a la fecha de nacimiento |
| DIAS | Formulado | N/A | Formulado de acuerdo a la fecha de nacimiento |
| Total meses | Formulado | N/A | Formulado de acuerdo a la fecha de nacimiento |
| Esquema completo | Selección | SI | Seleccione Si o No si la persona vacunada cuenta con el esquema completo para la edad. |

### Datos Complementarios

| Variable | Tipo de Campo | Obligatorio | Descripción del Diligenciamiento |
| --- | --- | --- | --- |
| Sexo* | Selección | SI | Seleccione la opción, de acuerdo con las características biológicas o fisiológicas de la persona vacunada. |
| Género | Selección | NO | Seleccione la opción, de acuerdo a cómo se identifique el usuario vacunado. |
| Orientación sexual | Selección | NO | Seleccione la opción, de acuerdo a cómo se identifique el usuario vacunado. |
| Edad gestacional (semanas) | Numero | SI | Diligencie en número las semanas de edad gestacional al momento de nacer el menor vacunado. No aplica para adultos. |
| País de nacimiento* | Selección | SI | Seleccione  el país de nacimiento de la persona vacunada. |
| Estatus Migratorio* | Formulado | N/A | De acuerdo a la condición migratoria de personas extranjeras, registre  REGULAR si cumple con las autorizaciones vigentes para permanecer en el país de lo contrario registre como  IRREGULAR |
| Lugar de atención del parto* (Hospital) | Formulado | N/A | Registre el nombre de la institución del lugar de atención del parto. Aplica para los menores de edad. Diligencie  completo  en letra mayúscula. |
| Régimen de afiliación* | Selección | SI | Seleccione el régimen de afiliación de la persona vacunada. |
| Aseguradora * | Selección | SI | Registre el nombre de la aseguradora a la cual esta afiliada la persona vacunada. |
| Pertenencia étnica* | Selección | SI | Seleccione el grupo étnico con el cual se identifica la persona vacunada. |
| Desplazado* | Selección | SI | Seleccione la opción  Si o No, de acuerdo a la situación referenciada de la persona vacunada. |
| Discapacitado* | Selección | SI | Seleccione la opción Si o No,  de acuerdo a la condición de discapacidad referenciada de la persona vacunada. |
| Fallecido* | Selección | SI | Seleccione la opción Si o No, en el momento en que se realiza la actualización de la información de la persona vacunada |
| Víctima del conflicto armado* | Selección | SI | Seleccione la opción Si o No,  de acuerdo a lo informado por la persona vacunada. |
| Estudia actualmente* | Selección | SI | Seleccione la opción Si o No, de acuerdo a lo informado por la persona vacunada. |
| País de residencia* | Selección | SI | Seleccione la opción de acuerdo al  país de residencia de la persona vacunada. |
| Departamento de residencia* | Selección | SI | Seleccione la opción de acuerdo a la opción de lista desplegable. |
| Municipio de residencia* | Selección | SI | Seleccione la opción de acuerdo a la opción de lista desplegable. |
| Comuna/Localidad | Texto | NO | Registre el nombre de la comuna o localidad de residencia de la persona vacunada. |
| Área* | Selección | SI | Seleccione la opción de acuerdo a la opción de lista desplegable Urbano o Rural. |
| Dirección con nomenclatura | Texto | SI | Registre la dirección de residencia de la persona vacunada. |
| indicativo + Teléfono fijo | Numero | SI | Registre el número de teléfono fijo de contacto de la persona vacunada. |
| Celular | Numero | SI | Registre el número de teléfono celular de contacto de la persona vacunada. Si no se tiene el dato deje la casilla en blanco. |
| Email | Texto | NO | Registre el correo electrónico de la persona vacunada. Si no se tiene el dato deje la casilla en blanco. |
| ¿Autoriza llamadas teléfonicas? * | Selección | SI | Al ubicarse en la casilla va encontrar el icono de flecha, en el cual debe dar click y seleccionar la opción Si o No, de acuerdo a la información suministrada de la persona vacunada. |
| ¿Autoriza envío de correo? * | Selección | SI | Al ubicarse en la casilla va encontrar el icono de flecha, en el cual debe dar click y seleccionar la opción Si o No, de acuerdo a la información suministrada de la persona vacunada. |

### Antecedentes Médicos

| Variable | Tipo de Campo | Obligatorio | Descripción del Diligenciamiento |
| --- | --- | --- | --- |
| ¿Sufre o ha sufrido algún evento o enfermedad que contraindique la vacunación?* | Selección | SI | Seleccionar la opción Si o No, de acuerdo a la información suministrada de la persona vacunada. |
| Cual | Texto | NO | Si en la casilla anterior registró "Si", debe seleccionar la enfermedad relacionada en la lista desplegable |
| ¿Ha presentado reacción moderada o severa a biológicos anteriores?* | Selección | SI | Seleccionar la opción Si o No, de acuerdo a la información suministrada de la persona vacunada. |
| Cual | Texto | NO | Si en la casilla anterior registró "Si", debe seleccionar los sintomas que haya presentado la persona vacunada, de la lista desplegable. |

### CONDICION USUARIA

| Variable | Tipo de Campo | Obligatorio | Descripción del Diligenciamiento |
| --- | --- | --- | --- |
| CONDICION USUARIA | Selección | NO | Esta opción se habilita para usuarias a partir de los 9 años de edad en los registros seleccionados con "sexo" mujer. |
| Gestante Fecha de última menstruación | Fecha | NO | Si la condición de la usuaria es  "gestante", registre la fecha del última menstruación. La estructura para el registro de la fecha es día/mes/año. |
| Semanas de gestación | Formulado | N/A | Formulado de acuerdo a la fecha de ultima menstruación |
| Fecha probable de parto | Formulado | N/A | Formulado de acuerdo a la fecha de ultima menstruación |
| Cantidad de embarazos previos | Selección | NO | Seleccionar la opción del número de embarazos previos que haya tenido la persona vacunada. |

### Histórico de antecedentes

| Variable | Tipo de Campo | Obligatorio | Descripción del Diligenciamiento |
| --- | --- | --- | --- |
| Fecha de registro del antecedente | Fecha | NO | Diligencie la fecha en que se presentó el antecedente en el formato dia/mes/año |
| Tipo | Texto | NO | Si se registró un antecedente de salud de la persona vacunada, debe escribir el tipo o nombre |
| Descripción | Texto | NO | Si en la opción de antecedentes médicos registro SI algún tipo de enfermedad o reacción a biológicos anteriores, regsitrela, ejm Enfermedad: Encefalopatía, cancer, inmunosupresión, neoplasia, etc, Reacción: Convulsión, edema, irritación etc. |
| Observaciones especiales | Texto | NO | Si es necesario conocer recomendaciones para posteriores atenciones en salud. |

### Datos de la Madre

| Variable | Tipo de Campo | Obligatorio | Descripción del Diligenciamiento |
| --- | --- | --- | --- |
| Tipo de identificación | Selección | SI | Registre el tipo de identificación de la madre del menor vacunado. Al ubicarse en la casilla va encontrar el icono de flecha, en el cual debe dar click y seleccionar el tipo de identificación de acuerdo al registro presentado o indicado de por la persona vacunada. CN: certificado de nacido vivo,  RC: Registro civil, TI:Tarjeta de Identidad, CC: Cédula de ciudadanía, AS: adulto sin identificación, MS: Menor sin identificación, CE: Cédula de extranjería, PA: Pasaporte, CD: Carné diplomático, SC: Salvoconducto, PE: Permiso especial de permanencia, PPT: Permiso por protección temporal  DE: documento extranjero |
| Número de identificación* | Numero | SI | Registre el número de identificación de la madre del menor vacunado, de acuerdo al tipo de identificación. |
| Primer nombre* | Texto | SI | Registre el primer nombre de la madre del menor vacunado. Diligencie todo el nombre en letra mayúscula. |
| Segundo nombre | Texto | NO | Registre el segundo nombre de la madre del menor vacunado, si no tiene segundo nombre deje la casilla en blanco. Si registra el nombre diligencie todo en letra mayúscula. |
| Primer apellido* | Texto | SI | Registre el segundo nombre de la madre del menor vacunado, si no tiene segundo nombre deje la casilla en blanco. Si registra el nombre diligencie todo en letra mayúscula. |
| Segundo apellido | Texto | NO | Registre el segundo apellido de la madre del menor vacunado, si no tiene segundo apellido deje la casilla en blanco. Si registra el apellido diligencie todo en letra mayúscula. |
| Correo electrónico* | Texto | NO | Registre el correo electrónico de la madre del menor vacunado. |
| indicativo + Teléfono fijo | Numero | SI | Registre el número de teléfono fijo de contacto de la madre del menor vacunado. Si no se tiene el dato deje la casilla en blanco. |
| Celular | Numero | SI | Registre el número de teléfono celular de contacto de la madre del menor vacunado. Si no se tiene el dato deje la casilla en blanco. |
| Régimen de afiliación* | Selección | SI | Al ubicarse en la casilla va encontrar el icono de flecha, en el cual debe dar click y seleccionar el régimen de afiliación de la madre del menor vacunado. |
| Pertenencia étnica* | Selección | SI | Al ubicarse en la casilla va encontrar el icono de flecha, en el cual debe dar click y seleccionar el grupo étnico con el cual se identifica la madre del menor vacunado. |
| Desplazado* | Selección | SI | Al ubicarse en la casilla va encontrar el icono de flecha, en el cual debe dar click y seleccionar la opción de Si o No de acuerdo a la situación referenciada por la madre del menor vacunado. |

### Datos del cuidador

| Variable | Tipo de Campo | Obligatorio | Descripción del Diligenciamiento |
| --- | --- | --- | --- |
| Tipo de identificación | Selección | SI | Registre el tipo de identificación del cuidador del menor vacunado. Al ubicarse en la casilla va encontrar el icono de flecha, en el cual debe dar click y seleccionar el tipo de identificación de acuerdo al registro presentado o indicado de por la persona vacunada. CN: certificado de nacido vivo,  RC: Registro civil, TI:Tarjeta de Identidad, CC: Cédula de ciudadanía, AS: adulto sin identificación, MS: Menor sin identificación, CE: Cédula de extranjería, PA: Pasaporte, CD: Carné diplomático, SC: Salvoconducto, PE: Permiso especial de permanencia, PPT: Permiso por protección temporal  DE: documento extranjero |
| Número de identificación* | Numero | SI | Registre el número de identificación del cuidador del menor vacunado, de acuerdo al tipo de identificación. |
| Primer nombre* | Texto | SI | Registre el primer nombre de la madre del menor vacunado. Diligencie todo el nombre en letra mayúscula. |
| Segundo nombre | Texto | NO | Registre el segundo nombre del cuidador del menor vacunado, si no tiene segundo nombre deje la casilla en blanco. Si registra el nombre diligencie todo en letra mayúscula. |
| Primer apellido* | Texto | SI | Registre el segundo nombre del cuidador del menor vacunado, si no tiene segundo nombre deje la casilla en blanco. Si registra el nombre diligencie todo en letra mayúscula. |
| Segundo apellido | Texto | NO | Registre el segundo apellido de la madre del menor vacunado, si no tiene segundo apellido deje la casilla en blanco. Si registra el apellido diligencie todo en letra mayúscula. |
| Parentesco* | Texto | NO | Registre el parentesco del cuidador del menor vacunado. |
| Correo electrónico* | Texto | NO | Registre el correo electrónico del cuidador del menor vacunado. |
| indicativo + Teléfono fijo | Numero | SI | Registre el número de teléfono fijo de contacto del cuidador del menor vacunado. |
| Celular | Numero | SI | Registre el número de teléfono celular de contacto del cuidador del menor vacunado. |

### ESQUMA DE VACUNACION

| Variable | Tipo de Campo | Obligatorio | Descripción del Diligenciamiento |
| --- | --- | --- | --- |
| TIPO DE CARNET | Selección | SI | Seleccionar la opción del tipo de carné que esta revisando. |

### BIOLOGICO

| Variable | Tipo de Campo | Obligatorio | Descripción del Diligenciamiento |
| --- | --- | --- | --- |
| Dosis | Selección | SI | Seleccionar la opción la dosis correspondiente del biológico aplicado a la personada vacunada. |
| Laboratorio | Selección | SI | Registre el laboratorio correspondiente del biológico aplicado a la persona vacunada, diligencie todo en letra mayúscula |
| Lote | Texto | SI | Registre el lote correspondiente del biológico aplicado a la persona vacunada, diligencie todo en letra mayúscula |
| Jeringa | Selección | SI | Seleccione  la opción del calibre de la jeringa utilizada para la aplicación del biológico a la persona vacunada. |
| Lote Jeringa | Texto | SI | Registre el lote correspondiente del biológico aplicado a la persona vacunada, diligencie todo en letra mayúscula. |
| Lote Diluyente | Texto | SI | Registre el lote correspondiente de la jeringa utilizada para la aplicación del biológico a la persona vacunada, diligencie todo en letra mayúscula. |

### RESPONSABLE (NOMBRE DEL VACUNADOR)

| Variable | Tipo de Campo | Obligatorio | Descripción del Diligenciamiento |
| --- | --- | --- | --- |
| RESPONSABLE (NOMBRE DEL VACUNADOR) | Texto | SI | Diligencie el nombre de la persona que aplicó la vacuna. |

### EL REGISTRO FUE INGRESADO AL APLICATIVO PAI

| Variable | Tipo de Campo | Obligatorio | Descripción del Diligenciamiento |
| --- | --- | --- | --- |
| EL REGISTRO FUE INGRESADO AL APLICATIVO PAI | Texto | SI | Relacione si el registro ya fue ingresado al aplicativo PAIWEB, registre Si o No de acuerdo al caso. |

### MOTIVO DE NO INGRESO

| Variable | Tipo de Campo | Obligatorio | Descripción del Diligenciamiento |
| --- | --- | --- | --- |
| MOTIVO DE NO INGRESO | Texto | SI | En caso de no haber ingresado el registro al aplicativo PAIWEB, registre la causa por la cual no se ha ingresado. |

### OBSERVACIONES

| Variable | Tipo de Campo | Obligatorio | Descripción del Diligenciamiento |
| --- | --- | --- | --- |
| OBSERVACIONES | Texto | SI | Si se presenta alguna novedad u observación frente al proceso de vacunación, registre  la observación. |

### Otros formatos incluidos en el instructivo

- Arqueo diario | Mes y año | Selección | SI | Seleccione en la lista desplegable el mes y año correspondiente
- Biológico/arqueo | Visualizado | SI | Registre la información por cada biológico, jeringa o insumo con existencias en físico
- C 69 - C80 | Texto | SI | Registre los datos correspondientes de acuerdo a las convenciones:
- Total | Formulado | SI | Se totalizan los datos que fueron registrados durante el periodo
#### FORMATO REPORTE MENSUAL

- Régimen/ Grupo étnico | Desagregado por tipo de sexo, régimen y étnias | Número | SI | Ingrese los valores correspondientes al total de la poblaicón vacunada de acuerdo al biológico
#### FORMATO TEMPERATURA REFRIGERADOR

- Nombre de quien registra | Mañana y tarde | Texto | SI | Diligencie con el nombre completo de quien registra la temperatura
- Nombre de quie revisa | Semanal | Texto | SI | Registre el nombre completo de quien supervisa la  toma y el registro de la  temperatura
- Columnas BC - 104 | Mañana y tarde | Gráfico | SI | Registre la temperatura  de acuerdo al día y turno en que se realizó la toma
- Temperatura | Mañana y tarde | Formulado | SI | Revise de acuerdo a la gráfica, los rangos de temperatura históricos y actuales como parte del seguimiento diario y el turno correspondiente

---

## 3. Hoja `Registro Diario` - Estructura de columnas

- **Fila 1**: agrupador / sección (celdas combinadas).
- **Fila 2**: nombre del campo a registrar.
- **Fila 3 en adelante**: datos diligenciados (un registro por fila = un evento de vacunación de un paciente).

### 3.1 Bloque de identificación y datos del paciente (columnas A - BX)

#### Datos básicos / identificación

| Col | Campo | Agrupador fila 1 |
| --- | --- | --- |
| A | Consecutivo | (sin grupo) |
| B | Fecha de atención formato de fecha en números (día/mes/año)* | (sin grupo) |
| C | Tipo de identificación* | DATOS BÁSICOS |
| D | Número de identificación* | DATOS BÁSICOS |
| E | Primer nombre* | DATOS BÁSICOS |
| F | Segundo nombre | DATOS BÁSICOS |
| G | Primer apellido* | DATOS BÁSICOS |
| H | Segundo apellido | DATOS BÁSICOS |
| I | Fecha de nacimiento  Formato de fecha en números (día/mes/año)* | DATOS BÁSICOS |
| J | AÑOS | DATOS BÁSICOS |
| K | MESES | DATOS BÁSICOS |
| L | DIAS | DATOS BÁSICOS |
| M | Total meses | DATOS BÁSICOS |
| N | Esquema completo | DATOS BÁSICOS |

#### Datos complementarios

| Col | Campo | Agrupador fila 1 |
| --- | --- | --- |
| O | Sexo* | DATOS COMPLEMENTARIOS |
| P | Género | DATOS COMPLEMENTARIOS |
| Q | Orientación sexual | DATOS COMPLEMENTARIOS |
| R | Edad gestacional (semanas) | DATOS COMPLEMENTARIOS |
| S | País de nacimiento* | DATOS COMPLEMENTARIOS |
| T | Estatus Migratorio* | DATOS COMPLEMENTARIOS |
| U | Lugar de atención del parto* (Hospital) | DATOS COMPLEMENTARIOS |
| V | Régimen de afiliación* | DATOS COMPLEMENTARIOS |
| W | Aseguradora * | DATOS COMPLEMENTARIOS |
| X | Pertenencia étnica* | DATOS COMPLEMENTARIOS |
| Y | Desplazado* | DATOS COMPLEMENTARIOS |
| Z | Discapacitado* | DATOS COMPLEMENTARIOS |
| AA | Fallecido* | DATOS COMPLEMENTARIOS |
| AB | Víctima del conflicto armado* | DATOS COMPLEMENTARIOS |
| AC | Estudia actualmente* | DATOS COMPLEMENTARIOS |
| AD | País de residencia* | DATOS COMPLEMENTARIOS |
| AE | Departamento de residencia* | DATOS COMPLEMENTARIOS |
| AF | Municipio de residencia* | DATOS COMPLEMENTARIOS |
| AG | Comuna/Localidad | DATOS COMPLEMENTARIOS |
| AH | Área* | DATOS COMPLEMENTARIOS |
| AI | Dirección con nomenclatura | DATOS COMPLEMENTARIOS |
| AJ | indicativo + Teléfono fijo | DATOS COMPLEMENTARIOS |
| AK | Celular | DATOS COMPLEMENTARIOS |
| AL | Email | DATOS COMPLEMENTARIOS |
| AM | ¿Autoriza llamadas teléfonicas? * | DATOS COMPLEMENTARIOS |
| AN | ¿Autoriza envío de correo? * | DATOS COMPLEMENTARIOS |

#### Antecedentes médicos

| Col | Campo | Agrupador fila 1 |
| --- | --- | --- |
| AO | ¿Sufre o ha sufrido algún evento o enfermedad que contraindique la vacunación?* | ANTECEDENTES MEDICOS |
| AP | Cuál | ANTECEDENTES MEDICOS |
| AQ | ¿Ha presentado reacción moderada o severa a biológicos anteriores?* | ANTECEDENTES MEDICOS |
| AR | Cuál | ANTECEDENTES MEDICOS |

#### Condición de la usuaria

| Col | Campo | Agrupador fila 1 |
| --- | --- | --- |
| AS | Condición de la usuaria | CONDICION USUARIA |
| AT | Gestante Fecha de última menstruación | CONDICION USUARIA |
| AU | Semanas de gestación | CONDICION USUARIA |
| AV | Fecha probable de parto | CONDICION USUARIA |
| AW | Cantidad de embarazos previos | CONDICION USUARIA |

#### Histórico de antecedentes

| Col | Campo | Agrupador fila 1 |
| --- | --- | --- |
| AX | Fecha de registro del antecedente | HISTORICO DE ANTECEDENTES |
| AY | Tipo | HISTORICO DE ANTECEDENTES |
| AZ | Descripción | HISTORICO DE ANTECEDENTES |
| BA | Observaciones especiales | HISTORICO DE ANTECEDENTES |

#### Datos de la madre

| Col | Campo | Agrupador fila 1 |
| --- | --- | --- |
| BB | Tipo de identificación | DATOS DE LA MADRE |
| BC | Número de identificación* | DATOS DE LA MADRE |
| BD | Primer nombre* | DATOS DE LA MADRE |
| BE | Segundo nombre | DATOS DE LA MADRE |
| BF | Primer apellido* | DATOS DE LA MADRE |
| BG | Segundo apellido | DATOS DE LA MADRE |
| BH | Correo electrónico* | DATOS DE LA MADRE |
| BI | indicativo + Teléfono fijo | DATOS DE LA MADRE |
| BJ | Celular | DATOS DE LA MADRE |
| BK | Régimen de afiliación* | DATOS DE LA MADRE |
| BL | Pertenencia étnica* | DATOS DE LA MADRE |
| BM | Desplazado* | DATOS DE LA MADRE |

#### Datos del cuidador

| Col | Campo | Agrupador fila 1 |
| --- | --- | --- |
| BN | Tipo de identificación | DATOS DEL CUIDADOR |
| BO | Número de identificación* | DATOS DEL CUIDADOR |
| BP | Primer nombre* | DATOS DEL CUIDADOR |
| BQ | Segundo nombre | DATOS DEL CUIDADOR |
| BR | Primer apellido* | DATOS DEL CUIDADOR |
| BS | Segundo apellido | DATOS DEL CUIDADOR |
| BT | Parentesco* | DATOS DEL CUIDADOR |
| BU | Correo electrónico* | DATOS DEL CUIDADOR |
| BV | indicativo + Teléfono fijo | DATOS DEL CUIDADOR |
| BW | Celular | DATOS DEL CUIDADOR |

#### Esquema de vacunación - encabezado

| Col | Campo | Agrupador fila 1 |
| --- | --- | --- |
| BX | TIPO DE CARNET | ESQUEMA DE VACUNACION |

#### Biológicos / vacunas aplicadas (columnas BY - IW)

Cada biológico es un bloque de columnas. Las subcolumnas típicas son: **Dosis, Lote, Jeringa, Lote Jeringa, Lote Diluyente y Observación** (algunas variantes usan **Número de frascos utilizados**, **Gotero** o **Tipo Neumococo**).

| Biológico (grupo fila 1) | Columnas | Subcampos (fila 2) |
| --- | --- | --- |
| COVID-19 | BY:CD | Dosis (BY); Laboratorio (BZ); Lote (CA); Jeringa (CB); Lote Jeringa (CC); Lote Diluyente (CD) |
| BCG | CE:CJ | Dosis (CE); Lote (CF); Jeringa (CG); Lote Jeringa (CH); Lote Diluyente (CI); Observación (CJ) |
| Hepatitis B | CK:CO | Dosis (CK); Lote (CL); Jeringa (CM); Lote Jeringa (CN); Observación (CO) |
| Polio Inactivado (Vacuna inyectable) | CP:CT | Dosis (CP); Lote (CQ); Jeringa (CR); Lote Jeringa (CS); Observación (CT) |
| Polio (Vacuna oral) | CU:CW | Dosis (CU); Lote (CV); Gotero (CW) |
| Pentavalente | CX:DB | Dosis (CX); Lote (CY); Jeringa (CZ); Lote Jeringa (DA); Observación (DB) |
| Hexavalente | DC:DF | Dosis (DC); Lote (DD); Jeringa (DE); Lote Jeringa (DF) |
| Difteria, Tos ferina y Tétanos - DPT | DG:DJ | Dosis (DG); Lote (DH); Jeringa (DI); Lote Jeringa (DJ) |
| DTPa Pediátrico | DK:DN | Dosis (DK); Lote (DL); Jeringa (DM); Lote Jeringa (DN) |
| TD Pediátrico | DO:DR | Dosis (DO); Lote (DP); Jeringa (DQ); Lote Jeringa (DR) |
| Rotavirus (vacuna oral) | DS:DT | Dosis (DS); Lote (DT) |
| Neumococo | DU:DY | Tipo Neumococo (DU); Dosis (DV); Lote (DW); Jeringa (DX); Lote Jeringa (DY) |
| Triple viral - SRP | DZ:ED | Dosis (DZ); Lote (EA); Jeringa (EB); Lote Jeringa (EC); Lote Diluyente (ED) |
| Sarampión - Rubeola - SR Multidosis | EE:EI | Dosis (EE); Lote (EF); Jeringa (EG); Lote Jeringa (EH); Lote Diluyente (EI) |
| Fiebre amarilla | EJ:EN | Dosis (EJ); Lote (EK); Jeringa (EL); Lote Jeringa (EM); Lote Diluyente (EN) |
| Hepatitis A pediátrica | EO:ER | Dosis (EO); Lote (EP); Jeringa (EQ); Lote Jeringa (ER) |
| Varicela | ES:EW | Dosis (ES); Lote (ET); Jeringa (EU); Lote Jeringa (EV); Lote Diluyente (EW) |
| Toxoide tetánico y diftérico de Adulto | EX:FA | Dosis (EX); Lote (EY); Jeringa (EZ); Lote Jeringa (FA) |
| dTpa adulto | FB:FE | Dosis (FB); Lote (FC); Jeringa (FD); Lote Jeringa (FE) |
| Influenza | FF:FJ | Dosis (FF); Lote (FG); Jeringa (FH); Lote Jeringa (FI); Observación (FJ) |
| VPH | FK:FN | Dosis (FK); Lote (FL); Jeringa (FM); Lote Jeringa (FN) |
| Antirrábica  Humana (vacuna) | FO:FT | Dosis (FO); Lote (FP); Jeringa (FQ); Lote Jeringa (FR); Lote Diluyente (FS); Observación (FT) |
| Antirrábico Humano (suero) | FU:FV | Número de frascos utilizados (FU); Lote (FV) |
| Hepatitis B (Inmunoglobulina) | FW:GA | Número de frascos utilizados (FW); Lote (FX); Jeringa (FY); Lote Jeringa (FZ); Observación (GA) |
| INMUNOGLOBULINA ANTI TETANICA (Suero homólogo) | GB:GE | Número de frascos utilizados (GB); Lote (GC); Jeringa (GD); Lote Jeringa (GE) |
| ANTI TOXINA TETANICA (Suero heterólogo) | GF:GI | Número de frascos utilizados (GF); Lote (GG); Jeringa (GH); Lote Jeringa (GI) |
| Meningococo  de los serogrupos A, C, W-135 e Y | GJ:GN | Dosis (GJ); Lote (GK); Jeringa (GL); Lote Jeringa (GM); Lote Diluyente (GN) |
| VIRUS SINCITIAL RESPIRATORIO (VSR) | GO:GP | Dosis (GO); Lote (GP) |
| DENGUE | GQ:GR | Dosis (GQ); Lote (GR) |
| HEPATITIS B | GS:GT | Dosis (GS); Lote (GT) |
| PENTAVALENTE (DPaT,HiB,VPI) | GU:GV | Dosis (GU); Lote (GV) |
| HEXAVALENTE (DPaT,HiB,HB,VPI) | GW:GX | Dosis (GW); Lote (GX) |
| TETRAVALENTE (DPaT,VPI) | GY:GZ | Dosis (GY); Lote (GZ) |
| DPT ACELULAR PEDIATRICO | HA:HB | Dosis (HA); Lote (HB) |
| TOXOIDE TETANICO Y DIFTERICO (TD) PEDIATRICO | HC:HD | Dosis (HC); Lote (HD) |
| ROTAVIRUS | HE:HF | Dosis (HE); Lote (HF) |
| NEUMOCOCO CONJUGADA | HG:HH | Dosis (HG); Lote (HH) |
| NEUMO POLISACARIDO | HI:HJ | Dosis (HI); Lote (HJ) |
| TRIPLE VIRAL | HK:HL | Dosis (HK); Lote (HL) |
| VARICELA + TRIPLE VIRAL | HM:HN | Dosis (HM); Lote (HN) |
| FIEBRE AMARILLA | HO:HP | Dosis (HO); Lote (HP) |
| HEPATITIS A | HQ:HR | Dosis (HQ); Lote (HR) |
| HEPATITIS A, HEPATITIS B | HS:HT | Dosis (HS); Lote (HT) |
| VARICELA | HU:HV | Dosis (HU); Lote (HV) |
| TOXOIDE TETÁNICO/DIFTERICO ADULTOS | HW:HX | Dosis (HW); Lote (HX) |
| DPT ACELULAR ADULTO | HY:HZ | Dosis (HY); Lote (HZ) |
| INFLUENZA | IA:IB | Dosis (IA); Lote (IB) |
| VPH | IC:ID | Dosis (IC); Lote (ID) |
| ANTIRRÁBICA PROFILÁCTICA | IE:IG | Dosis (IE); Lote (IF); Observación (IG) |
| INMUNOGLOBULINA ANTI TETANICA (Suero homólogo) | IH:II | Número de frascos utilizados (IH); Lote (II) |
| INMUNOGLOBULINA ANTI HEPATITIS B | IJ:IL | Número de frascos utilizados (IJ); Lote (IK); Observación (IL) |
| INMUNOGLOBULINA ANTI TETANICA (Suero homólogo) | IM:IN | Número de frascos utilizados (IM); Lote (IN) |
| ANTI TOXINA TETANICA (Suero heterólogo) | IO:IP | Número de frascos utilizados (IO); Lote (IP) |
| MENINGOCOCO CONJUGADO | IQ:IR | Dosis (IQ); Lote (IR) |
| FIEBRE TIFOIDEA | IS:IT | Dosis (IS); Lote (IT) |
| HERPES ZOSTER | IU:IV | Dosis (IU); Lote (IV) |

#### Cierre del registro

| Col | Campo | Grupo |
| --- | --- | --- |
| IW | RESPONSABLE (NOMBRE DEL VACUNADOR) | RESPONSABLE (NOMBRE DEL VACUNADOR) |
| IX | EL REGISTRO FUE INGRESADO AL APLICATIVO PAI | EL REGISTRO FUE INGRESADO AL APLICATIVO PAI |
| IY | MOTIVO DE NO INGRESO | MOTIVO DE NO INGRESO |
| IZ | OBSERVACIONES | OBSERVACIONES |
| JA | MUNICIPIO IPS VACUNADORA | MUNICIPIO IPS VACUNADORA |
| JB | IPS VACUNADORA | IPS VACUNADORA |

### 3.2 Listas de datos y validaciones (hoja `Registro Diario`)

| Columnas | Tipo de validación | Origen / fórmula |
| --- | --- | --- |
| CT3:CT10000 DB3:DB10000 | list | "AUTORIZADAS POR EL MINISTERIO" |
| AT3:AT10000 | date | 1/7/2022 |
| BI3:BJ10000 BV3:BW10000 | whole | 1000000000 |
| B3:B10000 I3:I10000 | date | 3654 |
| AK3:AK10000 | None | None |
| AE3:AE10000 CT3:CT10000 DB3:DB10000 JB3:JB7 | list | INDIRECT(AD3) |
| GD3:GD10000 GH3:GH10000 | list | jeringa |
| AX3:AX10000 | date | 7306 |
| R3:R10000 | whole | 1 |
| C3:C10000 | list | TIPO_ID_VAC |
| AJ3:AJ10000 | textLength | 10 |
| N3:N10000 Y3:AC10000 AM3:AO10000 AQ3:AQ10000 BM3:BM10000 | list | "SI,NO" |
| BB3:BB10000 BN3:BN10000 | list | TIPO_ID_MA |
| JA10000 | list | MUN_LA_GUAJIRA |
| W3:W10000 | list | $JP$10:$JP$26 |
| JA3:JA9999 | list | $JR$10:$JR$38 |
| AV3:AV10000 | date | AT3+280 |
| AF3:AF10000 | list | INDIRECT($AE3) |
| AS3:AS10000 | list | IF(J3>=9,INDIRECT(O3),"") |

---

## 4. Mapeo a las vistas

### 4.1 Vista `Registrar Paciente`

Campos provenientes de los bloques de la fila 1: **Datos básicos/identificación**, **Datos complementarios**, **Antecedentes médicos**, **Condición de la usuaria**, **Histórico de antecedentes**, **Datos de la madre** y **Datos del cuidador**.

| Bloque | Campos |
| --- | --- |
| Datos básicos / identificación | Consecutivo; Fecha de atención formato de fecha en números (día/mes/año); Tipo de identificación; Número de identificación; Primer nombre; Segundo nombre; Primer apellido; Segundo apellido; Fecha de nacimiento  Formato de fecha en números (día/mes/año); AÑOS; MESES; DIAS; Total meses; Esquema completo |
| Datos complementarios | Sexo; Género; Orientación sexual; Edad gestacional (semanas); País de nacimiento; Estatus Migratorio; Lugar de atención del parto (Hospital); Régimen de afiliación; Aseguradora; Pertenencia étnica; Desplazado; Discapacitado; Fallecido; Víctima del conflicto armado; Estudia actualmente; País de residencia; Departamento de residencia; Municipio de residencia; Comuna/Localidad; Área; Dirección con nomenclatura; indicativo + Teléfono fijo; Celular; Email; ¿Autoriza llamadas teléfonicas?; ¿Autoriza envío de correo? |
| Antecedentes médicos | ¿Sufre o ha sufrido algún evento o enfermedad que contraindique la vacunación?; Cuál; ¿Ha presentado reacción moderada o severa a biológicos anteriores?; Cuál |
| Condición de la usuaria | Condición de la usuaria; Gestante Fecha de última menstruación; Semanas de gestación; Fecha probable de parto; Cantidad de embarazos previos |
| Histórico de antecedentes | Fecha de registro del antecedente; Tipo; Descripción; Observaciones especiales |
| Datos de la madre | Tipo de identificación; Número de identificación; Primer nombre; Segundo nombre; Primer apellido; Segundo apellido; Correo electrónico; indicativo + Teléfono fijo; Celular; Régimen de afiliación; Pertenencia étnica; Desplazado |
| Datos del cuidador | Tipo de identificación; Número de identificación; Primer nombre; Segundo nombre; Primer apellido; Segundo apellido; Parentesco; Correo electrónico; indicativo + Teléfono fijo; Celular |

### 4.2 Vista `Registrar Vacuna` / Biológico

Campos provenientes del bloque **Esquema de vacunación** (Tipo de carnet) y de cada **bloque de biológico** (Dosis, Lote, Jeringa, Lote Jeringa, Lote Diluyente, Observación), más el cierre del registro (Responsable, ingreso al aplicativo PAIWEB, motivo de no ingreso, observaciones, municipio e IPS vacunadora).

---

## 5. Listas de valores de referencia (hoja `Validador`)

| Lista | Valores |
| --- | --- |
| Sexo | MUJER; HOMBRE; INDETERMIADO |
| Género | FEMENINO; MASCULINO; TRANSGENERO; INDETERMINADO |
| Orientación sexual | HOMOSEXUAL; BISEXUAL; TRANSEXUAL; INTERSEXUAL; HETEROSEXUAL; OTRO; NO SABE/NO APLICA |
| Tipo de identificación | CN; RC; TI; CC; AS; MS; CE; PA; CD; SC; PE; PPT; DE |
| Régimen de afiliación | CONTRIBUTIVO; SUBSIDIADO; POBLACION POBRE NO ASEGURADA; EXCEPCION Y ESPECIAL E INPEC |
| Pertenencia étnica | INDIGENA; ROM (GITANO); RAIZAL; PALENQUERO; NEGRO(A) O AFROCOLOMBIANO (A); NINGUNO DE LOS ANTERIORES |
| Área | URBANA; RURAL |
| Sí / No | SI; NO |
| Jeringa | Jeringa_Desechable_22G1_Media_Pulg_AD; Jeringa_Desechable_22G1_Media_Pulg_Convencional; Jeringa_Desechable_23G1_Pulg_AD; Jeringa_Desechable_23G1_Pulg_Convencional; Jeringa_Desechable_25G_Cinco_Octavos_Pulg_AD; Jeringa_Desechable_25G_Cinco_Octavos_Pulg_Convencional; Jeringa_Desechable_26G_Tres_Octavos_Pulg_AD; Jeringa_Desechable_26G_Tres_Octavos_Pulg_Convencional; Jeringa_Desechable_27G_Tres_Octavos_Pulg |

> Códigos de tipo de identificación: CN = certificado de nacido vivo, RC = registro civil, TI = tarjeta de identidad, CC = cédula de ciudadanía, AS = adulto sin identificación, MS = menor sin identificación, CE = cédula de extranjería, PA = pasaporte, CD = carné diplomático, SC = salvoconducto, PE = permiso especial de permanencia, PPT = permiso por protección temporal, DE = documento extranjero.

---

## 6. Notas para el agente

- La fila 2 de `Registro Diario` es la única fuente de nombres de campo; la fila 1 solo agrupa por sección.
- Un registro del formato equivale a **un paciente + una vacuna aplicada**; los datos del paciente se repiten por cada biológico aplicado en la misma atención.
- El campo **Consecutivo** es un número entero secuencial por registro.
- Las fechas se registran como **día/mes/año**.
- Los campos derivados/calculados (AÑOS, MESES, DIAS, Total meses, Semanas de gestación, Fecha probable de parto, Estatus Migratorio) no se diligencian manualmente.
- Los tipos de campo del instructivo son: Texto, Numero, Fecha, Selección, Formulado y Visualizado.
