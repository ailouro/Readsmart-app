import re

with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

start_marker = 'void _advanceToNextSlide() async {'
end_marker = 'void _triggerRemediationPopup(List<WordStatus> failedWords)'

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx == -1 or end_idx == -1:
    print('Could not find markers')
    exit(1)

new_method = '''void _advanceToNextSlide() async {
    List<dynamic> pages = widget.story['pages'] ?? [];
    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      int elapsedSeconds = 120;
      if (_readingStartTime != null) {
        elapsedSeconds = DateTime.now().difference(_readingStartTime!).inSeconds;
      }

      int totalWordsCount = 0;
      int correctWordsCount = 0;

      // Ensure the current page is saved to the cache
      _pageTargetWords[_currentPage] = List.from(_targetWords);

      List<dynamic> allPages = widget.story['pages'] ?? [];
      for (int i = 0; i < allPages.length; i++) {
        if (_pageTargetWords.containsKey(i)) {
          var list = _pageTargetWords[i]!;
          totalWordsCount += list.length;
          correctWordsCount += list.where((w) => w.isCorrect).length;
        } else {
          String pageText = "";
          var rawScripts = allPages[i]['audio_scripts'];
          if (rawScripts is List) {
            pageText = rawScripts.join(" ");
          } else if (rawScripts is String) {
            pageText = rawScripts;
          }
          if (pageText.trim().isNotEmpty) {
            int count = pageText.split(RegExp(r'\\s+')).where((w) => w.isNotEmpty).length;
            totalWordsCount += count;
          }
        }
      }

      double accuracy = totalWordsCount > 0 ? (correctWordsCount / totalWordsCount) * 100.0 : 0.0;
      accuracy = double.parse(accuracy.toStringAsFixed(2));

      try {
        await http.post(
          Uri.parse("/api/student/progress"),
          headers: {
            "Content-Type": "application/json",
            "ngrok-skip-browser-warning": "69420",
          },
          body: jsonEncode({
            "user_id": widget.studentId,
            "story_id": widget.story['id'] ?? widget.story['_id'],
            "quiz_score": 0,
            "total_questions": 0,
            "oral_fluency_accuracy": accuracy,
            "time_on_task": elapsedSeconds > 0 ? elapsedSeconds : 1,
            "test_type": "post_test",
          }),
        );
      } catch (e) {}

      // Save locally so the Dashboard shows "Done Reading" immediately!
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        'story__reading_completed',
        true,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuizScreen(
            storyId: widget.story['id'] ?? widget.story['_id'],
            studentId: widget.studentId,
            baseUrl: widget.baseUrl,
            oralAccuracy: accuracy,
            totalWords: _totalWordsInStory,
            readingTimeSeconds: elapsedSeconds > 0 ? elapsedSeconds : 1,
          ),
        ),
      );
    }
  }

  //
  '''

new_content = content[:start_idx] + new_method + content[end_idx:]

with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)
print("Success")
