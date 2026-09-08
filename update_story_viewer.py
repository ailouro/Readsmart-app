import re
content = open('lib/screens/story_view_screen.dart', encoding='utf-8').read()

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

# Pass testType to QuizScreen
pattern3 = re.compile(r'builder: \(context\) => QuizScreen\(')
content = content.replace(
    'builder: (context) => QuizScreen(',
    'builder: (context) => QuizScreen(\n                            testType: widget.testType,'
)

# Update _submitReadingResult
pattern4 = re.compile(r'"test_type": "post_test",')
content = content.replace(
    '"test_type": "post_test",',
    '"test_type": widget.testType,'
)

open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8').write(content)
print('Updated story_view_screen.dart')
