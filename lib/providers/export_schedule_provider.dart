import 'package:flutter/rendering.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/ics_service.dart';
import 'package:bugaoshan/utils/calendar_export_utils.dart';

enum ExportResult { success, failed, canceled }

class ExportScheduleProvider {
  final CourseProvider _courseProvider;
  // When override fields are set, they take precedence over the current schedule.
  // This allows exporting a non-active schedule from schedule management page.
  final ScheduleConfig? _overrideConfig;
  final List<Course>? _overrideCourses;

  String? _icsContent;

  ExportScheduleProvider(
    this._courseProvider, {
    ScheduleConfig? overrideConfig,
    List<Course>? overrideCourses,
  }) : _overrideConfig = overrideConfig,
       _overrideCourses = overrideCourses;

  factory ExportScheduleProvider.create() =>
      ExportScheduleProvider(getIt<CourseProvider>());

  factory ExportScheduleProvider.forSchedule(
    ScheduleConfig config,
    List<Course> courses,
  ) => ExportScheduleProvider(
    getIt<CourseProvider>(),
    overrideConfig: config,
    overrideCourses: courses,
  );

  ScheduleConfig get _config =>
      _overrideConfig ?? _courseProvider.scheduleConfig.value;
  List<Course> get _courses =>
      _overrideCourses ?? _courseProvider.courses.value;

  Future<ExportResult> copyToClipBoard() async {
    final data = {
      'config': _config.toJson(),
      'courses': _courses.map((e) => e.toJson()).toList(),
    };
    final success = await CalendarExportUtils.copyJsonToClipboard(
      data,
      logTag: 'copyToClipBoard',
    );
    return success ? ExportResult.success : ExportResult.failed;
  }

  // Return the semester name for ues by the file picker after .ics generation
  String genIcs(String teacherLabel) {
    _icsContent = IcsService.genIcs(
      config: _config,
      courses: _courses,
      teacherLabel: teacherLabel,
    );
    debugPrint("[genIcs] .ics generated successfully");

    final semesterName = _config.semesterName;
    // replace dangerous characters by _
    final safeSemesterName = semesterName.replaceAll(
      RegExp(r'[^\w\u4e00-\u9fff]'),
      '_',
    );
    return safeSemesterName;
  }

  String getIcsContent() {
    return _icsContent!;
  }

  List<Map<String, Object>> getCalendarEventPayloads(String teacherLabel) {
    return IcsService.genCourseCalendarEvents(
      config: _config,
      courses: _courses,
      teacherLabel: teacherLabel,
    ).map((event) => event.toPlatformJson()).toList();
  }
}
