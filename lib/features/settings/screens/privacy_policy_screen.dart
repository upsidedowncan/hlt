import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/constants/app_ui_constants.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Privacy Policy',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSizes.paddingMedium),
            Text(
              'Last updated: ${DateTime.now().toString().split(' ')[0]}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: AppSizes.paddingLarge),

            // Introduction
            _buildSection(
              theme,
              'Introduction',
              'Welcome to HLT ("Hey, Let\'s Talk!") - an AI-powered chat assistant app ("we," "our," or "us"). HLT combines human-to-human messaging with advanced AI conversations powered by our AI assistant "Mite". We are committed to protecting your privacy and ensuring the security of your personal information. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.',
            ),
            SizedBox(height: AppSizes.paddingMedium),
            Text(
              'Last updated: ${DateTime.now().toString().split(' ')[0]}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            SizedBox(height: AppSizes.paddingLarge),

            // Introduction
            _buildSection(
              theme,
              'Introduction',
              'Welcome to our AI Chat Assistant app ("we," "our," or "us"). We are committed to protecting your privacy and ensuring the security of your personal information. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.',
            ),

            // Information We Collect
            _buildSection(
              theme,
              'Information We Collect',
              '**All data is stored locally on your device. We do not collect, store, or transmit any location data, IP addresses, or usage analytics.**\n\n'
              'We only collect information you provide directly to us, such as when you create an account or participate in conversations. This includes:\n\n'
              '• Account information (email address, username, display name)\n'
              '• Profile information (avatar images stored locally)\n'
              '• Chat messages and conversation history (stored locally on your device)\n'
              '• Voice recordings and audio messages (processed locally for speech-to-text)\n'
              '• Files and media you upload or share (stored locally)\n'
              '• AI interaction preferences (quick vs deep mode, memory settings)\n'
              '• App customization settings (themes, colors, fonts - stored locally)\n\n'
              '**What we send to Mite (our AI assistant):**\n'
              'Only your display name, username, email, and platform information is sent to enable personalized AI responses. This data is transmitted securely and is not stored externally.',
            ),

            // How We Use Your Information
            _buildSection(
              theme,
              'How We Use Your Information',
              '**All your data remains on your device. We do not analyze, share, or sell any of your information.**\n\n'
              'We use the information stored locally on your device to:\n\n'
              '• Provide and maintain HLT\'s chat and AI assistant services\n'
              '• Process and deliver your messages and conversations locally\n'
              '• Power our AI assistant "Mite" with contextual responses\n'
              '• Store your conversations securely on your device\n'
              '• Process voice recordings locally for speech-to-text conversion\n'
              '• Handle file uploads and media sharing within the app\n'
              '• Generate AI-powered visualizations and HTML content\n'
              '• Personalize your experience based on your local preferences\n'
              '• Maintain app functionality and performance\n\n'
              '**Data sent to AI providers:**\n'
              'Only your display name, username, email, and platform are sent to enable personalized AI responses. This minimal data is transmitted securely and is not stored or used for any other purposes.',
            ),

            // Third-Party Services
            _buildSection(
              theme,
              'Third-Party Services',
              'HLT uses minimal third-party services, and **your personal data never leaves your device**:\n\n'
              '• **AI Processing**: Minimal profile information is sent to enable personalized AI responses\n'
              '• **No cloud storage**: All conversations, files, and data are stored locally on your device\n'
              '• **No analytics**: We do not collect or share any usage analytics\n'
              '• **No tracking**: No location, IP addresses, or device identifiers are collected\n\n'
              'AI processing uses your minimal profile information securely and does not store or reuse it for any other purposes.',
            ),

            // Information Sharing
            _buildSection(
              theme,
              'Information Sharing and Disclosure',
              '**We do not share, sell, or transfer any of your personal information.**\n\n'
              'Your data remains entirely on your device. The only information that leaves your device is:\n\n'
              '• Your display name, username, email, and platform (sent to AI providers for personalization)\n'
              '• This minimal data is transmitted securely and is not stored by the AI providers\n\n'
              '**We do not:**\n'
              '• Share conversations or messages with anyone\n'
              '• Sell data to third parties\n'
              '• Use data for advertising\n'
              '• Collect analytics or usage data\n'
              '• Track location or IP addresses\n'
              '• Store data on external servers',
            ),

            // Data Security
            _buildSection(
              theme,
              'Data Security',
              'We implement appropriate technical and organizational security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. These measures include:\n\n'
              '• Encryption of data in transit and at rest\n'
              '• Secure server infrastructure\n'
              '• Regular security audits and updates\n'
              '• Access controls and authentication\n\n'
              'However, no method of transmission over the internet is 100% secure, and we cannot guarantee absolute security.',
            ),

            // AI Assistant - Mite
            _buildSection(
              theme,
              'AI Assistant - Mite',
              'HLT features our AI assistant "Mite" with advanced AI capabilities. **All AI processing happens locally on your device, except for minimal profile data sent for personalization.**\n\n'
              '**What happens locally:**\n'
              '• Conversation processing and response generation\n'
              '• Voice recordings converted to text locally\n'
              '• HTML visualizations generated on-device\n'
              '• All conversation history stored locally\n'
              '• Quick vs Deep mode switching handled locally\n\n'
              '**What is sent externally:**\n'
              'Only your display name, username, email, and platform are sent to enable personalized responses. This minimal data:\n'
              '• Is transmitted securely\n'
              '• Is not stored externally\n'
              '• Is not used for training or other purposes\n'
              '• Is only used to provide better personalized responses\n\n'
              'Mite is designed to be helpful and engaging while strictly adhering to content guidelines. Your conversations and personal data remain entirely private and local to your device.',
            ),

            // Data Retention and Deletion
            _buildSection(
              theme,
              'Data Retention and Control',
              '**All your data is stored locally on your device. You have complete control over your data.**\n\n'
              '• **Conversations**: Stored locally until you delete them manually\n'
              '• **Files and media**: Stored locally until you delete them\n'
              '• **Settings and preferences**: Stored locally, controlled by you\n'
              '• **No external retention**: We do not retain any of your data on external servers\n'
              '• **Immediate deletion**: Data is deleted instantly when you remove it\n\n'
              'You can delete individual conversations, clear chat history, or remove any data at any time through the app interface. Since all data is local, deletion is immediate and permanent.',
            ),

            // Your Rights
            _buildSection(
              theme,
              'Your Rights and Choices',
              'Depending on your location, you may have certain rights regarding your personal information:\n\n'
              '• **Access**: Request access to your personal data and conversation history\n'
              '• **Rectification**: Correct inaccurate profile information or preferences\n'
              '• **Deletion**: Request deletion of conversations, account, or all personal data\n'
              '• **Portability**: Export your conversation data in readable format\n'
              '• **Objection**: Opt out of analytics or personalized AI features\n'
              '• **Restriction**: Limit data processing for specific purposes\n\n'
              'To exercise these rights, use the in-app settings or contact us using the information provided below.',
            ),

            // Children's Privacy
            _buildSection(
              theme,
              'Children\'s Privacy',
              'Our app is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If we become aware that we have collected personal information from a child under 13, we will take steps to delete such information promptly.',
            ),

            // Changes to Privacy Policy
            _buildSection(
              theme,
              'Changes to This Privacy Policy',
              'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date. You are advised to review this Privacy Policy periodically for any changes.',
            ),

            // Contact Us
            _buildSection(
              theme,
              'Contact Us',
              'If you have any questions about this Privacy Policy or our privacy practices, please contact us:\n\n'
              '• Email: privacy@hltapp.com\n'
              '• In-App Support: Through the app\'s settings or help section\n'
              '• App Name: HLT ("Hey, Let\'s Talk!")\n\n'
              '**Privacy Commitment:** HLT is designed with privacy as a core principle. All your conversations, files, and personal data remain on your device. We do not collect, store, or share any usage data, analytics, or personal information beyond the minimal profile data sent to AI providers for personalization.',
            ),

            // Footer
            const SizedBox(height: AppSizes.paddingLarge),
            Container(
              padding: EdgeInsets.all(AppSizes.paddingMedium),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
              child: Markdown(
                data: '*By using our app, you agree to the collection and use of information in accordance with this policy. If you do not agree with our policies and practices, please do not use our app.*',
                styleSheet: MarkdownStyleSheet(
                  p: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                    fontStyle: FontStyle.italic,
                  ),
                  em: const TextStyle(fontStyle: FontStyle.italic),
                ),
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
              ),
            ),
            SizedBox(height: AppSizes.paddingLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSizes.paddingSmall),
        Markdown(
          data: content,
          styleSheet: MarkdownStyleSheet(
            p: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurface,
            ),
            strong: const TextStyle(fontWeight: FontWeight.bold),
            listBullet: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
        ),
        const SizedBox(height: AppSizes.paddingLarge),
      ],
    );
  }
}