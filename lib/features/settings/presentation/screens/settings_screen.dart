import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/local_signal.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Kick a refresh from the backend each time the screen is opened, in
    // case settings were changed on another device.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _SectionHeader('Model'),
          ListTile(
            title: const Text('Active model', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text('${settings.defaultModel} · via Ollama, Docker Compose', style: const TextStyle(color: AppColors.textTertiary)),
            trailing: const LocalSignalBadge(label: 'on-device'),
          ),
          _SliderTile(
            label: 'Temperature',
            value: settings.temperature,
            onChanged: (v) => notifier.setTemperature(v),
          ),
          _SliderTile(
            label: 'Top P',
            value: settings.topP,
            onChanged: (v) => notifier.setTopP(v),
          ),
          _SliderTile(
            label: 'Top K',
            value: settings.topK.toDouble(),
            max: 100,
            onChanged: (v) => notifier.setTopK(v.round()),
          ),
          _SliderTile(
            label: 'Max tokens',
            value: settings.maxTokens.toDouble(),
            max: 8192,
            onChanged: (v) => notifier.setMaxTokens(v.round()),
          ),
          SwitchListTile(
            value: settings.streamingEnabled,
            onChanged: (v) => notifier.setStreamingEnabled(v),
            title: const Text('Streaming responses', style: TextStyle(color: AppColors.textPrimary)),
            activeThumbColor: AppColors.signal,
          ),
          SwitchListTile(
            value: settings.markdownEnabled,
            onChanged: (v) => notifier.setMarkdownEnabled(v),
            title: const Text('Markdown rendering', style: TextStyle(color: AppColors.textPrimary)),
            activeThumbColor: AppColors.signal,
          ),
          SwitchListTile(
            value: settings.animationsEnabled,
            onChanged: (v) => notifier.setAnimationsEnabled(v),
            title: const Text('Animations', style: TextStyle(color: AppColors.textPrimary)),
            activeThumbColor: AppColors.signal,
          ),
          _SectionHeader('Appearance'),
          ListTile(
            title: const Text('Theme', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(
              '${settings.theme[0].toUpperCase()}${settings.theme.substring(1)}',
              style: const TextStyle(color: AppColors.textTertiary),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            onTap: () => _showThemePicker(context, settings.theme, notifier),
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

  void _showThemePicker(BuildContext context, String current, SettingsNotifier notifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            for (final option in const ['system', 'light', 'dark'])
              ListTile(
                title: Text(
                  '${option[0].toUpperCase()}${option.substring(1)}',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                trailing: option == current ? const Icon(Icons.check, color: AppColors.signal) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  notifier.setTheme(option);
                },
              ),
          ],
        ),
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

class _SliderTile extends StatefulWidget {
  final String label;
  final double value;
  final double max;
  final ValueChanged<double>? onChanged;
  const _SliderTile({required this.label, required this.value, this.max = 1, this.onChanged});

  @override
  State<_SliderTile> createState() => _SliderTileState();
}

class _SliderTileState extends State<_SliderTile> {
  late double _dragValue = widget.value;

  @override
  void didUpdateWidget(covariant _SliderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _dragValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(widget.label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          ),
          Expanded(
            child: Slider(
              value: _dragValue,
              max: widget.max,
              activeColor: AppColors.signal,
              inactiveColor: AppColors.surfaceElevated,
              // Update the visible value on every frame of the drag, but
              // only push to the provider (and thus the backend) once the
              // person releases the slider, so we don't fire an API call
              // per pixel dragged.
              onChanged: (v) => setState(() => _dragValue = v),
              onChangeEnd: widget.onChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              _dragValue % 1 == 0 ? _dragValue.toInt().toString() : _dragValue.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
