import re

with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

idx = text.find('class RemediationDialog')
before = text[idx-20:idx]
if '}' in before:
    # it might have one '}', but we need TWO '}' (one for build method, one for the class)
    # let's count them:
    # The build method ends with:
    #     );
    #   }
    # So we want:
    #     );
    #   }
    # }
    text = text.replace('    );\n  }\n\n\nclass RemediationDialog', '    );\n  }\n}\n\n\nclass RemediationDialog')
    text = text.replace('    );\n  }\n\nclass RemediationDialog', '    );\n  }\n}\n\nclass RemediationDialog')

with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
print("Done python fix")
