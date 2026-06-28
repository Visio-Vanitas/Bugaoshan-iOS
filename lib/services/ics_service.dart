import 'package:flutter/material.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/campus/exam_plan/models/exam_info.dart';

class IcsService {
  const IcsService._();

  static String genIcs({
    required ScheduleConfig config,
    required List<Course> courses,
    required String teacherLabel,
  }) {
    final buffer = StringBuffer();
    _writeCalendarHeader(buffer, 'Course Schedule');

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

        final dtStart = _combineDateTime(courseDate, startTime);
        final dtEnd = _combineDateTime(courseDate, endTime);

        buffer.writeln('BEGIN:VEVENT');
        buffer.writeln('DTSTART;TZID=Asia/Shanghai:${_formatIcsDate(dtStart)}');
        buffer.writeln('DTEND;TZID=Asia/Shanghai:${_formatIcsDate(dtEnd)}');
        buffer.writeln('SUMMARY:${_escapeIcsText(course.name)}');
        buffer.writeln('LOCATION:${_escapeIcsText(course.location)}');
        buffer.writeln(
          'DESCRIPTION:${_escapeIcsText('$teacherLabel: ${course.teacher}')}',
        );
        buffer.writeln('UID:${course.id}_$week@bugaoshan');
        buffer.writeln('END:VEVENT');
      }
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static String genExamIcs({required List<ExamInfo> exams}) {
    final buffer = StringBuffer();
    _writeCalendarHeader(buffer, 'Exam Schedule');

    for (var i = 0; i < exams.length; i++) {
      final exam = exams[i];
      final range = _parseExamDateTimeRange(exam);
      if (range == null) continue;
      final courseName = _cleanExamCalendarText(exam.courseName);

      final description = [
        exam.week,
        '座位号: ${exam.seatNumber}',
        if (exam.ticketNumber.isNotEmpty) '准考证号: ${exam.ticketNumber}',
        if (exam.tip != '无') '提示: ${exam.tip}',
      ].join('\n');

      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln(
        'DTSTART;TZID=Asia/Shanghai:${_formatIcsDate(range.start)}',
      );
      buffer.writeln('DTEND;TZID=Asia/Shanghai:${_formatIcsDate(range.end)}');
      buffer.writeln('SUMMARY:${_escapeIcsText('${courseName}考试')}');
      buffer.writeln('LOCATION:${_escapeIcsText(exam.location)}');
      buffer.writeln('DESCRIPTION:${_escapeIcsText(description)}');
      buffer.writeln(
        'UID:exam_${exam.date}_${i}_${courseName.hashCode}@bugaoshan',
      );
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
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
