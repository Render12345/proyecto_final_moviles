
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_model.dart';
import '../services/report_service.dart';

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService();
});

final reportsProvider = StreamProvider<List<ReportModel>>((ref) {
  return ref.watch(reportServiceProvider).escucharReportes();
});
