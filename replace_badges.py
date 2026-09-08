import re

with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# We need to replace from // 2. CURRENT WORD BADGES down to ], right before ), that closes the Column
badges_start = text.find('                // 2. CURRENT WORD BADGES')
if badges_start == -1:
    print('Could not find CURRENT WORD BADGES')
    exit(1)

# Find the end of the Column that contains the badges.
# The Column children end at ], inside Column(children: [ Expanded(...), Container(...) ])
# Let's just find // 2. CURRENT WORD BADGES and then find the end of the build method.
# Wait, it's easier to find the end of Container(
text_after = text[badges_start:]
end_container = text_after.find('              ],\n            ),')
if end_container == -1:
    print('Could not find end of Column')
    exit(1)

end_index = badges_start + end_container

comic_and_controls = '''                // 2. COMIC BUBBLE TEXT DISPLAY
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          offset: Offset(4, 4),
                          blurRadius: 0,
                        )
                      ],
                    ),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: List.generate(_targetWords.length, (idx) {
                        WordStatus wordObj = _targetWords[idx];
                        bool isCurrentTarget = (idx == _currentWordIndex);
                        
                        Color textColor = Colors.black;
                        FontWeight weight = FontWeight.normal;

                        if (wordObj.isCorrect) {
                          textColor = Colors.green;
                          weight = FontWeight.bold;
                        } else if (wordObj.isFailed) {
                          textColor = Colors.red;
                          weight = FontWeight.bold;
                        } else if (isCurrentTarget) {
                          textColor = Colors.blue;
                          weight = FontWeight.bold;
                        }

                        return GestureDetector(
                          onTap: () => _showWordDefinition(wordObj.originalWord),
                          child: Text(
                            wordObj.originalWord,
                            style: TextStyle(
                              fontSize: 22,
                              color: textColor,
                              fontWeight: weight,
                              fontFamily: 'ComicSans',
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                // 3. CONTROLS PANEL
                Container(
                  width: double.infinity,
                  color: Colors.grey[900],
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isListening
                              ? Colors.red
                              : (_currentWordIndex >= _targetWords.length
                                    ? Colors.grey
                                    : Colors.teal),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                        label: Text(
                          _isListening
                              ? "Stop Oral Reading"
                              : (_currentWordIndex < _targetWords.length
                                    ? "Start Oral Reading ???"
                                    : "Completed!"),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _startOralReading,
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: List.generate(currentScripts.length, (
                          sIndex,
                        ) {
                          String currentText = currentScripts[sIndex];
                          bool isThisTtsPlaying =
                              _isPlayingTts && _playingIndex == sIndex;
                          bool isThisServerPlaying =
                              _isPlayingServerAudio && _playingIndex == sIndex;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isThisTtsPlaying
                                          ? Colors.redAccent
                                          : const Color(0xFF9B0505),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: Icon(
                                      isThisTtsPlaying
                                          ? Icons.stop
                                          : Icons.record_voice_over,
                                      size: 18,
                                    ),
                                    label: Text(
                                      isThisTtsPlaying
                                          ? "Stop TTS"
                                          : "Listen (Web Speech)",
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onPressed: _isGenerating
                                        ? null
                                        : () => _speakWebSpeech(
                                            sIndex,
                                            currentText,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  style: IconButton.styleFrom(
                                    backgroundColor: isThisServerPlaying
                                        ? Colors.amber[800]
                                        : Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: Icon(
                                    isThisServerPlaying
                                        ? Icons.stop
                                        : Icons.volume_up,
                                    size: 20,
                                  ),
                                  onPressed: _isGenerating
                                      ? null
                                      : () => _playServerAudio(
                                          sIndex,
                                          cleanBaseUrl,
                                        ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF2D3142),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.amberAccent,
                                    size: 20,
                                  ),
                                  onPressed: _isGenerating
                                      ? null
                                      : () => _generateAIVoice(
                                          sIndex,
                                          currentText,
                                        ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
'''

new_text = text[:badges_start] + comic_and_controls + text[end_index:]
with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_text)
print("Replaced Word Badges with Comic Bubble and Controls Panel!")

