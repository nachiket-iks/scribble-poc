// ── Chart Note Screen ────────────────────────────────────────
class ChartNoteScreen extends StatefulWidget {
  const ChartNoteScreen({super.key});

  @override
  State<ChartNoteScreen> createState() => _ChartNoteScreenState();
}

class _ChartNoteScreenState extends State<ChartNoteScreen> {
  // ── JSONBin endpoint ─────────────────────────────────────────
  // JSONBin wraps your response under a "record" key:
  // { "record": { "payload": { "encoding": "base64", "html": "..." } } }
  static const String _jsonBinUrl = 'https://api.jsonbin.io/v3/b/6a05ae68adc21f119a9bbde5';

  // Add your JSONBin Master Key here if the bin is private:
  // static const String _apiKey = '$2a$10$YOUR_KEY_HERE';
  // ────────────────────────────────────────────────────────────

  String? _htmlContent;
  String? _noteVersion; // e.g. "v1" or "v2"
  String? _encounterId; // e.g. "ENC-20260514-0042"
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _fetchedAt;

  @override
  void initState() {
    super.initState();
    _fetchNote();
  }

  Future<void> _fetchNote() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _htmlContent = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse(_jsonBinUrl),
            headers: {
              // Uncomment and fill in if your bin is private:
              // 'X-Master-Key': _apiKey,
              'X-Bin-Meta': 'false', // returns only the record, no metadata wrapper
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        // ── Step 1: decode the JSON envelope ──────────────────
        final Map<String, dynamic> json = jsonDecode(response.body);

        // JSONBin with X-Bin-Meta: false returns the record directly.
        // If you remove that header, unwrap via: json['record']
        final payload = json['payload'] as Map<String, dynamic>;
        final encoding = payload['encoding'] as String? ?? 'base64';
        final rawHtml = payload['html'] as String;

        // ── Step 2: decode Base64 → UTF-8 HTML string ─────────
        final String html;
        if (encoding == 'base64') {
          html = utf8.decode(base64Decode(rawHtml));
        } else {
          // Plain string fallback (no base64)
          html = rawHtml;
        }

        setState(() {
          _htmlContent = html;
          _noteVersion = json['version'] as String?;
          _encounterId = json['encounter_id'] as String?;
          _fetchedAt = DateTime.now();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Server returned ${response.statusCode}';
          _isLoading = false;
        });
      }
    } on TimeoutException {
      setState(() {
        _errorMessage = 'Request timed out. Check your network.';
        _isLoading = false;
      });
    } on FormatException catch (e) {
      setState(() {
        _errorMessage = 'Failed to parse JSON or decode Base64:\n$e';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error:\n$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Chart Note Viewer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                if (_noteVersion != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFC0392B), borderRadius: BorderRadius.circular(3)),
                    child: Text(
                      _noteVersion!.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
            if (_fetchedAt != null)
              Text(
                '${_encounterId ?? ''} · Fetched ${_timeAgo(_fetchedAt!)}',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
          ],
        ),
        actions: [IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded), onPressed: _fetchNote)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFC0392B)),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildShimmer();
    if (_errorMessage != null) return _buildError();
    return _buildHtmlView();
  }

  // ── HTML Viewer ──────────────────────────────────────────────
  Widget _buildHtmlView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFC0392B), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Html(
            data: _htmlContent!,
            style: {'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero, backgroundColor: Colors.white)},
          ),
        ),
      ),
    );
  }

  // ── Shimmer Loading ──────────────────────────────────────────
  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          6,
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: i == 0 ? 60 : (i == 1 ? 40 : 20),
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
    );
  }

  // ── Error State ──────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: Color(0xFFC0392B)),
            const SizedBox(height: 16),
            const Text('Could not load chart note', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _fetchNote,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC0392B)),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ============================================================
// pubspec.yaml additions:
// ============================================================
//
// dependencies:
//   flutter:
//     sdk: flutter
//   flutter_html: ^3.0.0
//   http: ^1.2.1
//
// dart:convert is part of the Dart SDK — no extra package needed.
//
// JSONBin expected record shape:
// {
//   "status": "success",
//   "version": "v1",
//   "encounter_id": "ENC-20260514-0042",
//   "payload": {
//     "encoding": "base64",
//     "html": "<base64 string>"
//   }
// }
// ============================================================
