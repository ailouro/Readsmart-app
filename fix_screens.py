import re
# 1. Fix story_view_screen.dart
content1 = open('lib/screens/story_view_screen.dart', encoding='utf-8').read()
content1 = content1.replace(
    '  final int studentId;',
    '  final int studentId;\n  final String testType;'
)
content1 = content1.replace(
    '    this.studentId = 1,\n  });',
    '    this.studentId = 1,\n    this.testType = "post_test",\n  });'
)
open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8').write(content1)

# 2. Fix quiz_screen.dart
content2 = open('lib/screens/quiz_screen.dart', encoding='utf-8').read()
content2 = content2.replace(
    '  final List<String> struggledWords;',
    '  final List<String> struggledWords;\n  final String testType;'
)
open('lib/screens/quiz_screen.dart', 'w', encoding='utf-8').write(content2)

print("Fixed screens")
