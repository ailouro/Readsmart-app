import re

with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

start_idx = text.find('  @override\n  Widget build(BuildContext context) {')
end_idx = text.find('class RemediationDialog', start_idx)

if start_idx == -1 or end_idx == -1:
    print('Could not find boundaries')
    exit(1)

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
              color: const Color(0xFF212121),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.story['title'] ?? 'Story',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            // MAIN BODY WITH COMIC BACKGROUND
            Expanded(
              child: Stack(
                children: [
                  // COMIC BACKGROUND (Red Dotted)
                  Positioned.fill(
                    child: CustomPaint(painter: ComicDotsPainter()),
                  ),
                  
                  Column(
                    children: [
                      // PAGE VIEW (IMAGE PANEL)
                      Expanded(
                        child: PageView.builder(
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
                              padding: const EdgeInsets.only(left: 20, right: 20, top: 40, bottom: 10),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // White Image Box with Black Border
                                  Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(color: Colors.black, width: 6),
                                    ),
                                    padding: const EdgeInsets.all(4.0),
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.contain,
                                      headers: const {"ngrok-skip-browser-warning": "69420"},
                                      errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, size: 60, color: Colors.grey),
                                    ),
                                  ),
                                  // YELLOW SLIDE BADGE
                                  Positioned(
                                    top: -20,
                                    left: 0, right: 0,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEB3B), // Yellow
                                          border: Border.all(color: Colors.black, width: 4),
                                        ),
                                        child: Text(
                                          "Slide  of ",
                                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // RED X CLOSE BUTTON
                                  Positioned(
                                    top: -24,
                                    right: -24,
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF44336), // Red
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.black, width: 4),
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        child: const Icon(Icons.close, color: Colors.white, size: 28),
                                      ),
                                    ),
                                  ),
                                  // LEFT ARROW
                                  if (index > 0)
                                    Positioned(
                                      left: -24,
                                      top: 0,
                                      bottom: 0,
                                      child: Center(
                                        child: GestureDetector(
                                          onTap: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: const Color(0xFFF44336), width: 3),
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            child: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFF44336), size: 24),
                                          ),
                                        ),
                                      ),
                                    ),
                                  // RIGHT ARROW
                                  if (index < pages.length - 1)
                                    Positioned(
                                      right: -24,
                                      top: 0,
                                      bottom: 0,
                                      child: Center(
                                        child: GestureDetector(
                                          onTap: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: const Color(0xFFF44336), width: 3),
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            child: const Icon(Icons.arrow_forward_ios, color: Color(0xFFF44336), size: 24),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // WORD ATTEMPTS PANEL
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black, width: 5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Attempt:  / ",
                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                if (_isAssessmentPassed)
                                  const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                                      SizedBox(width: 4),
                                      Text("Passed!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // PILLS
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: List.generate(_targetWords.length, (idx) {
                                WordStatus wordObj = _targetWords[idx];
                                bool isCurrentTarget = (idx == _currentWordIndex);
                                
                                Color bgColor = Colors.white;
                                Color textColor = Colors.black;
                                
                                if (wordObj.isCorrect) {
                                  bgColor = const Color(0xFF69F0AE); // Green
                                } else if (wordObj.isFailed) {
                                  bgColor = const Color(0xFFFF5252); // Red
                                } else if (isCurrentTarget) {
                                  bgColor = const Color(0xFFFFD740); // Yellow
                                }
                                
                                return GestureDetector(
                                  onTap: () => _showWordDefinition(wordObj.originalWord),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      border: Border.all(color: Colors.black, width: 2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isCurrentTarget)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 4.0),
                                            child: Text("👉", style: TextStyle(fontSize: 14)),
                                          ),
                                        Text(
                                          wordObj.originalWord,
                                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                _spokenText.isNotEmpty ? "Heard: \\"\\"" : "Heard: \\"........\\"",
                                style: const TextStyle(color: Colors.black87, fontStyle: FontStyle.italic, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // CONTROLS PANEL
                      Container(
                        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 5),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _startOralReading,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF44336), // Red
                                  border: Border.all(color: Colors.black, width: 4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(_isListening ? Icons.mic_off : Icons.mic, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isListening ? "Stop Oral Reading" : "Start Oral Reading",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _speakWebSpeech(0, currentScripts.join(" ")),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB71C1C), // Dark Red
                                        border: Border.all(color: Colors.black, width: 4),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.record_voice_over, color: Colors.white, size: 20),
                                          SizedBox(width: 6),
                                          Text("Listen (Web Speech)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {},
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2962FF), // Blue
                                      border: Border.all(color: Colors.black, width: 4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.volume_up, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {},
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF424242), // Grey
                                      border: Border.all(color: Colors.black, width: 4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.auto_awesome, color: Colors.amber),
                                  ),
                                ),
                              ],
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
'''

new_file = text[:start_idx] + new_build + '\n\n' + text[end_idx:]

with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_file)

print("Replaced build method with EXACT comic layout.")
