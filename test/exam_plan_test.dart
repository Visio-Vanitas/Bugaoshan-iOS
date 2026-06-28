import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/pages/campus/exam_plan/models/exam_info.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/ics_service.dart';

void main() {
  group('Exam plan parsing', () {
    test('parses highlighted same-day exam card', () {
      final exams = ZhjwApiService.parseExamCardsHtml('''
<div class="widget-box widget-color-green">
  <div class="widget-header">
    <h5 class="widget-title smaller">高等数学A</h5>
  </div>
  <div class="widget-body">
    <div class="widget-main">
      <div>
      第18周&nbsp;2026-06-27&nbsp;星期六&nbsp;09:00-11:00</br>
      地点:&nbsp;江安一教A101</br>
      座位号:&nbsp;12</br>
      准考证号:&nbsp;SCU20260627</br>
      <span>考试提示信息：&nbsp;请携带学生证</span>
      </div>
    </div>
  </div>
</div>
''');

      expect(exams, hasLength(1));
      expect(exams.single.courseName, '高等数学A');
      expect(exams.single.week, '第 18 周');
      expect(exams.single.date, '2026-06-27');
      expect(exams.single.weekday, '星期六');
      expect(exams.single.timeRange, '09:00-11:00');
      expect(exams.single.location, '江安一教A101');
      expect(exams.single.seatNumber, '12');
      expect(exams.single.ticketNumber, 'SCU20260627');
      expect(exams.single.tip, '请携带学生证');
    });
  });

  group('Exam plan ICS export', () {
    test('exports exams as calendar events', () {
      final ics = IcsService.genExamIcs(
        exams: const [
          ExamInfo(
            courseName: '高等数学A',
            week: '第 18 周',
            date: '2026-06-27',
            weekday: '星期六',
            timeRange: '09:00-11:00',
            location: '江安一教A101',
            seatNumber: '12',
            ticketNumber: 'SCU20260627',
            tip: '请携带学生证',
          ),
        ],
      );

      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('DTSTART;TZID=Asia/Shanghai:20260627T090000'));
      expect(ics, contains('DTEND;TZID=Asia/Shanghai:20260627T110000'));
      expect(ics, contains('SUMMARY:高等数学A考试'));
      expect(ics, contains('LOCATION:江安一教A101'));
      expect(ics, contains('座位号: 12'));
    });

    test('removes finished marker from exported calendar', () {
      final ics = IcsService.genExamIcs(
        exams: const [
          ExamInfo(
            courseName: '高等数学A（已结束）',
            week: '第 18 周',
            date: '2026-06-27',
            weekday: '星期六',
            timeRange: '09:00-11:00',
            location: '江安一教A101',
            seatNumber: '12',
            ticketNumber: '',
            tip: '无',
          ),
        ],
      );

      expect(ics, contains('SUMMARY:高等数学A考试'));
      expect(ics, isNot(contains('（已结束）')));
    });
  });
}
