import re

with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

prefix_end = text.find('heard: \\"import \\'dart:convert\\';'.replace('\\\\', '\\'))
if prefix_end == -1:
    prefix_end = text.find('heard: \"import \\'dart:convert\\';'.replace('\\\\', '\\'))
if prefix_end == -1:
    prefix_end = text.find('heard: \"import \\'dart:convert')
if prefix_end == -1:
    prefix_end = text.find('heard: \"import \\'dart')
if prefix_end == -1:
    prefix_end = text.find('heard: \"import')

if prefix_end != -1:
    prefix = text[:prefix_end]
    suffix_start = text.rfind('spokenText\\"",')
    if suffix_start != -1:
        fixed = prefix + 'heard: \\"\\\\"",' + text[text.find('\n', suffix_start):]
        with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
            f.write(fixed)
        print("Fixed!")
    else:
        print("Could not find suffix_start")
else:
    print("Could not find prefix_end")
