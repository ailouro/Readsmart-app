import sys
import re

with open("d:/flutter/readsmart/theapp/lib/screens/teacher_dashboard.dart", "r", encoding="utf-8") as f:
    content = f.read()

pattern = r"(builder:\s*\(context\)\s*=>\s*_ClassDetailsSheet\(\s*item:\s*item,\s*className:\s*className,\s*grade:\s*grade,\s*section:\s*section,)([\s]*\),)"
replacement = r"\1\n          buildRecordCard: _buildLearnerRecordCard,\2"

new_content = re.sub(pattern, replacement, content)

if content == new_content:
    print("Failed to replace using regex")
else:
    print("Regex replacement successful")
    with open("d:/flutter/readsmart/theapp/lib/screens/teacher_dashboard.dart", "w", encoding="utf-8") as f:
        f.write(new_content)
