package com.pai.api.reports.export;

import java.util.List;

/** AbstractProduct: escribe el encabezado del reporte (especifico del formato). */
public interface ReportHeaderBuilder {

  void writeHeader(List<String> titles);
}
