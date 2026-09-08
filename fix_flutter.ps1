$content = Get-Content 'lib/screens/story_view_screen.dart' -Raw
$old_code = "        List<String> wordsOnly = failedWords.map((w) => w.cleanWord).toList();
        for (int i = 0; i < wordsOnly.length; i++) {
          request.fields['words[$i]'] = wordsOnly[i];
        }"
$new_code = "        List<String> wordsOnly = failedWords.map((w) => w.cleanWord).toList();
        for (String word in wordsOnly) {
          request.files.add(http.MultipartFile.fromString('words[]', word));
        }
        request.fields['words_json'] = jsonEncode(wordsOnly);"
$content = $content.Replace($old_code, $new_code)
Set-Content 'lib/screens/story_view_screen.dart' -Value $content
