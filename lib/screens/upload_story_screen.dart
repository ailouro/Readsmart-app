import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/config.dart'; // Mula sa config.dart (baseUrl at networkHeaders)
import '../widgets/guide_comic_background.dart';

// Helper model para pagsamahin ang image file, bytes (para sa preview), at text controller
class SlideItem {
  final XFile file;
  final Uint8List bytes;
  final TextEditingController controller;

  SlideItem({
    required this.file,
    required this.bytes,
    required this.controller,
  });
}

class QuizQuestion {
  final TextEditingController questionController = TextEditingController();
  final List<TextEditingController> optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int correctAnswerIndex = 0; // Default to first option
}

class UploadStoryScreen extends StatefulWidget {
  const UploadStoryScreen({super.key});

  @override
  State<UploadStoryScreen> createState() => _UploadStoryScreenState();
}

class _UploadStoryScreenState extends State<UploadStoryScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _coverImage;
  Uint8List? _coverBytes;

  // List ng slides kasama ang script controllers
  final List<SlideItem> _slides = [];

  // List ng quiz questions
  final List<QuizQuestion> _quizQuestions = [];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  bool _isUploading = false;

  void _addQuizQuestion() {
    setState(() {
      _quizQuestions.add(QuizQuestion());
    });
  }

  void _removeQuizQuestion(int index) {
    setState(() {
      _quizQuestions[index].questionController.dispose();
      for (var ctrl in _quizQuestions[index].optionControllers) {
        ctrl.dispose();
      }
      _quizQuestions.removeAt(index);
    });
  }

  // --- 1. PICK COVER IMAGE ---
  Future<void> _pickCover() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _coverImage = image;
        _coverBytes = bytes;
      });
    }
  }

  // --- 2. PICK STORY PAGES (SLIDES) ---
  Future<void> _pickPages() async {
    final List<XFile> images = await _picker.pickMultiImage(imageQuality: 50);
    if (images.isNotEmpty) {
      List<SlideItem> newSlides = [];
      for (var file in images) {
        final bytes = await file.readAsBytes();
        newSlides.add(
          SlideItem(
            file: file,
            bytes: bytes,
            controller: TextEditingController(),
          ),
        );
      }
      setState(() {
        _slides.addAll(newSlides);
      });
    }
  }

  // --- 3. REMOVE SINGLE SLIDE ---
  void _removeSlide(int index) {
    setState(() {
      _slides[index].controller.dispose();
      _slides.removeAt(index);
    });
  }

  // --- 3.5 SCAN TEXT FROM IMAGE ---
  Future<void> _scanTextFromImage(int index) async {
    final slide = _slides[index];
    try {
      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Extracting text via Cloud OCR...")),
          );
        }

        final String base64Img = base64Encode(slide.bytes);
        final response = await http.post(
          Uri.parse('https://api.ocr.space/parse/image'),
          body: {
            'apikey': 'helloworld',
            'language': 'eng',
            'base64Image': 'data:image/jpeg;base64,$base64Img',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['IsErroredOnProcessing'] == false &&
              data['ParsedResults'] != null) {
            String extracted = "";
            for (var result in data['ParsedResults']) {
              extracted += (result['ParsedText'] ?? "") + "\n";
            }
            setState(() {
              slide.controller.text = extracted.trim();
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Text extracted successfully!")),
              );
            }
          } else {
            throw Exception("Could not read text from image.");
          }
        } else {
          throw Exception("Cloud OCR failed (${response.statusCode})");
        }
        return;
      }

      final inputImage = InputImage.fromFilePath(slide.file.path);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      setState(() {
        slide.controller.text = recognizedText.text;
      });

      textRecognizer.close();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Text extracted successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to extract text: $e")));
      }
    }
  }

  // --- 4. CROSS-PLATFORM UPLOAD LOGIC ---
  Future<void> _uploadToServer() async {
    if (_titleController.text.trim().isEmpty ||
        _coverImage == null ||
        _slides.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please fill in the title, cover image, and at least 1 slide page.",
          ),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final uri = Uri.parse("$baseUrl/api/stories");
      final request = http.MultipartRequest('POST', uri);

      // Add Headers (Kasama ang ngrok bypass at iba pang headers)
      request.headers.addAll(networkHeaders);
      request.headers["ngrok-skip-browser-warning"] = "69420";

      // Story Text Fields
      request.fields['title'] = _titleController.text.trim();
      request.fields['description'] = _descController.text.trim();

      // Audio Scripts Packaging (Papadala bilang JSON array at indexed array para sa flexibility ng backend)
      List<String> scripts = _slides
          .map((s) => s.controller.text.trim())
          .toList();
      request.fields['audio_scripts'] = jsonEncode(scripts);

      for (int i = 0; i < _slides.length; i++) {
        request.fields['audio_scripts[$i]'] = _slides[i].controller.text.trim();
      }

      // Processing Cover Image (Cross-Platform)
      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'cover_image',
            _coverBytes!,
            filename: _coverImage!.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('cover_image', _coverImage!.path),
        );
      }

      // Processing Story Pages / Slides (Cross-Platform)
      for (var slide in _slides) {
        if (kIsWeb) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'pages[]',
              slide.bytes,
              filename: slide.file.name,
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath('pages[]', slide.file.path),
          );
        }
      }

      // Ipadala ang Request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = jsonDecode(response.body);
        final storyId = resData['story']['id'];

        // Upload Quiz if we have any questions
        if (_quizQuestions.isNotEmpty) {
          List<Map<String, dynamic>> questionsPayload = _quizQuestions.map((q) {
            return {
              "question_text": q.questionController.text.trim(),
              "options": q.optionControllers.map((c) => c.text.trim()).toList(),
              "correct_answer": q.optionControllers[q.correctAnswerIndex].text
                  .trim(),
            };
          }).toList();

          try {
            await http.post(
              Uri.parse('$baseUrl/api/stories/$storyId/quiz'),
              headers: {
                ...networkHeaders,
                "ngrok-skip-browser-warning": "69420",
                "Content-Type": "application/json",
              },
              body: jsonEncode({
                "title": "${_titleController.text.trim()} Quiz",
                "questions": questionsPayload,
              }),
            );
          } catch (e) {
            debugPrint("Quiz upload error: $e");
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Story, scripts & quiz uploaded successfully! 🎉"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Auto refresh dashboard
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Server Error (${response.statusCode}): ${response.body}",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connection Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    for (var slide in _slides) {
      slide.controller.dispose();
    }
    super.dispose();
  }

  InputDecoration _comicInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "Upload New Story",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(color: Colors.black, height: 4.0),
        ),
      ),
      body: GuideComicBackground(
        child: _isUploading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 15),
                    Text(
                      "Uploading story & scripts, please wait...",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // STORY TITLE
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: _comicInputDecoration("Story Title *"),
                    ),
                    const SizedBox(height: 15),

                    // STORY DESCRIPTION
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: _comicInputDecoration(
                        "Description (Optional)",
                      ),
                    ),
                    const SizedBox(height: 25),

                    // COVER IMAGE SECTION
                    const Text(
                      "Cover Image *",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Colors.black,
                              width: 3,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _pickCover,
                        icon: const Icon(Icons.image),
                        label: Text(
                          _coverImage == null
                              ? "Select Cover Image"
                              : "Change Cover Image",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (_coverBytes != null) ...[
                      const SizedBox(height: 15),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.memory(
                            _coverBytes!,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 25),

                    // STORY PAGES SECTION
                    const Text(
                      "Story Pages (Slides) & Narrator Scripts *",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Colors.black,
                              width: 3,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _pickPages,
                        icon: const Icon(Icons.photo_library),
                        label: const Text(
                          "Select Pages from Gallery",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // DYNAMIC SLIDE LIST WITH SCRIPT TEXTFIELDS
                    if (_slides.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(3, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          "0 pages selected",
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _slides.length,
                        itemBuilder: (context, index) {
                          final slide = _slides[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.black, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(4, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.black,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.memory(
                                          slide.bytes,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Slide ${index + 1}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: "Extract Text from Image",
                                      icon: const Icon(
                                        Icons.document_scanner,
                                        color: Colors.blueAccent,
                                      ),
                                      onPressed: () =>
                                          _scanTextFromImage(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => _removeSlide(index),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: slide.controller,
                                  maxLines: 2,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration:
                                      _comicInputDecoration(
                                        "Narrator Script / Text for Slide ${index + 1}",
                                      ).copyWith(
                                        hintText:
                                            "Type story line for this slide...",
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 40),

                    // QUIZ SECTION
                    const Text(
                      "Story Quiz (Optional)",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_quizQuestions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(3, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          "No quiz questions added. Students won't take a quiz.",
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _quizQuestions.length,
                        itemBuilder: (context, index) {
                          final quiz = _quizQuestions[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE047), // comic yellow
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.black, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(4, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Question ${index + 1}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: Colors.black,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () =>
                                          _removeQuizQuestion(index),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: quiz.questionController,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: _comicInputDecoration(
                                    "Type question here...",
                                  ),
                                ),
                                const SizedBox(height: 15),
                                const Text(
                                  "Options & Correct Answer:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...List.generate(4, (optIndex) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        Radio<int>(
                                          value: optIndex,
                                          groupValue: quiz.correctAnswerIndex,
                                          activeColor: Colors.redAccent,
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() {
                                                quiz.correctAnswerIndex = val;
                                              });
                                            }
                                          },
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: quiz
                                                .optionControllers[optIndex],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            decoration:
                                                _comicInputDecoration(
                                                  "Option ${String.fromCharCode(65 + optIndex)}",
                                                ).copyWith(
                                                  fillColor:
                                                      quiz.correctAnswerIndex ==
                                                          optIndex
                                                      ? Colors.green[100]
                                                      : Colors.white,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Colors.black,
                              width: 3,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _addQuizQuestion,
                        icon: const Icon(Icons.add_task),
                        label: const Text(
                          "Add Quiz Question",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // SUBMIT BUTTON
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(5, 5)),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: const Color(0xFF9B0505),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: const BorderSide(
                              color: Colors.black,
                              width: 3,
                            ),
                          ),
                        ),
                        onPressed: _uploadToServer,
                        child: const Text(
                          "UPLOAD AND SAVE",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
