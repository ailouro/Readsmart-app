content = open('lib/screens/teacher_dashboard.dart', 'r', encoding='utf-8').read()
idx = content.find("LEARNERS' RECORDS")
print(content[idx-300:idx+300])
