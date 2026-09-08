
content = open('lib/screens/story_view_screen.dart', encoding='utf-8').read()
old_code = '''        List<String> wordsOnly = failedWords.map((w) => w.cleanWord).toList();
        for (int i = 0; i < wordsOnly.length; i++) {
          request.fields['words[]'] = wordsOnly[i];
        }'''
new_code = '''        List<String> wordsOnly = failedWords.map((w) => w.cleanWord).toList();
        for (String word in wordsOnly) {
          request.files.add(http.MultipartFile.fromString('words[]', word));
        }'''
open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8').write(content.replace(old_code, new_code))

