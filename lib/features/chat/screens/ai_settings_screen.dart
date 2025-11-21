import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/ai_settings_provider.dart';

class AiSettingsScreen extends StatelessWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AiSettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Settings'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.memory,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'AI Settings',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Response Mode',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      !provider.useDeepMode ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: !provider.useDeepMode ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    title: const Text('Quick Mode'),
                    subtitle: const Text('Fast responses, good for casual conversation'),
                    onTap: () {
                      if (!provider.useDeepMode) return;
                      provider.toggleAiMode();
                    },
                  ),
                  Divider(height: 1, color: theme.dividerColor),
                  ListTile(
                    leading: Icon(
                      provider.useDeepMode ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: provider.useDeepMode ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    title: const Text('Deep Mode'),
                    subtitle: const Text('Thorough analysis, better for complex questions'),
                    onTap: () {
                      if (provider.useDeepMode) return;
                      provider.toggleAiMode();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Memory',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Previous Messages: ${provider.memoryMessageCount}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Include previous messages in AI context for better responses',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: provider.memoryMessageCount.toDouble(),
                    min: 0,
                    max: 50,
                    divisions: 50,
                    label: provider.memoryMessageCount.toString(),
                    onChanged: (value) {
                      provider.setMemoryMessageCount(value.toInt());
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '0',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      Text(
                        '50',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Current: ${provider.useDeepMode ? "Deep Mode" : "Quick Mode"} • Memory: ${provider.memoryMessageCount} messages',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}