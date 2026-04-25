import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart' show baseUrl;

// ─────────────────────────────────────────────────────────────────────────────
//  ShareScreen — "Show to Teacher" QR dashboard
// ─────────────────────────────────────────────────────────────────────────────
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  bool _copied = false;
  bool _reportLoading = false;
  String? _reportText;

  String get _childId => context.read<LanguageProvider>().childId;
  String get _childName => context.read<LanguageProvider>().childName;

  String get _dashboardUrl => '${baseUrl}/dashboard/$_childId/html';
  String get _jsonUrl => '${baseUrl}/dashboard/$_childId';

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _dashboardUrl));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _shareWhatsApp() async {
    final msg = Uri.encodeComponent(
      '👋 Hi! Here is ${_childName}\'s VoiceGuru learning dashboard:\n$_dashboardUrl\n\n'
      'You can see their streak, subjects, quiz scores and AI recommendations there. 🦉',
    );
    final uri = Uri.parse('https://wa.me/?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _shareNative();
    }
  }

  Future<void> _shareNative() async {
    await Share.share(
      '📚 Check out ${_childName}\'s learning progress on VoiceGuru!\n$_dashboardUrl',
      subject: '${_childName}\'s Learning Dashboard',
    );
  }

  Future<void> _openDashboard() async {
    final uri = Uri.parse(_dashboardUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _fetchReport() async {
    setState(() => _reportLoading = true);
    try {
      final uri = Uri.parse('${baseUrl}/dashboard/$_childId/report');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() => _reportText = data['report']?.toString() ?? 'No report available.');
      } else {
        setState(() => _reportText = 'Could not load report (${response.statusCode}).');
      }
    } catch (_) {
      setState(() => _reportText = 'Could not load report. Make sure backend is running.');
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _childName;
    final grade = context.watch<LanguageProvider>().grade;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        title: const Text(
          'Share with Teacher',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Header card ──
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFF3367D6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4285F4).withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('🦉', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 10),
                  Text(
                    '$name\'s Dashboard',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Class $grade · VoiceGuru Progress Report',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  // Open in browser button
                  ElevatedButton.icon(
                    onPressed: _openDashboard,
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                    label: const Text('Open Dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF3367D6),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15),

            const SizedBox(height: 24),

            // ── QR Code ──
            Container(
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Scan to view dashboard',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Teacher scans this QR code on any phone',
                    style: TextStyle(fontSize: 12, color: kTextSecondary),
                  ),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: _dashboardUrl,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF4285F4),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // URL chip
                  GestureDetector(
                    onTap: _copyLink,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _copied
                            ? kGoogleGreen.withOpacity(0.1)
                            : kBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _copied ? kGoogleGreen : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _copied ? Icons.check_circle : Icons.link_rounded,
                            size: 16,
                            color: _copied ? kGoogleGreen : kTextSecondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _copied ? 'Link copied!' : _dashboardUrl,
                              style: TextStyle(
                                fontSize: 11,
                                color: _copied ? kGoogleGreen : kTextSecondary,
                                fontWeight: _copied
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.1),

            const SizedBox(height: 20),

            // ── Share buttons ──
            Row(
              children: [
                Expanded(
                  child: _ShareButton(
                    icon: '💬',
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: _shareWhatsApp,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ShareButton(
                    icon: '📤',
                    label: 'Share Link',
                    color: kGoogleBlue,
                    onTap: _shareNative,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 250.ms, duration: 400.ms),

            const SizedBox(height: 20),

            // ── AI Report section ──
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🤖', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'AI Weekly Report',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: kTextPrimary,
                          ),
                        ),
                      ),
                      if (_reportText == null)
                        ElevatedButton(
                          onPressed: _reportLoading ? null : _fetchReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGoogleBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          child: _reportLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Generate'),
                        ),
                    ],
                  ),
                  if (_reportText != null) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(
                        _reportText!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: kTextPrimary,
                          height: 1.6,
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _reportText!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Report copied to clipboard'),
                              backgroundColor: kGoogleGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy Report'),
                        style: TextButton.styleFrom(
                          foregroundColor: kGoogleBlue,
                        ),
                      ),
                    ),
                  ] else if (!_reportLoading) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Generate a Gemini-powered narrative report '
                      'you can share with your teacher or parent.',
                      style: TextStyle(fontSize: 13, color: kTextSecondary),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable share button ───
class _ShareButton extends StatefulWidget {
  const _ShareButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

