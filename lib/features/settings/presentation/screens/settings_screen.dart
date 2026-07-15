import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/local_signal.dart';
import '../../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _SectionHeader('Model'),
          const ListTile(
            title: Text('Active model', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text('llama3.1:8b · via Ollama, Docker Compose', style: TextStyle(color: AppColors.textTertiary)),
            trailing: LocalSignalBadge(label: 'on-device'),
          ),
          const _SliderTile(label: 'Temperature', value: 0.7),
          const _SliderTile(label: 'Top P', value: 0.9),
          const _SliderTile(label: 'Top K', value: 40, max: 100),
          const _SliderTile(label: 'Max tokens', value: 2048, max: 8192),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Streaming responses', style: TextStyle(color: AppColors.textPrimary)),
            activeThumbColor: AppColors.signal,
          ),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Markdown rendering', style: TextStyle(color: AppColors.textPrimary)),
            activeThumbColor: AppColors.signal,
          ),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Animations', style: TextStyle(color: AppColors.textPrimary)),
            activeThumbColor: AppColors.signal,
          ),
          _SectionHeader('Appearance'),
          const ListTile(
            title: Text('Theme', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text('System', style: TextStyle(color: AppColors.textTertiary)),
            trailing: Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ),
          _SectionHeader('Storage'),
          const ListTile(
            title: Text('Storage usage', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text('Cached locally via Hive — see breakdown', style: TextStyle(color: AppColors.textTertiary)),
            trailing: Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ),
          const ListTile(
            title: Text('Export data', style: TextStyle(color: AppColors.textPrimary)),
            trailing: Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ),
          _SectionHeader('Account'),
          ListTile(
            title: const Text('Log out', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
          const ListTile(
            title: Text('Delete account', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  const _SliderTile({required this.label, required this.value, this.max = 1});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          ),
          Expanded(
            child: Slider(
              value: value,
              max: max,
              activeColor: AppColors.signal,
              inactiveColor: AppColors.surfaceElevated,
              onChanged: (_) {},
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
