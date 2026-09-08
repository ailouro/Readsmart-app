import re

with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# We want to replace the uild(BuildContext context) method of _StoryViewerScreenState
# We'll locate @override\n  Widget build(BuildContext context) { and replace until the end of the class.
# Wait, the class _StoryViewerScreenState is the last big class, but there's _DefinitionSheet after it!
# So we need to find Widget build(BuildContext context) { inside _StoryViewerScreenState.
# And we end the replacement at the first class _DefinitionSheet

start_idx = text.find('  @override\n  Widget build(BuildContext context) {')
end_idx = text.find('class _DefinitionSheet', start_idx)

if start_idx == -1 or end_idx == -1:
    print('Could not find boundaries')
    exit(1)

# Find the exact closing brace of _StoryViewerScreenState
# It should be the last } before class _DefinitionSheet
last_brace = text.rfind('}', start_idx, end_idx)

new_build = '''  @override
  Widget build(BuildContext context) {
    if (widget.story.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No story details found.")),
      );
    }
    List<dynamic> pages = widget.story['pages'] ?? [];
    if (pages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Story View")),
        body: const Center(child: Text("This story has no pages yet.")),
      );
    }

    String cleanBaseUrl = widget.baseUrl.endsWith('/')
        ? widget.baseUrl.substring(0, widget.baseUrl.length - 1)
        : widget.baseUrl;

    List<dynamic> currentScripts = pages[_currentPage]['scripts'] ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // TOP BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.black,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    widget.story['title'] ?? 'Story',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // MAIN BODY WITH COMIC SUNBURST
            Expanded(
              child: Stack(
                children: [
                  // COMIC BACKGROUND
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ComicSunburstPainter(),
                    ),
                  ),
                  
                  // CONTENT COLUMN
                  Column(
                    children: [
                      // PAGE VIEW
                      Expanded(
                        child: Stack(
                          children: [
                            PageView.builder(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: pages.length,
                              onPageChanged: (index) async {
                                _stopAllAudio();
                                _pageTargetWords[_currentPage] = _targetWords;
                                _pageCurrentWordIndex[_currentPage] = _currentWordIndex;
                                _pageAssessmentPassed[_currentPage] = _isAssessmentPassed;
                                setState(() {
                                  _currentPage = index;
                                  if (_pageTargetWords.containsKey(index)) {
                                    _targetWords = _pageTargetWords[index]!;
                                    _currentWordIndex = _pageCurrentWordIndex[index]!;
                                    _isAssessmentPassed = _pageAssessmentPassed[index]!;
                                  } else {
                                    _setupTargetWords(
                                      (pages[index]['audio_scripts'] is List)
                                          ? (pages[index]['audio_scripts'] as List).join(" ")
                                          : (pages[index]['audio_scripts'] ?? "").toString(),
                                    );
                                  }
                                });
                                final prefs = await SharedPreferences.getInstance();
                                prefs.setInt('story__page', index);
                              },
                              itemBuilder: (context, index) {
                                String pageImagePath = pages[index]['image_path'] ?? "";
                                if (pageImagePath.startsWith('public/')) {
                                  pageImagePath = pageImagePath.replaceFirst('public/', '');
                                }
                                String imageUrl = "/api/get-image?path=";
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // The actual card
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(color: Colors.black, width: 4),
                                        ),
                                        child: Column(
                                          children: [
                                            // RED HEADER
                                            Container(
                                              width: double.infinity,
                                              color: const Color(0xFFE53935),
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                              child: Text(
                                                "Slide  of ",
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                            // IMAGE
                                            Expanded(
                                              child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(8.0),
                                                child: Image.network(
                                                  imageUrl,
                                                  fit: BoxFit.contain,
                                                  headers: const {"ngrok-skip-browser-warning": "69420"},
                                                  errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, size: 60),
                                                ),
                                              ),
                                            ),
                                            // TEXT BUBBLE
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(16.0),
                                              color: const Color(0xFFC4BBA5), // Light brown
                                              child: Text(
                                                (pages[index]['scripts'] ?? []).join(" "),
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Color(0xFF5A4D4A), // Dark brown
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                  fontFamily: 'ComicSans',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // CLOSE BUTTON
                                      Positioned(
                                        top: -12,
                                        right: -12,
                                        child: GestureDetector(
                                          onTap: () => Navigator.pop(context),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE53935),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 3),
                                            ),
                                            padding: const EdgeInsets.all(6),
                                            child: const Icon(Icons.close, color: Colors.white, size: 24),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            // FLOATING ARROWS
                            if (_currentPage > 0)
                              Positioned(
                                left: 8,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: GestureDetector(
                                    onTap: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.red, width: 2),
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.red, size: 20),
                                    ),
                                  ),
                                ),
                              ),
                            if (_currentPage < pages.length - 1)
                              Positioned(
                                right: 8,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: GestureDetector(
                                    onTap: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.red, width: 2),
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(Icons.arrow_forward_ios, color: Colors.red, size: 20),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // CURRENT WORD & BUTTONS
                      Container(
                        width: double.infinity,
                        color: const Color(0xFF6A4E49), // Dark brown area
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Current word",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            // Rich Text logic for target words
                            Wrap(
                              spacing: 6.0,
                              runSpacing: 8.0,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: List.generate(_targetWords.length, (idx) {
                                WordStatus wordObj = _targetWords[idx];
                                bool isCurrentTarget = (idx == _currentWordIndex);
                                
                                if (wordObj.isFailed) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    color: Colors.red,
                                    child: GestureDetector(
                                      onTap: () => _showWordDefinition(wordObj.originalWord),
                                      child: Text(wordObj.originalWord, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                    ),
                                  );
                                } else if (isCurrentTarget) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    color: Colors.green,
                                    child: const Text("........", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                  );
                                } else if (wordObj.isCorrect) {
                                  return GestureDetector(
                                    onTap: () => _showWordDefinition(wordObj.originalWord),
                                    child: Text(wordObj.originalWord, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                                  );
                                } else {
                                  return Text(wordObj.originalWord, style: const TextStyle(color: Colors.white70, fontSize: 18));
                                }
                              }),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                _spokenText.isNotEmpty ? "heard: \\"\\"" : "heard: \\"........\\"",
                                style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // BUTTONS ROW
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            SkewedButton(
                              text: _isListening ? "Stop" : "Read",
                              onPressed: _startOralReading,
                            ),
                            SkewedButton(
                              text: "Listen",
                              onPressed: () => _speakWebSpeech(0, currentScripts.join(" ")),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
'''

new_file = text[:start_idx] + new_build + '\n\n' + text[end_idx:]

with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_file)

print("Replaced build method.")
