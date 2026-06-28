import 'package:flutter/material.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/campus/exam_plan/models/exam_info.dart';

class CalendarStructuredLocation {
  final String title;
  final double latitude;
  final double longitude;
  final double radius;

  const CalendarStructuredLocation({
    required this.title,
    required this.latitude,
    required this.longitude,
    this.radius = 250,
  });

  Map<String, Object> toPlatformJson() {
    return {
      'title': title,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    };
  }
}

class CalendarEventPayload {
  final DateTime start;
  final DateTime end;
  final String title;
  final String location;
  final String description;
  final String uid;
  final String timeZone;
  final CalendarStructuredLocation? structuredLocation;

  const CalendarEventPayload({
    required this.start,
    required this.end,
    required this.title,
    required this.location,
    required this.description,
    required this.uid,
    this.timeZone = 'Asia/Shanghai',
    this.structuredLocation,
  });

  Map<String, Object> toPlatformJson() {
    final payload = <String, Object>{
      'title': title,
      'location': location,
      'notes': description,
      'uid': uid,
      'timeZone': timeZone,
      'start': _dateComponents(start),
      'end': _dateComponents(end),
    };
    final structuredLocation = this.structuredLocation;
    if (structuredLocation != null) {
      payload['structuredLocation'] = structuredLocation.toPlatformJson();
    }
    return payload;
  }

  static Map<String, int> _dateComponents(DateTime dateTime) {
    return {
      'year': dateTime.year,
      'month': dateTime.month,
      'day': dateTime.day,
      'hour': dateTime.hour,
      'minute': dateTime.minute,
    };
  }
}

class IcsService {
  const IcsService._();

  static const _campusLocations = [
    _CampusGeoReference(
      fullName: '四川大学江安校区',
      latitude: 30.5601863,
      longitude: 103.9973029,
      keywords: ['江安'],
    ),
    _CampusGeoReference(
      fullName: '四川大学望江校区',
      latitude: 30.6335392,
      longitude: 104.0815556,
      keywords: ['望江'],
    ),
    _CampusGeoReference(
      fullName: '四川大学华西校区',
      latitude: 30.6425541,
      longitude: 104.0673888,
      keywords: ['华西'],
    ),
  ];

  static String genIcs({
    required ScheduleConfig config,
    required List<Course> courses,
    required String teacherLabel,
  }) {
    final buffer = StringBuffer();
    _writeCalendarHeader(buffer, 'Course Schedule');

    for (final event in genCourseCalendarEvents(
      config: config,
      courses: courses,
      teacherLabel: teacherLabel,
    )) {
      _writeCalendarEvent(buffer, event);
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static List<CalendarEventPayload> genCourseCalendarEvents({
    required ScheduleConfig config,
    required List<Course> courses,
    required String teacherLabel,
  }) {
    final events = <CalendarEventPayload>[];

    for (final course in courses) {
      for (int week = course.startWeek; week <= course.endWeek; week++) {
        if (!_isWeekActive(course, week)) continue;

        final courseDate = _getCourseDate(
          config.semesterStartDate,
          week,
          course.dayOfWeek,
        );
        final startTime = config.timeSlots[course.startSection - 1].startTime;
        final endTime = config.timeSlots[course.endSection - 1].endTime;
        final location = _resolveCalendarLocation(course.location);

        events.add(
          CalendarEventPayload(
            start: _combineDateTime(courseDate, startTime),
            end: _combineDateTime(courseDate, endTime),
            title: course.name,
            location: location.title,
            description: '$teacherLabel: ${course.teacher}',
            uid: '${course.id}_$week@bugaoshan',
            structuredLocation: location.structuredLocation,
          ),
        );
      }
    }

    return events;
  }

  static String genExamIcs({required List<ExamInfo> exams}) {
    final buffer = StringBuffer();
    _writeCalendarHeader(buffer, 'Exam Schedule');

    for (final event in genExamCalendarEvents(exams: exams)) {
      _writeCalendarEvent(buffer, event);
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static List<CalendarEventPayload> genExamCalendarEvents({
    required List<ExamInfo> exams,
  }) {
    final events = <CalendarEventPayload>[];

    for (var i = 0; i < exams.length; i++) {
      final exam = exams[i];
      final range = _parseExamDateTimeRange(exam);
      if (range == null) continue;
      final courseName = _cleanExamCalendarText(exam.courseName);
      final location = _resolveCalendarLocation(exam.location);

      final description = [
        exam.week,
        '座位号: ${exam.seatNumber}',
        if (exam.ticketNumber.isNotEmpty) '准考证号: ${exam.ticketNumber}',
        if (exam.tip != '无') '提示: ${exam.tip}',
      ].join('\n');

      events.add(
        CalendarEventPayload(
          start: range.start,
          end: range.end,
          title: courseName.endsWith('考试') ? courseName : '$courseName考试',
          location: location.title,
          description: description,
          uid: 'exam_${exam.date}_${i}_${courseName.hashCode}@bugaoshan',
          structuredLocation: location.structuredLocation,
        ),
      );
    }

    return events;
  }

  static void _writeCalendarHeader(StringBuffer buffer, String productName) {
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Bugaoshan//$productName//EN');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');
    buffer.writeln('X-WR-TIMEZONE:Asia/Shanghai');
    buffer.writeln('BEGIN:VTIMEZONE');
    buffer.writeln('TZID:Asia/Shanghai');
    buffer.writeln('BEGIN:STANDARD');
    buffer.writeln('TZOFFSETFROM:+0800');
    buffer.writeln('TZOFFSETTO:+0800');
    buffer.writeln('TZNAME:CST');
    buffer.writeln('DTSTART:19700101T000000');
    buffer.writeln('RRULE:FREQ=YEARLY;BYDAY=1SU;BYMONTH=3');
    buffer.writeln('END:STANDARD');
    buffer.writeln('BEGIN:DAYLIGHT');
    buffer.writeln('TZOFFSETFROM:+0800');
    buffer.writeln('TZOFFSETTO:+0800');
    buffer.writeln('TZNAME:CST');
    buffer.writeln('DTSTART:19700101T000000');
    buffer.writeln('RRULE:FREQ=YEARLY;BYDAY=1SU;BYMONTH=11');
    buffer.writeln('END:DAYLIGHT');
    buffer.writeln('END:VTIMEZONE');
  }

  static void _writeCalendarEvent(
    StringBuffer buffer,
    CalendarEventPayload event,
  ) {
    buffer.writeln('BEGIN:VEVENT');
    buffer.writeln(
      'DTSTART;TZID=${event.timeZone}:${_formatIcsDate(event.start)}',
    );
    buffer.writeln('DTEND;TZID=${event.timeZone}:${_formatIcsDate(event.end)}');
    buffer.writeln('SUMMARY:${_escapeIcsText(event.title)}');
    buffer.writeln('LOCATION:${_escapeIcsText(event.location)}');
    final structuredLocation = event.structuredLocation;
    if (structuredLocation != null) {
      buffer.writeln(
        'GEO:${structuredLocation.latitude};${structuredLocation.longitude}',
      );
    }
    buffer.writeln('DESCRIPTION:${_escapeIcsText(event.description)}');
    buffer.writeln('UID:${event.uid}');
    buffer.writeln('END:VEVENT');
  }

  static bool _isWeekActive(Course course, int week) {
    if (course.weekType == WeekType.odd && week.isEven) return false;
    if (course.weekType == WeekType.even && week.isOdd) return false;
    return true;
  }

  static DateTime _getCourseDate(
    DateTime semesterStart,
    int week,
    int dayOfWeek,
  ) {
    // force monday alignment
    final monday = semesterStart.toMonday();
    final targetDate = monday.add(
      Duration(days: (week - 1) * 7 + (dayOfWeek - 1)),
    );
    return DateTime(targetDate.year, targetDate.month, targetDate.day);
  }

  static DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  static ({DateTime start, DateTime end})? _parseExamDateTimeRange(
    ExamInfo exam,
  ) {
    final dateMatch = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})$',
    ).firstMatch(exam.date);
    final timeMatch = RegExp(
      r'^(\d{2}):(\d{2})-(\d{2}):(\d{2})$',
    ).firstMatch(exam.timeRange);
    if (dateMatch == null || timeMatch == null) return null;

    final year = int.parse(dateMatch.group(1)!);
    final month = int.parse(dateMatch.group(2)!);
    final day = int.parse(dateMatch.group(3)!);
    final start = DateTime(
      year,
      month,
      day,
      int.parse(timeMatch.group(1)!),
      int.parse(timeMatch.group(2)!),
    );
    final end = DateTime(
      year,
      month,
      day,
      int.parse(timeMatch.group(3)!),
      int.parse(timeMatch.group(4)!),
    );
    return (start: start, end: end);
  }

  static String _cleanExamCalendarText(String text) {
    return text.replaceAll(RegExp(r'\s*[（(]\s*已结束\s*[）)]\s*'), '').trim();
  }

  static ({String title, CalendarStructuredLocation? structuredLocation})
  _resolveCalendarLocation(String rawLocation) {
    final location = rawLocation.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (location.isEmpty) {
      return (title: location, structuredLocation: null);
    }

    final campus = _campusForLocation(location);
    if (campus == null) {
      return (title: location, structuredLocation: null);
    }

    final title = location.contains(campus.fullName)
        ? location
        : '${campus.fullName} · $location';
    return (
      title: title,
      structuredLocation: CalendarStructuredLocation(
        title: title,
        latitude: campus.latitude,
        longitude: campus.longitude,
      ),
    );
  }

  static _CampusGeoReference? _campusForLocation(String location) {
    for (final campus in _campusLocations) {
      if (campus.keywords.any((keyword) => location.contains(keyword))) {
        return campus;
      }
    }
    return null;
  }

  static String _formatIcsDate(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}'
        'T${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}00';
  }

  static String _escapeIcsText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('\n', '\\n')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;');
  }
}

class _CampusGeoReference {
  final String fullName;
  final double latitude;
  final double longitude;
  final List<String> keywords;

  const _CampusGeoReference({
    required this.fullName,
    required this.latitude,
    required this.longitude,
    required this.keywords,
  });
}
