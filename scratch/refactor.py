import re
import sys

with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the build method
match = re.search(r'  Widget _buildScriptBox\(.*?\}', content, flags=re.DOTALL)
if not match:
    match = re.search(r'  @override\s+Widget build\(BuildContext context\)\s*\{', content)
    if not match:
        print("Cannot find build method")
        sys.exit(1)

build_start = match.start()
if "Widget _buildScriptBox" in content[:build_start]:
    build_start = content.rfind("  Widget _buildScriptBox", 0, build_start)

# Find end of class
class_end_marker = 'class RemediationDialog'
class_end_idx = content.find(class_end_marker)
if class_end_idx == -1:
    class_end_idx = len(content)

last_brace_idx = content.rfind('}', build_start, class_end_idx)

file_top = content[:build_start]

build_method = """  Widget _buildScriptBox(List<String> currentScripts) {
    if (currentScripts.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amberAccent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(4, 4)),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4.0,
        runSpacing: 4.0,
        children: currentScripts
            .join(" ")
            .split(RegExp(r'\\s+'))
            .where((word) => word.isNotEmpty)
            .map((word) {
          return GestureDetector(
            onTap: () => _showWordDefinition(word),
            child: Text(
              word,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16, // slightly bigger for readability
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: Colors.black54,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> pages = widget.story['pages'] ?? [];
    String cleanBaseUrl = widget.baseUrl.endsWith('/api')
        ? widget.baseUrl.substring(0, widget.baseUrl.length - 4)
        : widget.baseUrl;
    List<String> currentScripts = [];
    if (pages.isNotEmpty && _currentPage < pages.length) {
      var rawScripts = pages[_currentPage]['audio_scripts'];
      if (rawScripts is List) {
        currentScripts = rawScripts.map((e) => e.toString()).toList();
      } else if (rawScripts is String && rawScripts.isNotEmpty) {
        currentScripts = [rawScripts];
      }
    }
    String fullTargetText = currentScripts.join(" ");
    if (_targetWords.isEmpty && fullTargetText.isNotEmpty) {
      _setupTargetWords(fullTargetText);
    }

    // --- EXTRACTED CONTROLS WIDGET ---
    Widget controlsWidget = SingleChildScrollView(
      child: Container(
        width: double.infinity,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentPage > 0
                      ? () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  label: const Text(
                    "Prev",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _advanceToNextSlide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Text(
                        "Next",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: _currentWordIndex < _targetWords.length ? _startOralReading : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? Colors.redAccent
                          : (_currentWordIndex >= _targetWords.length
                              ? Colors.grey
                              : Colors.tealAccent[400]),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.black, width: 3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isListening ? Icons.stop : Icons.mic,
                          color: Colors.black,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isListening
                              ? "Stop Oral Reading"
                              : (_currentWordIndex < _targetWords.length
                                  ? "Start Oral Reading 🎙️"
                                  : "Completed!"),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_targetWords.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                "Attempt: $_currentWordAttempts / $_maxWordAttempts",
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  shadows: [Shadow(color: Colors.white, offset: Offset(1, 1))],
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _targetWords.asMap().entries.map((entry) {
                  int wIndex = entry.key;
                  WordStatus wStatus = entry.value;
                  Color chipColor = Colors.white;
                  Color borderColor = Colors.black;
                  Color textColor = Colors.black;

                  if (wStatus.isCorrect) {
                    chipColor = Colors.greenAccent;
                  } else if (wIndex == _currentWordIndex && _isListening) {
                    chipColor = Colors.amberAccent;
                    borderColor = Colors.redAccent;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: chipColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                    ),
                    child: Text(
                      wStatus.originalWord,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Column(
              children: currentScripts.asMap().entries.map((entry) {
                int sIndex = entry.key;
                String currentText = entry.value;
                bool isThisTtsPlaying = _isPlayingTts && _playingIndex == sIndex;
                bool isThisServerPlaying = _isPlayingServerAudio && _playingIndex == sIndex;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isThisTtsPlaying ? Colors.redAccent : const Color(0xFF9B0505),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Colors.black, width: 2.5),
                              ),
                            ),
                            icon: Icon(isThisTtsPlaying ? Icons.stop : Icons.record_voice_over, size: 18),
                            label: Text(
                              isThisTtsPlaying ? "Stop TTS" : "Listen",
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                            ),
                            onPressed: _isGenerating ? null : () => _speakWebSpeech(sIndex, currentText),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                        ),
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: isThisServerPlaying ? Colors.amber[800] : Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(side: BorderSide(color: Colors.black, width: 2.5)),
                          ),
                          icon: Icon(isThisServerPlaying ? Icons.stop : Icons.volume_up, size: 20),
                          onPressed: _isGenerating ? null : () => _playServerAudio(sIndex, cleanBaseUrl),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                        ),
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF2D3142),
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(side: BorderSide(color: Colors.black, width: 2.5)),
                          ),
                          icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 20),
                          onPressed: _isGenerating ? null : () => _generateAIVoice(sIndex, currentText),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );

    // --- EXTRACTED SKIP BUTTON ---
    Widget skipButtonWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black, width: 2.5),
            ),
            elevation: 4,
          ),
          onPressed: _advanceToNextSlide,
          child: Text(
            _currentPage < pages.length - 1 ? "Skip to Next Slide" : "Finish Reading & Take Quiz",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );

    // --- EXTRACTED PAGE VIEW BUILDER (ONLY IMAGE AND COUNTER) ---
    Widget pageViewWidget = PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) async {
        _pageTargetWords[_currentPage] = List.from(_targetWords);
        _pageCurrentWordIndex[_currentPage] = _currentWordIndex;
        _pageAssessmentPassed[_currentPage] = _isAssessmentPassed;

        setState(() {
          _currentPage = index;
          if (_pageTargetWords.containsKey(index)) {
            _targetWords = List.from(_pageTargetWords[index]!);
            _currentWordIndex = _pageCurrentWordIndex[index]!;
            _isAssessmentPassed = _pageAssessmentPassed[index]!;
          } else {
            _targetWords = [];
            _currentWordIndex = 0;
            _isAssessmentPassed = false;
          }
          _currentWordAttempts = 0;
          _spokenText = "";
          _isListening = false;
        });

        if (!_pageTargetWords.containsKey(index)) {
          _setupTargetWords(pages[index]['audio_scripts']?.toString() ?? "");
        }
        final prefs = await SharedPreferences.getInstance();
        prefs.setInt('story_${widget.story['id']}_page', index);
      },
      itemCount: pages.length,
      itemBuilder: (context, index) {
        var page = pages[index];
        String pageImagePath = page['image_path'] ?? "";
        if (pageImagePath.startsWith('public/')) {
          pageImagePath = pageImagePath.replaceFirst('public/', '');
        }
        String imageUrl = "$cleanBaseUrl/api/get-image?path=$pageImagePath";

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  "Slide ${index + 1} of ${pages.length}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Colors.black, offset: Offset(2, 2))],
                  ),
                ),
              ),
              if (pageImagePath.isNotEmpty)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black, width: 4),
                      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(6, 6))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        headers: const {"ngrok-skip-browser-warning": "69420"},
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.story['title'] ?? "Story Preview",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            shadows: [Shadow(color: Colors.black, offset: Offset(2, 2))],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (_isGenerating)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: StoryComicBackground(
        child: SafeArea(
          child: pages.isEmpty
              ? const Center(
                  child: Text(
                    "No pages found.",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // Force desktop mode for a wider range of screens to ensure Side-by-Side is visible on tablets/laptops
                    bool isDesktop = constraints.maxWidth > 700;

                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 1, // 50% width
                            child: pageViewWidget,
                          ),
                          Expanded(
                            flex: 1, // 50% width
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 20.0),
                              child: Column(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 20.0, top: 10.0),
                                      child: _buildScriptBox(currentScripts)
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3, 
                                    child: controlsWidget
                                  ),
                                  skipButtonWidget,
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          Expanded(
                            flex: 4,
                            child: pageViewWidget,
                          ),
                          Expanded(
                            flex: 2,
                            child: _buildScriptBox(currentScripts)
                          ),
                          Expanded(
                            flex: 3,
                            child: controlsWidget,
                          ),
                          skipButtonWidget,
                        ],
                      );
                    }
                  },
                ),
        ),
      ),
    );
  }
}
"""

new_content = file_top + build_method + '\n\n// 🔊 REMEDIATION POPUP DIALOG COMPONENT\n' + content[class_end_idx:]
with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)
print("done")
