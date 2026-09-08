import re
content = open('lib/screens/teacher_dashboard.dart', encoding='utf-8').read()

# Add _selectedTestType state variable
pattern1 = re.compile(r'Set<dynamic> _selectedStoryIds = \{\};')
content = content.replace(
    'Set<dynamic> _selectedStoryIds = {};',
    'Set<dynamic> _selectedStoryIds = {};\n    String _selectedTestType = "pre_test";'
)

# Update _assignSelectedStories to include test_type
pattern2 = re.compile(r'body: jsonEncode\(\{"story_id": _selectedStoryIds\.toList\(\)\}\),')
content = content.replace(
    'body: jsonEncode({"story_id": _selectedStoryIds.toList()}),',
    'body: jsonEncode({"story_id": _selectedStoryIds.toList(), "test_type": _selectedTestType}),'
)

# Add UI segment just above Assign button
# The assign button is inside an 'if (_selectedStoryIds.isNotEmpty)' block usually.
# Let's find "if (_selectedStoryIds.isNotEmpty)" in the build method.
pattern3 = re.compile(r'if \(_selectedStoryIds\.isNotEmpty\)\s*Padding\(')
if not pattern3.search(content):
    print('Pattern 3 not found')
else:
    new_ui = '''if (_selectedStoryIds.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: Row(
                  children: [
                    const Text(
                      "Phase: ",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text("Pre-test", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        value: "pre_test",
                        groupValue: _selectedTestType,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setState(() => _selectedTestType = val!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text("Post-test", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        value: "post_test",
                        groupValue: _selectedTestType,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setState(() => _selectedTestType = val!),
                      ),
                    ),
                  ],
                ),
              ),
            if (_selectedStoryIds.isNotEmpty)
              Padding('''
    content = re.sub(pattern3, new_ui, content)

open('lib/screens/teacher_dashboard.dart', 'w', encoding='utf-8').write(content)
print('Updated teacher_dashboard.dart')
