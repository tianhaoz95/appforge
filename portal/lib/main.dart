import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.linux) {
      debugPrint("Firebase initialization failed on Linux: $e");
    } else {
      rethrow;
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MicroForge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      themeMode: ThemeMode.system,
      home: const LandingPage(),
    );
  }
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _featuresKey = GlobalKey();
  final _pricingKey = GlobalKey();

  Future<void> _scrollTo(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            LandingHeader(
              onFeaturesTap: () => _scrollTo(_featuresKey),
              onPricingTap: () => _scrollTo(_pricingKey),
            ),
            const HeroSection(),
            FeaturesSection(key: _featuresKey),
            PricingSection(key: _pricingKey),
            const HowItWorksSection(),
            const Footer(),
          ],
        ),
      ),
    );
  }
}

class LandingHeader extends StatelessWidget {
  final VoidCallback onFeaturesTap;
  final VoidCallback onPricingTap;

  const LandingHeader({
    super.key,
    required this.onFeaturesTap,
    required this.onPricingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: [
          Image.asset('assets/brand/logo.png', height: 40),
          const SizedBox(width: 12),
          Text(
            'MicroForge',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          if (!kIsWeb || MediaQuery.of(context).size.width > 700)
            Row(
              children: [
                _HeaderLink(label: 'Features', onTap: onFeaturesTap),
                _HeaderLink(label: 'Pricing', onTap: onPricingTap),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Get Started'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HeaderLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _HeaderLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: isMobile ? 48 : 96,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: Flex(
        direction: isMobile ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: isMobile ? 0 : 5,
            child: Column(
              crossAxisAlignment: isMobile
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Vibe Coding is Here',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Forge Your Ideas into Reality',
                  textAlign: isMobile ? TextAlign.center : TextAlign.left,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Build functional micro-apps instantly using natural language. No complex setup, no build times, just pure creativity powered by flexible AI.',
                  textAlign: isMobile ? TextAlign.center : TextAlign.left,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: isMobile
                      ? WrapAlignment.center
                      : WrapAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.rocket_launch),
                      label: const Text('Start Forging Now'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 24,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isMobile) const SizedBox(width: 64),
          if (!isMobile) const Expanded(flex: 4, child: MockAppInterface()),
        ],
      ),
    );
  }
}

class MockAppInterface extends StatelessWidget {
  const MockAppInterface({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 600,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.outlineVariant, width: 8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isDark ? Colors.black : Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.menu),
                  const SizedBox(width: 12),
                  const Text(
                    'MicroForge',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const Icon(Icons.add),
                  const SizedBox(width: 12),
                  const Icon(Icons.settings),
                ],
              ),
            ),
            // Chat area
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _MockMessage(
                    isUser: true,
                    text:
                        'Forge a minimalist pomodoro timer with local storage.',
                  ),
                  _MockMessage(
                    isUser: false,
                    text:
                        "I've forged your Pomodoro Timer! It includes persistence and a sleek dark theme.",
                    hasForge: true,
                  ),
                ],
              ),
            ),
            // Input area
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text('Describe your idea...'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    backgroundColor: colorScheme.primary,
                    child: Icon(
                      Icons.send,
                      color: colorScheme.onPrimary,
                      size: 20,
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

class _MockMessage extends StatelessWidget {
  final bool isUser;
  final String text;
  final bool hasForge;

  const _MockMessage({
    required this.isUser,
    required this.text,
    this.hasForge = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              color: isUser
                  ? colorScheme.primary
                  : (isDark ? Colors.grey[800] : Colors.grey[200]),
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomRight: isUser ? const Radius.circular(0) : null,
                bottomLeft: !isUser ? const Radius.circular(0) : null,
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
          ),
          if (hasForge)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.5),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: colorScheme.primary.withOpacity(0.05),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.rocket_launch, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pomodoro Timer',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'v1.0.0 • Initial release',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      child: const Text('OPEN'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FeaturesSection extends StatelessWidget {
  const FeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
      child: Column(
        children: [
          Text(
            'Powerful Features for Forgers',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Everything you need to build and deploy mini-tools in seconds.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 64),
          Wrap(
            spacing: 32,
            runSpacing: 32,
            alignment: WrapAlignment.center,
            children: [
              _FeatureCard(
                icon: Icons.auto_fix_high,
                title: 'AI-First Workflow',
                description:
                    'Model-flexible generation pipeline for rapid, accurate micro-app creation.',
              ),
              _FeatureCard(
                icon: Icons.flash_on,
                title: 'Instant Rendering',
                description:
                    'No build step. Apps run immediately in an integrated WebView environment.',
              ),
              _FeatureCard(
                icon: Icons.storage,
                title: 'Local Persistence',
                description:
                    'Built-in bridge for SQLite and SharedPreferences to keep your data safe.',
              ),
              _FeatureCard(
                icon: Icons.code,
                title: 'Modern Stack',
                description:
                    'Leverages Alpine.js and Tailwind CSS for lightweight, reactive UIs.',
              ),
              _FeatureCard(
                icon: Icons.notifications_active,
                title: 'Background Tasks',
                description:
                    'Schedule periodic logic and notifications that run even when the app is closed.',
              ),
              _FeatureCard(
                icon: Icons.devices,
                title: 'Cross-Platform',
                description:
                    'Available on iOS, Android, macOS, Windows, and Linux, with web support coming soon after.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PricingSection extends StatelessWidget {
  const PricingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
      color: colorScheme.surfaceVariant.withOpacity(0.18),
      child: Column(
        children: [
          Text(
            'Simple Pricing',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Dummy plans for early positioning. Swap pricing and quota details later.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: 56),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: const [
              _PricingCard(
                title: 'Free',
                price: '\$0',
                subtitle: 'For trying out MicroForge',
                features: [
                  'Basic app forging',
                  'Community templates',
                  'Local previews',
                ],
              ),
              _PricingCard(
                title: 'Pro',
                price: '\$19',
                subtitle: 'For regular builders',
                badge: 'Popular',
                highlighted: true,
                features: [
                  'Higher monthly quota',
                  'Priority generation',
                  'Saved projects and history',
                ],
              ),
              _PricingCard(
                title: 'Ultra',
                price: '\$79',
                subtitle: 'For power users and teams',
                features: [
                  'Largest quota pool',
                  'Advanced model access',
                  'Team collaboration controls',
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
      child: Column(
        children: [
          Text(
            'How It Works',
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 64),
          _StepItem(
            number: '01',
            title: 'Describe Your App',
            description:
                'Use natural language to tell MicroForge what you want to build. "A simple habit tracker with a dark theme and notifications."',
          ),
          _StepItem(
            number: '02',
            title: 'AI Forges the Code',
            description:
                'MicroForge generates the HTML, Alpine.js logic, and Tailwind CSS styles for your micro-app.',
          ),
          _StepItem(
            number: '03',
            title: 'Instant Preview',
            description:
                'Interact with your new app immediately in the preview sheet. Test the functionality and UI in real-time.',
          ),
          _StepItem(
            number: '04',
            title: 'Iterate & Save',
            description:
                'Ask for changes or enhancements. Once satisfied, save it to your Vault for permanent access.',
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _StepItem({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      margin: const EdgeInsets.only(bottom: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/brand/logo.png', height: 32),
              const SizedBox(width: 12),
              const Text(
                'MicroForge',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '© 2026 MicroForge. Built with Flutter and AI-powered app generation.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {},
                icon: const FaIcon(FontAwesomeIcons.twitter, size: 20),
              ),
              IconButton(
                onPressed: () {},
                icon: const FaIcon(FontAwesomeIcons.discord, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String price;
  final String subtitle;
  final List<String> features;
  final String? badge;
  final bool highlighted;

  const _PricingCard({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.features,
    this.badge,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = highlighted
        ? colorScheme.primary.withOpacity(0.6)
        : colorScheme.outlineVariant.withOpacity(0.5);

    return Container(
      width: 320,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: highlighted
            ? colorScheme.primaryContainer.withOpacity(0.35)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: highlighted ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyLarge,
              children: [
                TextSpan(
                  text: price,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: '/mo',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: highlighted
                    ? colorScheme.primary
                    : colorScheme.surface,
                foregroundColor: highlighted
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
                side: highlighted
                    ? null
                    : BorderSide(color: colorScheme.outlineVariant),
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: Text(highlighted ? 'Choose Pro' : 'Select Plan'),
            ),
          ),
        ],
      ),
    );
  }
}
