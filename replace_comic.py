import re

with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

start_comic = text.find('                // 2. COMIC BUBBLE TEXT DISPLAY')
start_controls = text.find('                // 3. CONTROLS PANEL')

if start_comic == -1 or start_controls == -1:
    print('Could not find sections.')
    exit(1)

with open('sequential.txt', 'r', encoding='utf-8') as f:
    sequential_text = f.read()

sequential_text = sequential_text.replace(
    '                          return Container(',
    '                          return GestureDetector(\n                            onTap: () => _showWordDefinition(wordObj.originalWord),\n                            child: Container('
)

old_end = '''                            ),
                          );
                        }),'''

new_end = '''                            ),
                          ),
                        );
                        }),'''

sequential_text = sequential_text.replace(old_end, new_end)

new_text = text[:start_comic] + sequential_text + text[start_controls:]

with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_text)
print("Restored BEFORE UI with Dictionary Tap Support!")
