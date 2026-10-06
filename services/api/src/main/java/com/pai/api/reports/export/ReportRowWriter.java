package com.pai.api.reports.export;

import java.util.List;

/** AbstractProduct: escribe una fila del reporte (especifico del formato). */
public interface ReportRowWriter {

  void writeRow(List<String> cells);
}
