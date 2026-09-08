import sys

with open("d:/flutter/readsmart/theapp/lib/screens/teacher_dashboard.dart", "r", encoding="utf-8") as f:
    content = f.read()

start_str = 'const ComicBadgeHeader(title: "LEARNERS\' RECORDS"),'
end_str = 'const ComicBadgeHeader(title: "YOUR CLASSES"),'

start_idx = content.find(start_str)
end_idx = content.find(end_str)

if start_idx == -1 or end_idx == -1:
    print("Could not find start or end strings")
    sys.exit(1)

# Find the start of the Row that contains "YOUR CLASSES"
row_start_idx = content.rfind('Row(', 0, end_idx)

if row_start_idx == -1:
    print("Could not find Row start")
    sys.exit(1)

# Remove the block
new_content = content[:start_idx] + content[row_start_idx:]

with open("d:/flutter/readsmart/theapp/lib/screens/teacher_dashboard.dart", "w", encoding="utf-8") as f:
    f.write(new_content)

print("Successfully removed LEARNERS' RECORDS section from teacher_dashboard.dart")
