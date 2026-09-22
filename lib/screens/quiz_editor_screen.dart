import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class QuizEditorScreen extends StatefulWidget {
  final dynamic story;
  final String baseUrl;

  const QuizEditorScreen({
    super.key,
    required this.story,
    required this.baseUrl,
  });

  @override
  State<QuizEditorScreen> createState() => _QuizEditorScreenState();
}

class QuestionControllerGroup {
  TextEditingController questionText;
  List<TextEditingController> options;
  String correctAnswer;

  QuestionControllerGroup({
    required this.questionText,
    required this.options,
    required this.correctAnswer,
  });

  void dispose() {
    questionText.dispose();
    for (var opt in options) {
      opt.dispose();
    }
  }
}

class _QuizEditorScreenState extends State<QuizEditorScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  final List<QuestionControllerGroup> _questionGroups = [];

  @override
  void initState() {
    super.initState();
    _fetchQuiz();
  }

  @override
  void dispose() {
    for (var group in _questionGroups) {
      group.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchQuiz() async {
    try {
      final response = await http.get(
        Uri.parse("${widget.baseUrl}/api/stories/${widget.story['id']}/quiz"),
        headers: const {"ngrok-skip-browser-warning": "69420"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> questions = data['quiz']?['questions'] ?? [];

        setState(() {
          for (var q in questions) {
            List<dynamic> rawOptions = q['options'] ?? [];
            List<TextEditingController> optControllers = rawOptions
                .map((opt) => TextEditingController(text: opt.toString()))
                .toList();

            // Siguraduhing may at least 2 options palagi
            while (optControllers.length < 2) {
              optControllers.add(TextEditingController());
            }

            _questionGroups.add(
              QuestionControllerGroup(
                questionText: TextEditingController(
                  text: q['question_text'] ?? '',
                ),
                options: optControllers,
                correctAnswer: q['correct_answer'] ?? '',
              ),
            );
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching quiz: $e");
      setState(() => _isLoading = false);
    }
  }

  void _addEmptyQuestion() {
    setState(() {
      _questionGroups.add(
        QuestionControllerGroup(
          questionText: TextEditingController(),
          options: [
            TextEditingController(),
            TextEditingController(),
            TextEditingController(),
            TextEditingController(),
          ],
          correctAnswer: '',
        ),
      );
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questionGroups[index].dispose();
      _questionGroups.removeAt(index);
    });
  }

  Future<void> _saveQuiz() async {
    setState(() => _isSaving = true);

    List<Map<String, dynamic>> questionsPayload = [];

    for (var group in _questionGroups) {
      final qText = group.questionText.text.trim();
      final opts = group.options
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      if (qText.isEmpty || opts.isEmpty) continue;

      // Kung ang correct answer ay wala sa options, i-default sa unang option
      String correctAns = group.correctAnswer;
      if (!opts.contains(correctAns) && opts.isNotEmpty) {
        correctAns = opts.first;
      }

      questionsPayload.add({
        "question_text": qText,
        "options": opts,
        "correct_answer": correctAns,
      });
    }

    try {
      final response = await http.post(
        Uri.parse("${widget.baseUrl}/api/stories/${widget.story['id']}/quiz"),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420",
        },
        body: jsonEncode({"questions": questionsPayload}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Quiz saved successfully! ✅"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception("Status code: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save quiz: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          "Edit Quiz: ${widget.story['title'] ?? 'Story'}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 12.0,
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent[700],
                foregroundColor: Colors.black,
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? "Saving..." : "Save Quiz"),
              onPressed: _isSaving ? null : _saveQuiz,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.amberAccent),
            )
          : _questionGroups.isEmpty
          ? _buildEmptyState()
          : _buildQuestionsList(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.amberAccent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text(
          "Add Question",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: _addEmptyQuestion,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.quiz_outlined, size: 64, color: Colors.white38),
          const SizedBox(height: 16),
          const Text(
            "No quiz available for this story yet.",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.add),
            label: const Text("Create First Question"),
            onPressed: _addEmptyQuestion,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100, top: 16, left: 16, right: 16),
      itemCount: _questionGroups.length,
      itemBuilder: (context, index) {
        final group = _questionGroups[index];

        // Populate dropdown options based on what's typed
        final currentOptions = group.options
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();

        return Card(
          color: const Color(0xFF1E1E1E),
          margin: const EdgeInsets.only(bottom: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Question ${index + 1}",
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _removeQuestion(index),
                      tooltip: "Delete Question",
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: group.questionText,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Question Text",
                    labelStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Color(0xFF2C2C2C),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Options:",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(group.options.length, (optIdx) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            String.fromCharCode(65 + optIdx), // A, B, C, D...
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: group.options[optIdx],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: "Option ${optIdx + 1}",
                              hintStyle: const TextStyle(color: Colors.white30),
                              filled: true,
                              fillColor: const Color(0xFF2C2C2C),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(
                              () {},
                            ), // Trigger rebuild para ma-update ang dropdown list
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                const Text(
                  "Correct Answer:",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: currentOptions.contains(group.correctAnswer)
                      ? group.correctAnswer
                      : null,
                  dropdownColor: const Color(0xFF2C2C2C),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Color(0xFF2C2C2C),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                  hint: const Text(
                    "Select the correct answer",
                    style: TextStyle(color: Colors.white54),
                  ),
                  items: currentOptions.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt,
                      child: Text(opt),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        group.correctAnswer = val;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
