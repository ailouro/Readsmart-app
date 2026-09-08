import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class StoryEditorScreen extends StatefulWidget {
  final dynamic story;
  final String baseUrl;

  const StoryEditorScreen({
    super.key,
    required this.story,
    required this.baseUrl,
  });

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  final PageController _pageController = PageController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  int _currentPage = 0;

  final TextEditingController _scriptController = TextEditingController();
  bool _isSaving = false;
  bool _isGeneratingVoice = false;
  bool _isPlayingAudio = false;
  List<dynamic> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.story['pages'] ?? []);
    _loadCurrentSlideScript();

    _scriptController.addListener(_onScriptChanged);

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    });
  }

  void _onScriptChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _loadCurrentSlideScript() {
    _stopAudio();
    if (_pages.isNotEmpty && _currentPage < _pages.length) {
      var rawScripts = _pages[_currentPage]['audio_scripts'];
      if (rawScripts is List && rawScripts.isNotEmpty) {
        _scriptController.text = rawScripts[0].toString();
      } else if (rawScripts is String) {
        _scriptController.text = rawScripts;
      } else {
        _scriptController.text = "";
      }
    }
  }

  Future<void> _stopAudio() async {
    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    }
  }

  Future<void> _scanTextFromImage() async {
    if (_pages.isEmpty || _currentPage >= _pages.length) return;

    // Retrieve image URL
    String rawPath = _pages[_currentPage]['image_path'] ?? '';
    if (rawPath.startsWith('public/')) {
      rawPath = rawPath.replaceFirst('public/', '');
    }
    String cleanBaseUrl = widget.baseUrl.endsWith('/api')
        ? widget.baseUrl.substring(0, widget.baseUrl.length - 4)
        : widget.baseUrl;
    String imageUrl = "$cleanBaseUrl/api/get-image?path=$rawPath";

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Downloading image for scanning...")),
        );
      }

      // 1. Download the image
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {"ngrok-skip-browser-warning": "69420"},
      );

      if (response.statusCode != 200) {
        throw Exception(
          "Failed to download image. Status: ${response.statusCode}",
        );
      }

      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Extracting text via Cloud OCR...")),
          );
        }
        final String base64Img = base64Encode(response.bodyBytes);
        final ocrResponse = await http.post(
          Uri.parse('https://api.ocr.space/parse/image'),
          body: {
            'apikey': 'helloworld',
            'language': 'eng',
            'base64Image': 'data:image/jpeg;base64,$base64Img',
          },
        );

        if (ocrResponse.statusCode == 200) {
          final data = jsonDecode(ocrResponse.body);
          if (data['IsErroredOnProcessing'] == false &&
              data['ParsedResults'] != null) {
            String extracted = "";
            for (var result in data['ParsedResults']) {
              extracted += (result['ParsedText'] ?? "") + "\n";
            }
            if (mounted) {
              setState(() {
                _scriptController.text = extracted.trim();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Text extracted successfully!")),
              );
            }
          } else {
            throw Exception("Could not read text from image.");
          }
        } else {
          throw Exception("Cloud OCR failed (${ocrResponse.statusCode})");
        }
        return;
      }

      // 2. Save it to a temporary file (Android/iOS only)
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/temp_ocr_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(response.bodyBytes);

      // 3. Process with ML Kit
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Extracting text...")));
      }

      final inputImage = InputImage.fromFilePath(file.path);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      // 4. Update UI
      if (mounted) {
        setState(() {
          _scriptController.text = recognizedText.text;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Text extracted successfully!")),
        );
      }

      // 5. Cleanup
      textRecognizer.close();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to extract text: $e")));
      }
    }
  }

  void _goToPreviousSlide() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextSlide() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _toggleAudioPlayback() async {
    if (_isPlayingAudio) {
      await _audioPlayer.pause();
      setState(() {
        _isPlayingAudio = false;
      });
    } else {
      try {
        String cleanBaseUrl = widget.baseUrl.endsWith('/api')
            ? widget.baseUrl.substring(0, widget.baseUrl.length - 4)
            : widget.baseUrl;

        dynamic slideIdentifier = _currentPage;
        if (_pages.isNotEmpty && _currentPage < _pages.length) {
          slideIdentifier = _pages[_currentPage]['id'] ?? _currentPage;
        }

        String audioUrl =
            "$cleanBaseUrl/api/stories/${widget.story['id']}/slides/$slideIdentifier/audio";

        setState(() {
          _isPlayingAudio = true;
        });

        final response = await http.get(
          Uri.parse(audioUrl),
          headers: const {"ngrok-skip-browser-warning": "69420"},
        );

        if (!mounted) return;

        if (response.statusCode == 200) {
          await _audioPlayer.play(BytesSource(response.bodyBytes));
        } else if (response.statusCode == 404) {
          throw Exception(
            "Audio not found on server for Slide ${_currentPage + 1}. Click 'Create Voice' first!",
          );
        } else {
          throw Exception(
            "Failed to download audio. Status: ${response.statusCode}",
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll("Exception: ", "")),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _saveSlideScript() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final slideIdentifier = _currentPage;

      final url = Uri.parse(
        "${widget.baseUrl}/api/stories/${widget.story['id']}/slides/$slideIdentifier/update-script",
      );

      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420",
        },
        body: jsonEncode({"audio_script": _scriptController.text}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _pages[_currentPage]['audio_scripts'] = [_scriptController.text];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Slide ${_currentPage + 1} script saved! 💾"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(
          "Failed to save script. Status: ${response.statusCode}",
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving script: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _generateAiVoice() async {
    if (_scriptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please type a script first before generating AI voice! ⚠️",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingVoice = true;
    });

    try {
      dynamic slideIdentifier = _currentPage;
      if (_pages.isNotEmpty && _currentPage < _pages.length) {
        slideIdentifier = _pages[_currentPage]['id'] ?? _currentPage;
      }

      final url = Uri.parse(
        "${widget.baseUrl}/api/stories/${widget.story['id']}/slides/$slideIdentifier/generate-tts",
      );

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420",
        },
        body: jsonEncode({
          "text": _scriptController.text,
          "script_index": 0,
          "lang": "tl",
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Voice created for Slide ${_currentPage + 1}! Press 'Play Voice Preview' to test. 🤖🎙️",
            ),
            backgroundColor: Colors.blueAccent,
          ),
        );
      } else {
        throw Exception(
          "Failed to generate voice. Status: ${response.statusCode}",
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error generating voice: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingVoice = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scriptController.removeListener(_onScriptChanged);
    _audioPlayer.dispose();
    _pageController.dispose();
    _scriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String cleanBaseUrl = widget.baseUrl.endsWith('/api')
        ? widget.baseUrl.substring(0, widget.baseUrl.length - 4)
        : widget.baseUrl;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text("Edit: ${widget.story['title'] ?? 'Story'}"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true);
          },
        ),
      ),
      body: _pages.isEmpty
          ? const Center(
              child: Text(
                "No slides to edit.",
                style: TextStyle(color: Colors.white),
              ),
            )
          : Column(
              children: [
                // 1. TOP SLIDE NAVIGATION CONTROLS
                Container(
                  color: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _currentPage > 0 ? _goToPreviousSlide : null,
                        icon: const Icon(Icons.arrow_back_ios),
                        color: _currentPage > 0
                            ? Colors.amberAccent
                            : Colors.grey[700],
                      ),
                      Text(
                        "Editing Slide ${_currentPage + 1} of ${_pages.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        onPressed: _currentPage < _pages.length - 1
                            ? _goToNextSlide
                            : null,
                        icon: const Icon(Icons.arrow_forward_ios),
                        color: _currentPage < _pages.length - 1
                            ? Colors.amberAccent
                            : Colors.grey[700],
                      ),
                    ],
                  ),
                ),

                // 2. QUICK JUMP SLIDE CHIPS
                Container(
                  height: 48,
                  color: Colors.grey[850],
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pages.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (context, idx) {
                      bool isSelected = idx == _currentPage;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text("Slide ${idx + 1}"),
                          selected: isSelected,
                          selectedColor: Colors.amber[700],
                          backgroundColor: Colors.grey[800],
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              _pageController.animateToPage(
                                idx,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),

                // 3. SLIDE IMAGE & SUBTITLE PREVIEW AREA
                Expanded(
                  flex: 2,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    // ENABLE MOUSE DRAG ON WEB
                    scrollBehavior: const MaterialScrollBehavior().copyWith(
                      dragDevices: {
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.touch,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                    ),
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                      _loadCurrentSlideScript();
                    },
                    itemBuilder: (context, index) {
                      String pageImagePath = _pages[index]['image_path'] ?? "";
                      String imageUrl =
                          "$cleanBaseUrl/api/get-image?path=$pageImagePath";

                      return Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Slide Image
                          Image.network(
                            imageUrl,
                            headers: const {
                              "ngrok-skip-browser-warning": "69420",
                            },
                            fit: BoxFit.contain,
                            width: double.infinity,
                            errorBuilder: (c, o, s) => const Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                          // Live Subtitle Overlay
                          if (_scriptController.text.trim().isNotEmpty)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.amberAccent.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                _scriptController.text,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                // 4. BOTTOM EDITING CONTROLS
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.black,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "NARRATOR SCRIPT / TEXT FOR SLIDE ${_currentPage + 1}:",
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            tooltip: "Extract Text from Image",
                            icon: const Icon(
                              Icons.document_scanner,
                              color: Colors.blueAccent,
                            ),
                            onPressed: _scanTextFromImage,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _scriptController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText:
                              "Type the story line or narrator script for Slide ${_currentPage + 1} here...",
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.grey[800],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // PLAYBACK PREVIEW BUTTON
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPlayingAudio
                              ? Colors.orange[800]
                              : Colors.teal[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: Icon(
                          _isPlayingAudio ? Icons.pause : Icons.play_arrow,
                        ),
                        label: Text(
                          _isPlayingAudio
                              ? "Pause Audio"
                              : "Play Voice Preview",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isSaving || _isGeneratingVoice
                            ? null
                            : _toggleAudioPlayback,
                      ),
                      const SizedBox(height: 8),

                      // SAVE & CREATE VOICE BUTTONS
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber[700],
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(
                                _isSaving ? "Saving..." : "Save Text",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: _isSaving || _isGeneratingVoice
                                  ? null
                                  : _saveSlideScript,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              icon: _isGeneratingVoice
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.record_voice_over),
                              label: Text(
                                _isGeneratingVoice
                                    ? "Creating..."
                                    : "Create Voice",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: _isSaving || _isGeneratingVoice
                                  ? null
                                  : _generateAiVoice,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
