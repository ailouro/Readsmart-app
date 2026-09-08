import re
content = open('lib/screens/class_dashboard_screen.dart', encoding='utf-8').read()

pattern = re.compile(r'builder: \(context\) => StoryViewerScreen\(\s*story: story,\s*baseUrl: baseUrl,\s*studentId: widget\.studentId,\s*\),')
new_call = '''builder: (context) {
                      String tType = "post_test";
                      if (story['pivot'] != null && story['pivot']['test_type'] != null) {
                        tType = story['pivot']['test_type'];
                      }
                      return StoryViewerScreen(
                        story: story,
                        baseUrl: baseUrl,
                        studentId: widget.studentId,
                        testType: tType,
                      );
                    },'''

content = content.replace(
    '''builder: (context) => StoryViewerScreen(
                      story: story,
                      baseUrl: baseUrl,
                      studentId: widget.studentId,
                    ),''',
    new_call
)

open('lib/screens/class_dashboard_screen.dart', 'w', encoding='utf-8').write(content)
print('Updated class_dashboard_screen.dart')
