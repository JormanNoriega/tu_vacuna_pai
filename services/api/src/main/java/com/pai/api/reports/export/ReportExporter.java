package com.pai.api.reports.export;

/** AbstractProduct: serializa el reporte a bytes (especifico del formato). */
public interface ReportExporter {

  byte[] export();
}
