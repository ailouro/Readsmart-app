import sys

with open("d:/flutter/readsmart/theapp/lib/screens/teacher_dashboard.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Replace _ClassDetailsSheet invocation inside _openClassDetails
target = """        builder: (context) => _ClassDetailsSheet(
          item: item,
          className: className,
          grade: grade,
          section: section,
        ),"""

replacement = """        builder: (context) => _ClassDetailsSheet(
          item: item,
          className: className,
          grade: grade,
          section: section,
          buildRecordCard: _buildLearnerRecordCard,
        ),"""

if target in content:
    content = content.replace(target, replacement)
    print("Replaced _ClassDetailsSheet successfully")
else:
    print("Failed to replace _ClassDetailsSheet")
    sys.exit(1)

with open("d:/flutter/readsmart/theapp/lib/screens/teacher_dashboard.dart", "w", encoding="utf-8") as f:
    f.write(content)
