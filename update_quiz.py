import re
content = open('lib/screens/quiz_screen.dart', encoding='utf-8').read()

# Add testType to constructor
pattern1 = re.compile(r'final int\? studentId;')
content = content.replace(
    'final int? studentId;',
    'final int? studentId;\n  final String testType;'
)

pattern2 = re.compile(r'this\.studentId,')
content = content.replace(
    'this.studentId,',
    'this.studentId,\n    this.testType = "post_test",'
)

# Update _submitQuiz
pattern4 = re.compile(r'"test_type": "post_test",')
content = content.replace(
    '"test_type": "post_test",',
    '"test_type": widget.testType,'
)

open('lib/screens/quiz_screen.dart', 'w', encoding='utf-8').write(content)
print('Updated quiz_screen.dart')
