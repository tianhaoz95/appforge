import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'dart:io';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/forge_mode.dart';
import 'legal_notice_screen.dart';
import 'system_prompt_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isEditingProfile = false;
  bool _showOldPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  double? _localModelMaxGenLenSliderValue;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
    }
  }

  Future<void> _requestNotificationPermissions() async {
    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().updateDisplayName(_nameController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    final oldPass = _oldPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all password fields')),
      );
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().changePassword(oldPass, newPass);
      if (mounted) {
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating password: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This action is permanent and cannot be undone. All your forged apps and history will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        await context.read<AuthProvider>().deleteAccount();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Avatar'),
        content: const Text(
          'Choose a new profile picture. This only applies to this device and won\'t sync to other devices with the same account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image != null && mounted) {
      final appDir = await getApplicationDocumentsDirectory();
      if (!mounted) return;
      
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.png';
      final localFile = File('${appDir.path}/$fileName');
      
      // Clean up old avatar if exists
      final oldPath = context.read<SettingsProvider>().localAvatarPath;
      if (oldPath.isNotEmpty) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }

      await File(image.path).copy(localFile.path);
      if (mounted) {
        context.read<SettingsProvider>().setLocalAvatarPath(localFile.path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar updated locally'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final user = authProvider.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                _buildCategoryCard(
                  'Account',
                  [
                    _buildProfileHeader(user, theme, settingsProvider),
                    if (user?.email != null) ...[
                      const SizedBox(height: 16),
                      _buildPasswordSection(theme),
                    ],
                    const Divider(height: 32),
                    _buildAccountAction(
                      icon: Icons.logout_rounded,
                      title: 'Sign Out',
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await authProvider.signOut();
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                    _buildAccountAction(
                      icon: Icons.delete_outline_rounded,
                      title: 'Delete Account',
                      color: theme.colorScheme.error,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _deleteAccount();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCategoryCard(
                  'AI Model',
                  [
                    _buildPreferenceItem(
                      icon: Icons.computer_outlined,
                      title: 'Use Local LLM (On-device)',
                      subtitle: 'Snowglobe engine running locally',
                      trailing: Switch(
                        value: settingsProvider.useSnowglobeLocalModel,
                        onChanged: (v) {
                          HapticFeedback.lightImpact();
                          settingsProvider.setUseSnowglobeLocalModel(v);
                        },
                      ),
                    ),
                    if (settingsProvider.useSnowglobeLocalModel) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 48, right: 16, bottom: 16),
                        child: _buildLocalModelSettings(theme, settingsProvider),
                      ),
                    ],
                    _buildPreferenceItem(
                      icon: Icons.hub_outlined,
                      title: 'Use Remote OpenAI API',
                      subtitle: 'Ollama, LM Studio, etc.',
                      trailing: Switch(
                        value: settingsProvider.useLocalOpenAi,
                        onChanged: (v) {
                          HapticFeedback.lightImpact();
                          settingsProvider.setUseLocalOpenAi(v);
                        },
                      ),
                    ),
                    if (settingsProvider.useLocalOpenAi) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 48, right: 16, bottom: 16),
                        child: _buildRemoteModelSettings(theme, settingsProvider),
                      ),
                    ],
                    _buildPreferenceItem(
                      icon: Icons.lightbulb_outline,
                      title: 'Suggest Existing Apps',
                      subtitle: 'Avoid duplicate forgings',
                      trailing: Switch(
                        value: settingsProvider.suggestExistingApps,
                        onChanged: (v) {
                          HapticFeedback.lightImpact();
                          settingsProvider.setSuggestExistingApps(v);
                        },
                      ),
                    ),
                    _buildPreferenceItem(
                      icon: Icons.auto_fix_high_outlined,
                      title: 'Default Forge Mode',
                      trailing: SegmentedButton<ForgeMode>(
                        segments: const [
                          ButtonSegment(value: ForgeMode.plan, label: Text('Plan'), icon: Icon(Icons.architecture_outlined, size: 16)),
                          ButtonSegment(value: ForgeMode.build, label: Text('Build'), icon: Icon(Icons.bolt, size: 16)),
                        ],
                        selected: {settingsProvider.defaultForgeMode},
                        onSelectionChanged: (Set<ForgeMode> newSelection) {
                          HapticFeedback.selectionClick();
                          settingsProvider.setDefaultForgeMode(newSelection.first);
                        },
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    ),
                    const Divider(height: 32),
                    _buildTokenUsageTile(theme, settingsProvider),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCategoryCard(
                  'Appearance',
                  [
                    _buildPreferenceItem(
                      icon: Icons.palette_outlined,
                      title: 'App Theme',
                      trailing: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto, size: 18)),
                          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 18)),
                          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18)),
                        ],
                        selected: {settingsProvider.themeMode},
                        onSelectionChanged: (Set<ThemeMode> newSelection) {
                          HapticFeedback.selectionClick();
                          settingsProvider.setThemeMode(newSelection.first);
                        },
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    ),
                    _buildPreferenceItem(
                      icon: Icons.terminal_outlined,
                      title: 'System Instructions',
                      subtitle: 'Customize AI behavior',
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_document),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SystemPromptScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCategoryCard(
                  'System',
                  [
                    _buildPreferenceItem(
                      icon: Icons.location_on_outlined,
                      title: 'Allow Geolocation',
                      trailing: Switch(
                        value: settingsProvider.allowGeolocation,
                        onChanged: (v) async {
                          HapticFeedback.lightImpact();
                          if (v) {
                            final permission = await Geolocator.requestPermission();
                            if (permission == LocationPermission.denied ||
                                permission == LocationPermission.deniedForever) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Location permission denied')),
                              );
                              return;
                            }
                          }
                          settingsProvider.setAllowGeolocation(v);
                        },
                      ),
                    ),
                    _buildPreferenceItem(
                      icon: Icons.vibration_outlined,
                      title: 'Allow Accelerometer',
                      trailing: Switch(
                        value: settingsProvider.allowAccelerometer,
                        onChanged: (v) {
                          HapticFeedback.lightImpact();
                          settingsProvider.setAllowAccelerometer(v);
                        },
                      ),
                    ),
                    _buildPreferenceItem(
                      icon: Icons.notifications_active_outlined,
                      title: 'Allow Notifications',
                      trailing: Switch(
                        value: settingsProvider.allowNotifications,
                        onChanged: (v) async {
                          HapticFeedback.lightImpact();
                          if (v) await _requestNotificationPermissions();
                          settingsProvider.setAllowNotifications(v);
                        },
                      ),
                    ),
                    const Divider(height: 32),
                    _buildPreferenceItem(
                      icon: Icons.storage_outlined,
                      title: 'Backend Database Access',
                      trailing: Switch(
                        value: settingsProvider.allowBackendDatabase,
                        onChanged: (v) {
                          HapticFeedback.lightImpact();
                          settingsProvider.setAllowBackendDatabase(v);
                        },
                      ),
                    ),
                    _buildPreferenceItem(
                      icon: Icons.running_with_errors_outlined,
                      title: 'Background Execution',
                      trailing: Switch(
                        value: settingsProvider.allowBackgroundExecution,
                        onChanged: (v) {
                          HapticFeedback.lightImpact();
                          settingsProvider.setAllowBackgroundExecution(v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                _buildAppInfo(theme),
                const SizedBox(height: 24),
                _buildLegalLinks(context, theme),
              ],
            ),
    );
  }

  Widget _buildProfileHeader(User? user, ThemeData theme, SettingsProvider settingsProvider) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _pickAvatar();
          },
          child: CircleAvatar(
            radius: 36,
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage: settingsProvider.localAvatarPath.isNotEmpty
                ? FileImage(File(settingsProvider.localAvatarPath))
                : null,
            child: settingsProvider.localAvatarPath.isEmpty
                ? Text(
                    (user?.displayName?[0] ?? user?.email?[0] ?? 'U').toUpperCase(),
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEditingProfile)
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check, size: 20),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _updateProfile();
                        setState(() => _isEditingProfile = false);
                      },
                    ),
                  ),
                  onSubmitted: (_) {
                    HapticFeedback.mediumImpact();
                    _updateProfile();
                    setState(() => _isEditingProfile = false);
                  },
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user?.displayName ?? 'Anonymous User',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isEditingProfile = true);
                      },
                    ),
                  ],
                ),
              Text(
                user?.email ?? 'Not signed in',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordSection(ThemeData theme) {
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: const Text('Security & Password', style: TextStyle(fontSize: 14)),
        leading: const Icon(Icons.password_rounded),
        tilePadding: EdgeInsets.zero,
        onExpansionChanged: (v) {
          if (v) HapticFeedback.lightImpact();
        },
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _buildPasswordField(_oldPasswordController, 'Old Password', _showOldPassword, (v) => setState(() => _showOldPassword = v)),
                const SizedBox(height: 8),
                _buildPasswordField(_newPasswordController, 'New Password', _showNewPassword, (v) => setState(() => _showNewPassword = v)),
                const SizedBox(height: 8),
                _buildPasswordField(_confirmPasswordController, 'Confirm New Password', _showConfirmPassword, (v) => setState(() => _showConfirmPassword = v)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _changePassword();
                    },
                    child: const Text('Update Password'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label, bool visible, Function(bool) toggle) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_off : Icons.visibility, size: 20),
          onPressed: () {
            HapticFeedback.lightImpact();
            toggle(!visible);
          },
        ),
      ),
    );
  }

  Widget _buildAccountAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontSize: 14)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildPreferenceItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: trailing,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildTokenRow(String label, int value, ThemeData theme, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  Widget _buildAppInfo(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Image.asset('assets/brand/logo.png', height: 48, errorBuilder: (_, _, _) => const Icon(Icons.auto_awesome, size: 48)),
          const SizedBox(height: 12),
          const Text('MicroForge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final info = snapshot.data!;
                return Text('Version ${info.version} (Build ${info.buildNumber})', style: TextStyle(fontSize: 12, color: theme.hintColor));
              }
              return Text('Version ...', style: TextStyle(fontSize: 12, color: theme.hintColor));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegalLinks(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalNoticeScreen(type: LegalNoticeType.privacyNotice)));
          },
          child: const Text('Privacy Policy', style: TextStyle(fontSize: 12)),
        ),
        const Text('•'),
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalNoticeScreen(type: LegalNoticeType.userAgreement)));
          },
          child: const Text('Terms of Service', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalModelSettings(ThemeData theme, SettingsProvider settingsProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (settingsProvider.isDownloadingModel) ...[
          const Text('Downloading model...', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: settingsProvider.modelDownloadProgress,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          Text(
            '${(settingsProvider.modelDownloadProgress * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 10, color: theme.hintColor),
          ),
        ] else if (!settingsProvider.isModelDownloaded) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                settingsProvider.downloadModel();
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download Model (0.8B)'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ] else ...[
          Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
              const SizedBox(width: 8),
              const Text('Model ready', style: TextStyle(fontSize: 12, color: Colors.green)),
            ],
          ),
        ],
        if (settingsProvider.isModelDownloaded) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Max context length', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text(
                '${(_localModelMaxGenLenSliderValue ?? settingsProvider.localModelMaxGenLen).toInt()} tokens',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: (_localModelMaxGenLenSliderValue ?? settingsProvider.localModelMaxGenLen.toDouble()),
            min: 512,
            max: 8192,
            divisions: 15,
            onChanged: (v) => setState(() => _localModelMaxGenLenSliderValue = v),
            onChangeEnd: (v) {
              HapticFeedback.selectionClick();
              settingsProvider.setLocalModelMaxGenLen(v.toInt());
              setState(() => _localModelMaxGenLenSliderValue = null);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildRemoteModelSettings(ThemeData theme, SettingsProvider settingsProvider) {
    return TextField(
      decoration: InputDecoration(
        labelText: 'OpenAI API URL',
        hintText: 'http://localhost:11434/v1',
        isDense: true,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      controller: TextEditingController(text: settingsProvider.localOpenAiUrl)
        ..selection = TextSelection.fromPosition(
          TextPosition(offset: settingsProvider.localOpenAiUrl.length),
        ),
      onChanged: (v) => settingsProvider.setLocalOpenAiUrl(v),
    );
  }

  Widget _buildTokenUsageTile(ThemeData theme, SettingsProvider settingsProvider) {
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: const Text('Token Usage Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        leading: Icon(Icons.analytics_outlined, color: theme.colorScheme.primary),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 16),
        children: [
          _buildTokenRow('Prompt Tokens', settingsProvider.totalPromptTokens, theme),
          const SizedBox(height: 8),
          _buildTokenRow('Candidate Tokens', settingsProvider.totalCandidateTokens, theme),
          const SizedBox(height: 8),
          if (settingsProvider.totalThoughtsTokens > 0) ...[
            _buildTokenRow('Thoughts Tokens', settingsProvider.totalThoughtsTokens, theme),
            const SizedBox(height: 8),
          ],
          const Divider(),
          _buildTokenRow('Total Tokens', settingsProvider.totalTotalTokens, theme, isBold: true),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
