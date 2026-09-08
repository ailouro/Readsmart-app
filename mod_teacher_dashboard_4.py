import sys

with open("d:/flutter/readsmart/theapp/lib/screens/teacher_dashboard.dart", "r", encoding="utf-8") as f:
    content = f.read()

bad_str = """                              child: Material(
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
                                  child: ListTile("""

if bad_str in content:
    content = content.replace(bad_str, "                              child: ListTile(")
    print("Fixed bad string")
else:
    print("Could not find bad string")
    sys.exit(1)

with open("d:/flutter/readsmart/theapp/lib/screens/teacher_dashboard.dart", "w", encoding="utf-8") as f:
    f.write(content)
