// lib/widgets/calendar_widget.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_booking/models/reservation_model.dart';
import 'package:flutter_booking/theme/app_theme.dart';

class CalendarWidget extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final List<ReservationModel> reservations;
  final void Function(DateTime selected, DateTime focused) onDaySelected;
  final bool readOnly;

  const CalendarWidget({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.reservations,
    required this.onDaySelected,
    this.readOnly = false,
  });

  List<ReservationModel> _getEventsForDay(DateTime day) {
    return reservations.where((r) {
      return r.startTime.year == day.year &&
          r.startTime.month == day.month &&
          r.startTime.day == day.day &&
          (r.status == 'pending' || r.status == 'confirmed');
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TableCalendar(
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: focusedDay,
          selectedDayPredicate: (day) => isSameDay(selectedDay, day),
          eventLoader: _getEventsForDay,
          onDaySelected: readOnly ? null : onDaySelected,
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: StartingDayOfWeek.monday,
          locale: 'fr_FR',
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
              fontFamily: 'Poppins',
            ),
            leftChevronIcon:
                Icon(Icons.chevron_left_rounded, color: AppColors.primary),
            rightChevronIcon:
                Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            todayTextStyle: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
            selectedDecoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
            markerDecoration: const BoxDecoration(
              color: AppColors.warning,
              shape: BoxShape.circle,
            ),
            outsideDaysVisible: false,
            weekendTextStyle:
                const TextStyle(color: AppColors.error),
            defaultTextStyle:
                const TextStyle(color: AppColors.textPrimary),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            weekendStyle: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}