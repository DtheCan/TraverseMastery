import 'package:flutter/material.dart';

class ResultSectionTitle extends StatelessWidget {
  final String title;
  const ResultSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0), // Добавлен горизонтальный отступ
      child: Text(
        title.toUpperCase(), // Заголовок большими буквами для выделения
        style: Theme.of(context).textTheme.titleMedium?.copyWith( // Изменено на titleMedium для лучшей иерархии
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600, // Чуть менее жирный, чем bold
          letterSpacing: 0.5, // Небольшой интервал между буквами
        ),
      ),
    );
  }
}

class ResultDataRow extends StatelessWidget {
  final String label;
  final String value;
  final bool? isGood; // Для опциональной подсветки (зеленый/красный)
  final IconData? icon; // Опциональная иконка перед label

  const ResultDataRow({
    super.key,
    required this.label,
    required this.value,
    this.isGood,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color? valueColor;
    final ThemeData theme = Theme.of(context);

    if (isGood != null) {
      valueColor = isGood!
          ? (theme.brightness == Brightness.dark ? Colors.green.shade300 : Colors.green.shade700)
          : (theme.brightness == Brightness.dark ? Colors.red.shade300 : Colors.red.shade700);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Выравнивание по верху, если текст многострочный
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 3, // Даем больше места для метки
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2, // Меньше места для значения, но достаточно
            child: Text(
              value,
              textAlign: TextAlign.end, // Выравниваем значение по правому краю
              style: theme.textTheme.bodyMedium?.copyWith( // Изменено на bodyMedium для консистентности
                fontWeight: FontWeight.w600, // Слегка жирнее обычного
                color: valueColor ?? theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Виджет для отображения данных в виде таблицы (простой вариант)
class DataTableWidget extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;

  const DataTableWidget({
    super.key,
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return SingleChildScrollView( // Для горизонтальной прокрутки, если таблица широкая
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20.0, // Расстояние между колонками
        headingRowHeight: 40.0, // Высота строки заголовков
        dataRowMinHeight: 38.0, // Минимальная высота строки данных
        dataRowMaxHeight: 48.0, // Максимальная высота строки данных (для переноса текста)
        headingTextStyle: theme.textTheme.labelLarge?.copyWith( // Изменено на labelLarge
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
        dataTextStyle: theme.textTheme.bodySmall, // Изменено на bodySmall для компактности
        border: TableBorder.all(
          width: 1.0,
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4.0),
        ),
        columns: columns.map((colName) => DataColumn(label: Text(colName))).toList(),
        rows: rows.map((rowData) {
          return DataRow(
            cells: rowData.map((cellData) => DataCell(Text(cellData))).toList(),
          );
        }).toList(),
      ),
    );
  }
}
