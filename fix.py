import re

with open('lib/screens/student_dashboard.dart', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = """
  @override
  Widget build(BuildContext context) {
    Widget mobileLayout = Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            color: maroonTheme,
            border: Border(bottom: BorderSide(color: Colors.black, width: 3.5)),
            boxShadow: [BoxShadow(color: Colors.black26, offset: Offset(0, 4))],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentTheme,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: const Icon(
                          Icons.menu_book,
                          color: Colors.black,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "READSMART HUB",
                            style: TextStyle(
                              fontSize: 10,
                              color: accentTheme,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            widget.userName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: accentTheme,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                      onPressed: _logout,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(4, 4)),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showJoinClassDialog,
          backgroundColor: accentTheme,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: const BorderSide(color: Colors.black, width: 3),
          ),
          elevation: 0,
          icon: const Icon(Icons.add_circle, color: Colors.black, size: 24),
          label: const Text(
            "JOIN CLASS",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
      body: ComicBackground(
        child: RefreshIndicator(
          onRefresh: _fetchMyClasses,
          color: maroonTheme,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(),
                const SizedBox(height: 25),
                _buildSectionTitle("YOUR CLASSES"),
                const SizedBox(height: 15),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(color: maroonTheme),
                    ),
                  )
                else if (_myClasses.isEmpty)
                  _buildEmptyState()
                else
                  _buildClassesGrid(),
              ],
            ),
          ),
        ),
      ),
    );

    Widget desktopLayout = Scaffold(
      backgroundColor: maroonTheme,
      body: Row(
        children: [
          // 1. Sidebar
          Container(
            width: 260,
            decoration: const BoxDecoration(
              color: maroonTheme,
              border: Border(right: BorderSide(color: Colors.black, width: 3.5)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentTheme,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 3),
                  ),
                  child: const Icon(Icons.menu_book, color: Colors.black, size: 48),
                ),
                const SizedBox(height: 16),
                const Text(
                  "READSMART HUB",
                  style: TextStyle(
                    fontSize: 14,
                    color: accentTheme,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  widget.userName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ListTile(
                  leading: const Icon(Icons.dashboard, color: Colors.white),
                  title: const Text("Dashboard", style: TextStyle(color: Colors.white)),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.add_circle, color: Colors.white70),
                  title: const Text("Join Class", style: TextStyle(color: Colors.white70)),
                  onTap: _showJoinClassDialog,
                ),
                const Spacer(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white70),
                  title: const Text("Logout", style: TextStyle(color: Colors.white70)),
                  onTap: _logout,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          // 2. Main Content
          Expanded(
            child: Container(
              color: const Color(0xFFC7EEFF), // ComicBackground color logic
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: mobileLayout,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return ResponsiveLayout(
      mobileLayout: mobileLayout,
      desktopLayout: desktopLayout,
    );
  }
"""

pattern = r"  @override\s+Widget build\(BuildContext context\) \{\s+// Current Mobile Layout \(With App Bar\)\s+Widget mobileLayout = Scaffold\(.*?    \n  \}\n\n  Widget _buildHeaderBanner\(\) \{"

new_content = re.sub(pattern, replacement + '\n\n  Widget _buildHeaderBanner() {', content, flags=re.DOTALL)

with open('lib/screens/student_dashboard.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)
print("Updated student_dashboard.dart")
