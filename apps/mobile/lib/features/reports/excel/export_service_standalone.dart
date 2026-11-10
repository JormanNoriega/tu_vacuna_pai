import 'dart:io';
import 'dart:isolate';

import 'package:excel/excel.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'age_calculator.dart';
import 'carnet_type_formatter.dart';
import 'id_type_constants.dart';
import 'report_category_colors.dart';

/// Servicio autónomo y desacoplado para generar el reporte Excel de vacunación.
///
/// Este módulo contiene toda la lógica de:
/// 1. Construcción de encabezados combinados (Fila 0 - Categorías).
/// 2. Construcción de subencabezados detallados (Fila 1 - Nombres de campos).
/// 3. Formateo y estilización por celdas con colores ARGB profesionales.
/// 4. Agrupación y pivoteo de dosis múltiples por paciente y fecha de atención.
/// 5. Generación asíncrona dentro de un [Isolate] para evitar bloqueos del hilo principal.
class StandaloneExcelExportService {
  // 10 campos posibles que puede tener una vacuna
  static const List<String> vaccineFields = [
    'dose',
    'vial_count',
    'lot_number',
    'laboratory',
    'syringe',
    'syringe_lot',
    'diluent_lot',
    'dropper',
    'pneumococcal_type',
    'observation',
  ];

  // Vacunas que por norma no registran dosis numérica (solo se aplican)
  static const Set<String> noDoseVaccines = {
    'antirrabico_suero',
    'hepatitis_b_inmunoglobulina',
    'inmunoglobulina_antitetanica',
    'antitoxina_tetanica',
  };

  // Categorías fijas del reporte y cantidad de columnas que abarca cada una
  static const List<MapEntry<String, int>> fixedCategories = [
    MapEntry('DATOS BÁSICOS', 18),
    MapEntry('DATOS COMPLEMENTARIOS', 24),
    MapEntry('ANTECEDENTES MÉDICOS', 4),
    MapEntry('CONDICIÓN USUARIA', 7),
    MapEntry('HISTÓRICO DE ANTECEDENTES', 4),
    MapEntry('DATOS DE LA MADRE', 13),
    MapEntry('DATOS DEL CUIDADOR', 14),
    MapEntry('ESQUEMA DE VACUNACIÓN', 4),
  ];

  // Colores ARGB de fondo para cada categoría fija en la Fila 0
  static const Map<String, String> categoryColors = {
    'DATOS BÁSICOS': ReportCategoryColors.basicData,
    'DATOS COMPLEMENTARIOS': ReportCategoryColors.complementaryData,
    'ANTECEDENTES MÉDICOS': ReportCategoryColors.medicalHistory,
    'CONDICIÓN USUARIA': ReportCategoryColors.userCondition,
    'HISTÓRICO DE ANTECEDENTES': ReportCategoryColors.antecedentHistory,
    'DATOS DE LA MADRE': ReportCategoryColors.motherData,
    'DATOS DEL CUIDADOR': ReportCategoryColors.caregiverData,
    'ESQUEMA DE VACUNACIÓN': ReportCategoryColors.vaccinationScheme,
    'DATOS ENFERMERA': ReportCategoryColors.nurseData,
    'VACUNAS': ReportCategoryColors.vaccines,
  };

  // Etiquetas para la Fila 1 de los campos dinámicos de vacunas
  static const Map<String, String> vaccineFieldLabels = {
    'dose': 'DOSIS',
    'lot_number': 'LOTE',
    'laboratory': 'LABORATORIO',
    'syringe': 'JERINGA',
    'syringe_lot': 'LOTE JERINGA',
    'diluent_lot': 'DILUYENTE',
    'dropper': 'GOTERO',
    'pneumococcal_type': 'TIPO NEUMOCOCO',
    'vial_count': 'CANTIDAD FRASCOS',
    'observation': 'OBSERVACIÓN',
  };

  // Encabezados fijos (Fila 1) organizados por categorías
  static const List<String> fixedFieldHeaders = [
    // --- DATOS BÁSICOS (20) ---
    'CONSECUTIVO',
    'FECHA DE ATENCIÓN',
    'TIPO DE IDENTIFICACIÓN',
    'NÚMERO DE IDENTIFICACIÓN',
    'PRIMER NOMBRE',
    'SEGUNDO NOMBRE',
    'PRIMER APELLIDO',
    'SEGUNDO APELLIDO',
    'FECHA DE NACIMIENTO',
    'AÑOS',
    'MESES',
    'DÍAS',
    'TOTAL MESES',
    'ESQUEMA COMPLETO',
    'SEXO',
    'GÉNERO',
    'ORIENTACIÓN SEXUAL',
    'EDAD GESTACIONAL (SEMANAS)',

    // --- DATOS COMPLEMENTARIOS (24) ---
    'PAÍS DE NACIMIENTO',
    'ESTATUS MIGRATORIO',
    'LUGAR DE ATENCIÓN DEL PARTO',
    'RÉGIMEN DE AFILIACIÓN',
    'ASEGURADORA',
    'PERTENENCIA ÉTNICA',
    'DESPLAZADO',
    'DISCAPACITADO',
    'FALLECIDO',
    'VÍCTIMA DEL CONFLICTO ARMADO',
    'ESTUDIA ACTUALMENTE',
    'PAÍS DE RESIDENCIA',
    'DEPARTAMENTO DE RESIDENCIA',
    'MUNICIPIO DE RESIDENCIA',
    'COMUNA/LOCALIDAD',
    'ÁREA',
    'DIRECCIÓN CON NOMENCLATURA',
    'TELÉFONO FIJO',
    'CELULAR',
    'EMAIL',
    '¿AUTORIZA LLAMADAS TELEFÓNICAS?',
    '¿AUTORIZA ENVÍO DE CORREO?',
    'NIVEL EDUCATIVO',
    'CÓDIGO ASEGURADORA',

    // --- ANTECEDENTES MÉDICOS (4) ---
    '¿SUFRE O HA SUFRIDO ALGÚN EVENTO O ENFERMEDAD QUE CONTRAINDIQUE LA VACUNACIÓN?',
    'CUÁL CONTRAINDICACIÓN',
    '¿HA PRESENTADO REACCIÓN MODERADA O SEVERA A BIOLÓGICOS ANTERIORES?',
    'CUÁL REACCIÓN',

    // --- CONDICIÓN USUARIA (7) ---
    'CONDICIÓN DE LA USUARIA',
    'FECHA DE ÚLTIMA MENSTRUACIÓN',
    'SEMANAS DE GESTACIÓN',
    'FECHA PROBABLE DE PARTO',
    'CANTIDAD DE EMBARAZOS PREVIOS',
    '¿HA TENIDO PARTOS PREVIOS?',
    'LUGAR PARTO USUARIA',

    // --- HISTÓRICO DE ANTECEDENTES (4) ---
    'FECHA DE REGISTRO DEL ANTECEDENTE',
    'TIPO',
    'DESCRIPCIÓN',
    'OBSERVACIONES ESPECIALES',

    // --- DATOS DE LA MADRE (13) ---
    'TIPO DE IDENTIFICACIÓN MADRE',
    'NÚMERO DE IDENTIFICACIÓN MADRE',
    'PRIMER NOMBRE MADRE',
    'SEGUNDO NOMBRE MADRE',
    'PRIMER APELLIDO MADRE',
    'SEGUNDO APELLIDO MADRE',
    'CORREO ELECTRÓNICO MADRE',
    'TELÉFONO FIJO MADRE',
    'CELULAR MADRE',
    'RÉGIMEN DE AFILIACIÓN MADRE',
    'PERTENENCIA ÉTNICA MADRE',
    'DESPLAZADO MADRE',
    'ASEGURADORA MADRE',

    // --- DATOS DEL CUIDADOR (14) ---
    'TIPO DE IDENTIFICACIÓN CUIDADOR',
    'NÚMERO DE IDENTIFICACIÓN CUIDADOR',
    'PRIMER NOMBRE CUIDADOR',
    'SEGUNDO NOMBRE CUIDADOR',
    'PRIMER APELLIDO CUIDADOR',
    'SEGUNDO APELLIDO CUIDADOR',
    'PARENTESCO',
    'CORREO ELECTRÓNICO CUIDADOR',
    'TELÉFONO FIJO CUIDADOR',
    'CELULAR CUIDADOR',
    'RÉGIMEN DE AFILIACIÓN CUIDADOR',
    'ASEGURADORA CUIDADOR',
    'PERTENENCIA ÉTNICA CUIDADOR',
    'DESPLAZADO CUIDADOR',

    // --- ESQUEMA DE VACUNACIÓN (4) ---
    'TIPO DE CARNET DE VACUNACIÓN',
    'REGISTRADO EN PAIWEB',
    'MOTIVO NO INGRESO PAIWEB',
    'OBSERVACIONES DE LA ATENCIÓN',
  ];

  static const int nurseFieldCount = 7;
  static const List<String> nurseFieldLabels = [
    'NOMBRE ENFERMERA',
    'DOCUMENTO ENFERMERA',
    'CORREO ELECTRÓNICO ENFERMERA',
    'TELÉFONO ENFERMERA',
    'INSTITUCIÓN ENFERMERA',
    'PROFESIÓN ENFERMERA',
    'REGISTRO PROFESIONAL ENFERMERA',
  ];

  /// Genera los bytes del archivo Excel a partir de:
  /// - [doseRows]: Lista de mapas con los registros planos de dosis aplicadas y datos de paciente.
  /// - [vaccineStructure]: Estructura con la configuración y campos habilitados de cada vacuna.
  ///
  /// Se ejecuta en un [Isolate] en segundo plano para no congelar la UI.
  static Future<List<int>> generateExcelBytes({
    required List<Map<String, dynamic>> doseRows,
    required Map<String, Map<String, dynamic>> vaccineStructure,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return Isolate.run(
      () => _buildExcelBytes({
        'doseRows': doseRows,
        'vaccineStructure': vaccineStructure,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      }),
    );
  }

  /// Genera el archivo físico `.xlsx` en la ruta especificada.
  static Future<File> generateExcelFile({
    required String filePath,
    required List<Map<String, dynamic>> doseRows,
    required Map<String, Map<String, dynamic>> vaccineStructure,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final bytes = await generateExcelBytes(
      doseRows: doseRows,
      vaccineStructure: vaccineStructure,
      startDate: startDate,
      endDate: endDate,
    );
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Construye los bytes del Excel (función pura para ejecutar en Isolate)
  static Future<List<int>> _buildExcelBytes(Map<String, dynamic> params) async {
    await initializeDateFormatting('es', null);

    final doseRows = (params['doseRows'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final vaccineStructure =
        (params['vaccineStructure'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, v as Map<String, dynamic>),
        );

    // Agrupar dosis por (paciente + fecha de atención normalizada a día YYYY-MM-DD)
    final Map<String, List<Map<String, dynamic>>> groupedByPatientDate = {};
    for (final dose in doseRows) {
      final patientId = dose['patient_id']?.toString() ?? '';
      final appDate = dose['application_date']?.toString() ?? '';
      final normalizedDate = appDate.split('T')[0];
      final key = '$patientId|$normalizedDate';
      groupedByPatientDate.putIfAbsent(key, () => []);
      groupedByPatientDate[key]!.add(dose);
    }

    final List<List<dynamic>> reportRows = [];
    for (final groupEntry in groupedByPatientDate.entries) {
      final doses = groupEntry.value;
      final firstDose = doses.first;

      // Agrupar las dosis aplicadas en esta consulta por ID de vacuna
      final vaccineDosesMap = <String, List<Map<String, dynamic>>>{};
      for (final dose in doses) {
        final vaccId = dose['vaccine_id']?.toString() ?? '';
        vaccineDosesMap.putIfAbsent(vaccId, () => []);
        vaccineDosesMap[vaccId]!.add(dose);
      }

      // Si el paciente recibió varias dosis de la misma vacuna en la misma visita,
      // calculamos la cantidad máxima para generar filas adicionales.
      var maxDosesCount = 0;
      for (final dosesList in vaccineDosesMap.values) {
        if (dosesList.length > maxDosesCount) {
          maxDosesCount = dosesList.length;
        }
      }
      if (maxDosesCount == 0) maxDosesCount = 1;

      for (int doseIndex = 0; doseIndex < maxDosesCount; doseIndex++) {
        reportRows.add(
          _buildPatientRowWithDoseIndex(
            firstDose,
            vaccineDosesMap,
            vaccineStructure,
            doseIndex,
          ),
        );
      }
    }

    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    _createMergedHeaders(sheet, vaccineStructure);
    _addDataRows(sheet, reportRows);

    return excel.encode()!;
  }

  /// Construye las dos filas de encabezados:
  /// - Fila 0: Categorías principales combinadas (merged) y coloreadas.
  /// - Fila 1: Subencabezados con los nombres exactos de las columnas.
  static void _createMergedHeaders(
    Sheet sheet,
    Map<String, Map<String, dynamic>> vaccineStructure,
  ) {
    int columnIndex = 0;

    // 1) Categorías Fijas (Fila 0)
    for (final entry in fixedCategories) {
      final category = entry.key;
      final fieldCount = entry.value;
      final cellColorHex =
          categoryColors[category] ?? ReportCategoryColors.defaultWhite;

      for (int i = 0; i < fieldCount; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: columnIndex + i, rowIndex: 0),
        );
        if (i == 0) cell.value = TextCellValue(category);
        cell.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString(cellColorHex),
          fontColorHex: ExcelColor.fromHexString(
            ReportCategoryColors.defaultWhite,
          ),
          bold: true,
        );
      }

      // Combinar las celdas de la categoría
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: 0),
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex + fieldCount - 1,
          rowIndex: 0,
        ),
      );
      columnIndex += fieldCount;
    }

    final sortedVaccines = _sortedVaccines(vaccineStructure);

    // 2) Categorías dinámicas de Vacunas (Fila 0)
    for (var i = 0; i < sortedVaccines.length; i++) {
      final entry = sortedVaccines[i];
      final vaccineName = (entry.value['name']?.toString() ?? '').toUpperCase();
      final enabledFields =
          (entry.value['enabledFields'] as List<dynamic>?)?.cast<String>() ??
          [];
      if (enabledFields.isEmpty) continue;

      final cellColorHex = i.isEven
          ? ReportCategoryColors.vaccineDark
          : ReportCategoryColors.vaccineLight;

      for (int j = 0; j < enabledFields.length; j++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: columnIndex + j, rowIndex: 0),
        );
        if (j == 0) cell.value = TextCellValue(vaccineName);
        cell.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString(cellColorHex),
          fontColorHex: ExcelColor.fromHexString(
            ReportCategoryColors.defaultWhite,
          ),
          bold: true,
        );
      }

      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: 0),
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex + enabledFields.length - 1,
          rowIndex: 0,
        ),
      );
      columnIndex += enabledFields.length;
    }

    // 3) Categoría DATOS ENFERMERA (Fila 0)
    final nurseColor = categoryColors['DATOS ENFERMERA']!;
    for (int i = 0; i < nurseFieldCount; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: columnIndex + i, rowIndex: 0),
      );
      if (i == 0) cell.value = TextCellValue('DATOS ENFERMERA');
      cell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString(nurseColor),
        fontColorHex: ExcelColor.fromHexString(
          ReportCategoryColors.defaultWhite,
        ),
        bold: true,
      );
    }
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: 0),
      CellIndex.indexByColumnRow(
        columnIndex: columnIndex + nurseFieldCount - 1,
        rowIndex: 0,
      ),
    );
    columnIndex += nurseFieldCount;

    // --- FILA 1: Nombres de las columnas ---
    int col = 0;

    // Fijos
    for (final field in fixedFieldHeaders) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1),
      );
      cell.value = TextCellValue(field);
      cell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString(
          ReportCategoryColors.headerRow,
        ),
        bold: true,
      );
      col++;
    }

    // Vacunas dinámicas
    for (var i = 0; i < sortedVaccines.length; i++) {
      final enabledFields =
          (sortedVaccines[i].value['enabledFields'] as List<dynamic>?)
              ?.cast<String>() ??
          [];
      final cellColorHex = i.isEven
          ? ReportCategoryColors.vaccineFieldDark
          : ReportCategoryColors.vaccineFieldLight;

      for (final field in enabledFields) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1),
        );
        cell.value = TextCellValue(vaccineFieldLabels[field] ?? field);
        cell.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString(cellColorHex),
          bold: true,
        );
        col++;
      }
    }

    // Enfermera
    for (final label in nurseFieldLabels) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1),
      );
      cell.value = TextCellValue(label);
      cell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString(
          ReportCategoryColors.vaccineFieldLight,
        ),
        bold: true,
      );
      col++;
    }
  }

  /// Escribe las filas de datos aplicando diseño cebra (alternado blanco / gris suave)
  static void _addDataRows(Sheet sheet, List<List<dynamic>> data) {
    for (int rowIndex = 0; rowIndex < data.length; rowIndex++) {
      final row = data[rowIndex];
      final backgroundColor = rowIndex.isEven
          ? ReportCategoryColors.rowEven
          : ReportCategoryColors.rowOdd;

      for (int colIndex = 0; colIndex < row.length; colIndex++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: colIndex,
            rowIndex:
                rowIndex + 2, // Desplazamiento por los dos encabezados (0 y 1)
          ),
        );
        cell.value = TextCellValue(row[colIndex]?.toString() ?? '');
        cell.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString(backgroundColor),
        );
      }
    }
  }

  /// Ordena las vacunas por su secuencia numérica
  static List<MapEntry<String, Map<String, dynamic>>> _sortedVaccines(
    Map<String, Map<String, dynamic>> structure,
  ) {
    final entries = structure.entries.toList()
      ..sort((a, b) {
        int parseSeq(Object? v) {
          if (v is int) return v;
          if (v == null) return 0;
          return int.tryParse(v.toString()) ?? 0;
        }

        return parseSeq(a.value['sequence'])
            .compareTo(parseSeq(b.value['sequence']));
      });
    return entries;
  }

  /// Construye una fila completa combinando datos de paciente + vacunas + enfermera
  static List<dynamic> _buildPatientRowWithDoseIndex(
    Map<String, dynamic> patientData,
    Map<String, List<Map<String, dynamic>>> vaccineDosesMap,
    Map<String, Map<String, dynamic>> vaccineStructure,
    int doseIndex,
  ) {
    final row = _getBasicPatientData(patientData);
    final sortedVaccines = _sortedVaccines(vaccineStructure);

    for (final vaccineEntry in sortedVaccines) {
      final vaccineId = vaccineEntry.key;
      final vaccineConfig = vaccineEntry.value;
      final enabledFields =
          (vaccineConfig['enabledFields'] as List<dynamic>?)?.cast<String>() ??
          [];
      final dosesList = vaccineDosesMap[vaccineId] ?? [];

      for (final field in enabledFields) {
        if (doseIndex < dosesList.length) {
          final dose = dosesList[doseIndex];
          final value = _getVaccineFieldValue(dose, field);
          row.add(value.toString());
        } else {
          row.add('');
        }
      }
    }

    // Datos de la enfermera que aplicó la dosis en este índice
    Map<String, dynamic>? dosesForNurse;
    for (final vaccineEntry in sortedVaccines) {
      final vaccineId = vaccineEntry.key;
      final dosesList = vaccineDosesMap[vaccineId] ?? [];
      if (doseIndex < dosesList.length) {
        dosesForNurse = dosesList[doseIndex];
        break;
      }
    }

    if (dosesForNurse != null) {
      row.add((dosesForNurse['nurse_name']?.toString() ?? '').toUpperCase());
      row.add(dosesForNurse['nurse_document']?.toString() ?? '');
      row.add(dosesForNurse['nurse_email']?.toString() ?? '');
      row.add(dosesForNurse['nurse_phone']?.toString() ?? '');
      row.add(
        (dosesForNurse['nurse_institution']?.toString() ?? '').toUpperCase(),
      );
      row.add(
        (dosesForNurse['nurse_profession']?.toString() ?? '').toUpperCase(),
      );
      row.add(dosesForNurse['nurse_registration']?.toString() ?? '');
    } else {
      row.addAll(['', '', '', '', '', '', '']);
    }

    return row;
  }

  /// Mapea y formatea los 76 campos fijos de paciente
  static List<dynamic> _getBasicPatientData(Map<String, dynamic> patientData) {
    DateTime? birthDate;
    final rawBirth = patientData['birth_date']?.toString();
    if (rawBirth != null && rawBirth.isNotEmpty) {
      birthDate = DateTime.tryParse(rawBirth);
    }

    final ageData = birthDate != null
        ? AgeCalculator.calculate(birthDate)
        : {'years': 0, 'months': 0, 'days': 0, 'totalMonths': 0};

    String formatDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return '';
      try {
        final date = DateTime.parse(dateStr);
        return DateFormat('dd/MM/yyyy').format(date);
      } catch (_) {
        return dateStr;
      }
    }

    return [
      patientData['consecutivo']?.toString() ?? '',
      formatDate(patientData['attention_date']?.toString()),
      IdTypeConstants.toAbbreviation(patientData['id_type']?.toString()),
      patientData['id_number']?.toString() ?? '',
      (patientData['first_name']?.toString() ?? '').toUpperCase(),
      (patientData['second_name']?.toString() ?? '').toUpperCase(),
      (patientData['last_name']?.toString() ?? '').toUpperCase(),
      (patientData['second_last_name']?.toString() ?? '').toUpperCase(),
      formatDate(patientData['birth_date']?.toString()),
      ageData['years'].toString(),
      ageData['months'].toString(),
      ageData['days'].toString(),
      ageData['totalMonths'].toString(),
      patientData['complete_scheme'] == 1 ||
              patientData['complete_scheme'] == true
          ? 'SÍ'
          : 'NO',
      (patientData['sex']?.toString() ?? '').toUpperCase(),
      (patientData['gender']?.toString() ?? '').toUpperCase(),
      (patientData['sexual_orientation']?.toString() ?? '').toUpperCase(),
      patientData['gestational_age']?.toString() ?? '',
      (patientData['birth_country']?.toString() ?? '').toUpperCase(),
      (patientData['migration_status']?.toString() ?? '').toUpperCase(),
      (patientData['birth_place']?.toString() ?? '').toUpperCase(),
      (patientData['affiliation_regime']?.toString() ?? '').toUpperCase(),
      (patientData['insurer']?.toString() ?? '').toUpperCase(),
      (patientData['ethnicity']?.toString() ?? '').toUpperCase(),
      patientData['displaced'] == 1 || patientData['displaced'] == true
          ? 'SÍ'
          : 'NO',
      patientData['disabled'] == 1 || patientData['disabled'] == true
          ? 'SÍ'
          : 'NO',
      patientData['deceased'] == 1 || patientData['deceased'] == true
          ? 'SÍ'
          : 'NO',
      patientData['armed_conflict_victim'] == 1 ||
              patientData['armed_conflict_victim'] == true
          ? 'SÍ'
          : 'NO',
      patientData['currently_studying'] == 1 ||
              patientData['currently_studying'] == true
          ? 'SÍ'
          : 'NO',
      patientData['residence_country']?.toString() ?? '',
      patientData['residence_department']?.toString() ?? '',
      patientData['residence_municipality']?.toString() ?? '',
      patientData['commune']?.toString() ?? '',
      patientData['area']?.toString() ?? '',
      patientData['address']?.toString() ?? '',
      patientData['landline']?.toString() ?? '',
      patientData['cellphone']?.toString() ?? '',
      patientData['email']?.toString() ?? '',
      patientData['authorize_calls'] == 1 ||
              patientData['authorize_calls'] == true
          ? 'SÍ'
          : 'NO',
      patientData['authorize_email'] == 1 ||
              patientData['authorize_email'] == true
          ? 'SÍ'
          : 'NO',
      (patientData['education_level']?.toString() ?? '').toUpperCase(),
      patientData['insurer_code']?.toString() ?? '',
      patientData['has_contraindication'] == 1 ||
              patientData['has_contraindication'] == true
          ? 'SÍ'
          : 'NO',
      (patientData['contraindication_details']?.toString() ?? '').toUpperCase(),
      patientData['has_previous_reaction'] == 1 ||
              patientData['has_previous_reaction'] == true
          ? 'SÍ'
          : 'NO',
      (patientData['reaction_details']?.toString() ?? '').toUpperCase(),
      (patientData['user_condition']?.toString() ?? '').toUpperCase(),
      formatDate(patientData['last_menstrual_date']?.toString()),
      patientData['gestation_weeks']?.toString() ?? '',
      formatDate(patientData['probable_delivery_date']?.toString()),
      patientData['previous_pregnancies']?.toString() ?? '',
      patientData['has_given_birth'] == 1 ||
              patientData['has_given_birth'] == true
          ? 'SÍ'
          : 'NO',
      (patientData['birth_place_delivery']?.toString() ?? '').toUpperCase(),
      formatDate(patientData['history_record_date']?.toString()),
      (patientData['history_type']?.toString() ?? '').toUpperCase(),
      (patientData['history_description']?.toString() ?? '').toUpperCase(),
      (patientData['special_observations']?.toString() ?? '').toUpperCase(),
      IdTypeConstants.toAbbreviation(patientData['mother_id_type']?.toString()),
      patientData['mother_id_number']?.toString() ?? '',
      (patientData['mother_first_name']?.toString() ?? '').toUpperCase(),
      (patientData['mother_second_name']?.toString() ?? '').toUpperCase(),
      (patientData['mother_last_name']?.toString() ?? '').toUpperCase(),
      (patientData['mother_second_last_name']?.toString() ?? '').toUpperCase(),
      patientData['mother_email']?.toString() ?? '',
      patientData['mother_landline']?.toString() ?? '',
      patientData['mother_cellphone']?.toString() ?? '',
      (patientData['mother_affiliation_regime']?.toString() ?? '')
          .toUpperCase(),
      (patientData['mother_ethnicity']?.toString() ?? '').toUpperCase(),
      patientData['mother_displaced'] == 1 ||
              patientData['mother_displaced'] == true
          ? 'SÍ'
          : 'NO',
      (patientData['mother_insurer']?.toString() ?? '').toUpperCase(),
      IdTypeConstants.toAbbreviation(
        patientData['caregiver_id_type']?.toString(),
      ),
      patientData['caregiver_id_number']?.toString() ?? '',
      (patientData['caregiver_first_name']?.toString() ?? '').toUpperCase(),
      (patientData['caregiver_second_name']?.toString() ?? '').toUpperCase(),
      (patientData['caregiver_last_name']?.toString() ?? '').toUpperCase(),
      (patientData['caregiver_second_last_name']?.toString() ?? '')
          .toUpperCase(),
      (patientData['caregiver_relationship']?.toString() ?? '').toUpperCase(),
      patientData['caregiver_email']?.toString() ?? '',
      patientData['caregiver_landline']?.toString() ?? '',
      patientData['caregiver_cellphone']?.toString() ?? '',
      (patientData['caregiver_affiliation_regime']?.toString() ?? '')
          .toUpperCase(),
      (patientData['caregiver_insurer']?.toString() ?? '').toUpperCase(),
      (patientData['caregiver_ethnicity']?.toString() ?? '').toUpperCase(),
      patientData['caregiver_displaced'] == 1 ||
              patientData['caregiver_displaced'] == true
          ? 'SÍ'
          : 'NO',
      formatCarnetType(patientData['type_carnet_vaccination']?.toString()),
      patientData['paiweb_registered'] == 1 ||
              patientData['paiweb_registered'] == true
          ? 'SÍ'
          : 'NO',
      (patientData['paiweb_not_registered_reason']?.toString() ?? '')
          .toUpperCase(),
      (patientData['attention_observations']?.toString() ?? '').toUpperCase(),
    ];
  }

  /// Extrae el valor de un subcampo específico de dosis
  static String _getVaccineFieldValue(Map<String, dynamic> dose, String field) {
    switch (field) {
      case 'dose':
        return dose['selected_dose']?.toString() ?? '';
      case 'lot_number':
        return dose['lot_number']?.toString() ?? '';
      case 'laboratory':
        return (dose['selected_laboratory']?.toString() ?? '').toUpperCase();
      case 'syringe':
        return (dose['selected_syringe']?.toString() ?? '').toUpperCase();
      case 'syringe_lot':
        return dose['syringe_lot']?.toString() ?? '';
      case 'diluent_lot':
        return dose['diluent_lot']?.toString() ?? '';
      case 'dropper':
        return (dose['selected_dropper']?.toString() ?? '').toUpperCase();
      case 'pneumococcal_type':
        return (dose['selected_pneumococcal_type']?.toString() ?? '')
            .toUpperCase();
      case 'vial_count':
        return dose['vial_count']?.toString() ?? '';
      case 'observation':
        return (dose['selected_observation']?.toString() ?? '').toUpperCase();
      default:
        return '';
    }
  }

  /// Construye la estructura de configuración dinámica de vacunas a partir
  /// de una lista de vacunas del catálogo o base de datos.
  static Map<String, Map<String, dynamic>> buildVaccineStructure(
    List<Map<String, dynamic>> rawVaccines,
  ) {
    final Map<String, Map<String, dynamic>> structure = {};

    for (final vaccine in rawVaccines) {
      final vaccineId = vaccine['id']?.toString() ?? '';
      final vaccineCode = vaccine['code']?.toString() ?? '';

      final fieldMapping = {
        'dose': !noDoseVaccines.contains(vaccineCode),
        'lot_number': vaccine['has_lot'] == 1 || vaccine['has_lot'] == true,
        'laboratory':
            vaccine['has_laboratory'] == 1 || vaccine['has_laboratory'] == true,
        'syringe':
            vaccine['has_syringe'] == 1 || vaccine['has_syringe'] == true,
        'syringe_lot':
            vaccine['has_syringe_lot'] == 1 ||
            vaccine['has_syringe_lot'] == true,
        'diluent_lot':
            vaccine['has_diluent'] == 1 || vaccine['has_diluent'] == true,
        'dropper':
            vaccine['has_dropper'] == 1 || vaccine['has_dropper'] == true,
        'pneumococcal_type':
            vaccine['has_pneumococcal_type'] == 1 ||
            vaccine['has_pneumococcal_type'] == true,
        'vial_count':
            vaccine['has_vial_count'] == 1 || vaccine['has_vial_count'] == true,
        'observation':
            vaccine['has_observation'] == 1 ||
            vaccine['has_observation'] == true,
      };

      final enabledFields = vaccineFields
          .where((field) => fieldMapping[field] == true)
          .toList();

      structure[vaccineId] = {
        'name': vaccine['name'] ?? '',
        'code': vaccineCode,
        'sequence': vaccine['vaccine_sequence'] ?? 0,
        'fieldMapping': fieldMapping,
        'enabledFields': enabledFields,
        'totalFields': enabledFields.length,
      };
    }

    return structure;
  }
}
