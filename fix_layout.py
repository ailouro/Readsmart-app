import re
content = open('lib/screens/teacher_dashboard.dart', 'r', encoding='utf-8').read()
match = re.search(r'Row\(\s*mainAxisAlignment: MainAxisAlignment\.spaceBetween,\s*children: \[\s*(const SizedBox\(height: 20\),.*?)(const ComicBadgeHeader\(title: "YOUR CLASSES"\),)', content, re.DOTALL)
if match:
    injected_code = match.group(1)
    content = content[:match.start(1)] + content[match.end(1):]
    row_start_idx = match.start(0)
    content = content[:row_start_idx] + injected_code + content[row_start_idx:]
    open('lib/screens/teacher_dashboard.dart', 'w', encoding='utf-8').write(content)
    print("FIXED")
else:
    print("NOT FOUND")
