import sys

with open("d:/flutter/readsmart/theapp/lib/screens/teacher_dashboard.dart", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add buildRecordCard to _ClassDetailsSheet constructor
class_details_sheet_str = """class _ClassDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final String className;
  final String grade;
  final String section;

  const _ClassDetailsSheet({
    required this.item,
    required this.className,
    required this.grade,
    required this.section,
  });"""

class_details_sheet_new = """class _ClassDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final String className;
  final String grade;
  final String section;
  final Widget Function(Map<String, dynamic>)? buildRecordCard;

  const _ClassDetailsSheet({
    required this.item,
    required this.className,
    required this.grade,
    required this.section,
    this.buildRecordCard,
  });"""

if class_details_sheet_str in content:
    content = content.replace(class_details_sheet_str, class_details_sheet_new)
else:
    print("Failed to replace _ClassDetailsSheet constructor")
    # try flexible replace
    idx = content.find("class _ClassDetailsSheet extends StatefulWidget {")
    if idx == -1:
        sys.exit(1)

# 2. Add buildRecordCard parameter to _openClassDetails call
open_class_details_str = """      final result = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _ClassDetailsSheet(
          item: item,
          className: className,
          grade: grade,
          section: section,
        ),
      );"""

open_class_details_new = """      final result = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _ClassDetailsSheet(
          item: item,
          className: className,
          grade: grade,
          section: section,
          buildRecordCard: _buildLearnerRecordCard,
        ),
      );"""

if open_class_details_str in content:
    content = content.replace(open_class_details_str, open_class_details_new)
else:
    print("Failed to replace _openClassDetails")

# 3. Add onTap to ListTile in _ClassDetailsSheetState
list_tile_str = """                              child: ListTile(
                                leading: Container(
                                  width: 45,
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDE047),"""

list_tile_new = """                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    if (widget.buildRecordCard != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => _StudentRecordScreen(
                                            studentName: _safeString(student['name'], 'Student'),
                                            recordCard: widget.buildRecordCard!(student),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: ListTile(
                                leading: Container(
                                  width: 45,
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDE047),"""

if list_tile_str in content:
    content = content.replace(list_tile_str, list_tile_new)
    # Also need to close the Material/InkWell wrappers later... wait!
    # Instead of wrapping the ListTile in Material/InkWell manually, just add onTap directly to ListTile!
    # Let's revert and use onTap on ListTile:
    
    list_tile_str_better = """                              child: ListTile(
                                leading: Container("""
    
    list_tile_new_better = """                              child: ListTile(
                                onTap: () {
                                  if (widget.buildRecordCard != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => _StudentRecordScreen(
                                          studentName: _safeString(student['name'], 'Student'),
                                          recordCard: widget.buildRecordCard!(student),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                leading: Container("""
    content = content.replace(list_tile_str_better, list_tile_new_better)

with open("d:/flutter/readsmart/theapp/lib/screens/teacher_dashboard.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("Modification complete.")
