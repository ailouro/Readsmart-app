import sys

with open("d:/flutter/readsmart/theapp/lib/screens/teacher_dashboard.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
for idx, line in enumerate(lines):
    # Find the line that starts with Row( right after the SizedBox(height: 20) inside _StudentsTabState
    # Specifically around line 1527-1528 based on previous output
    if "const SizedBox(height: 20)," in line and idx + 1 < len(lines) and "Row(" in lines[idx+1] and "mainAxisAlignment: MainAxisAlignment.spaceBetween," in lines[idx+2]:
        new_lines.append(line)
        new_lines.append("                  ],\n")
        new_lines.append("                ),\n")
    else:
        new_lines.append(line)

with open("d:/flutter/readsmart/theapp/lib/screens/teacher_dashboard.dart", "w", encoding="utf-8") as f:
    f.writelines(new_lines)
