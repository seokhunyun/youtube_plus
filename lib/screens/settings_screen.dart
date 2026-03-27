import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _serverUrl = 'http://localhost:8765';
  bool _autoPlay = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text('설정', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Server settings ────────────────────────
          _sectionTitle('서버 설정'),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('API 서버 주소', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: _serverUrl,
                  onChanged: (v) => setState(() => _serverUrl = v),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          // ── Playback settings ──────────────────────
          _sectionTitle('재생 설정'),
          _card(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('연속 재생', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('목록의 다음 영상 자동 재생',
                        style: TextStyle(
                            color: AppTheme.textTertiary, fontSize: 12)),
                  ],
                ),
                Switch(
                  value: _autoPlay,
                  activeColor: AppTheme.accent,
                  onChanged: (v) => setState(() => _autoPlay = v),
                ),
              ],
            ),
          ),

          // ── App info ───────────────────────────────
          _sectionTitle('앱 정보'),
          _card(
            child: Column(
              children: [
                _infoRow('버전', '1.0.0 (Prototype)'),
                const Divider(height: 20),
                _infoRow('DB', 'b-611.iptime.org:33069'),
                const Divider(height: 20),
                _infoRow('채널 수', '9,425'),
                const Divider(height: 20),
                _infoRow('영상 수', '2,147,718'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}
