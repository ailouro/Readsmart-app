with open('lib/screens/student_dashboard.dart', 'r', encoding='utf-8') as f:
    c = f.read()
if 'responsive_layout.dart' not in c:
    c = c.replace("import '../services/config.dart';", "import '../services/config.dart';\nimport '../widgets/responsive_layout.dart';")
    with open('lib/screens/student_dashboard.dart', 'w', encoding='utf-8') as f:
        f.write(c)
print("Import check done.")
