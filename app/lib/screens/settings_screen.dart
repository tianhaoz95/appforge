import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
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
  bool _isChangingPassword = false;
  bool _showOldPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
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
            backgroundColor: Colors.redAccent,
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
        setState(() => _isChangingPassword = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating password: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
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
              backgroundColor: Colors.redAccent,
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
              backgroundColor: Colors.redAccent,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                _buildProfileHeader(user, theme, settingsProvider),
                if (user?.email != null) ...[
                  const SizedBox(height: 24),
                  _buildPasswordSection(theme),
                ],
                const SizedBox(height: 32),
                _buildSectionHeader('App preferences'),
                const SizedBox(height: 12),
                _buildPreferenceItem(
                  icon: Icons.memory,
                  title: 'HAL Mode',
                  subtitle: 'Enable experimental AI features',
                  trailing: Switch(
                    value: settingsProvider.halMode,
                    onChanged: (v) => settingsProvider.setHalMode(v),
                  ),
                ),
                _buildPreferenceItem(
                  icon: Icons.palette_outlined,
                  title: 'App Theme',
                  subtitle: 'Choose your preferred look',
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto, size: 18)),
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 18)),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18)),
                    ],
                    selected: {settingsProvider.themeMode},
                    onSelectionChanged: (Set<ThemeMode> newSelection) {
                      settingsProvider.setThemeMode(newSelection.first);
                    },
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader('Token Usage'),
                const SizedBox(height: 12),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: ExpansionTile(
                      title: const Text('View Token Usage Details', style: TextStyle(fontSize: 14)),
                      initiallyExpanded: false,
                      childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      children: [
                      _buildTokenRow('Prompt Tokens', settingsProvider.totalPromptTokens, theme),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(height: 1),
                      ),
                      _buildTokenRow('Candidate Tokens', settingsProvider.totalCandidateTokens, theme),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(height: 1),
                      ),
                      if (settingsProvider.totalThoughtsTokens > 0) ...[
                        _buildTokenRow('Thoughts Tokens', settingsProvider.totalThoughtsTokens, theme),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(height: 1),
                        ),
                      ],
                      if (settingsProvider.totalCachedTokens > 0) ...[
                        _buildTokenRow('Cached Tokens', settingsProvider.totalCachedTokens, theme),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(height: 1),
                        ),
                      ],
                      if (settingsProvider.totalToolUseTokens > 0) ...[
                        _buildTokenRow('Tool Use Tokens', settingsProvider.totalToolUseTokens, theme),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(height: 1),
                        ),
                      ],
                        _buildTokenRow('Total Tokens', settingsProvider.totalTotalTokens, theme, isBold: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader('AI agent preferences'),
                const SizedBox(height: 12),
                _buildPreferenceItem(
                  icon: Icons.lightbulb_outline,
                  title: 'Suggest Existing Apps',
                  subtitle: 'AI will look for similar apps before forging new ones',
                  trailing: Switch(
                    value: settingsProvider.suggestExistingApps,
                    onChanged: (v) => settingsProvider.setSuggestExistingApps(v),
                  ),
                ),
                _buildPreferenceItem(
                  icon: Icons.auto_fix_high_outlined,
                  title: 'Default Mode',
                  subtitle: 'Initial mode for new conversations',
                  trailing: SegmentedButton<ForgeMode>(
                    segments: const [
                      ButtonSegment<ForgeMode>(
                        value: ForgeMode.plan,
                        label: Text('Plan'),
                        icon: Icon(Icons.architecture_outlined, size: 18),
                      ),
                      ButtonSegment<ForgeMode>(
                        value: ForgeMode.build,
                        label: Text('Build'),
                        icon: Icon(Icons.bolt, size: 18),
                      ),
                    ],
                    selected: {settingsProvider.defaultForgeMode},
                    onSelectionChanged: (Set<ForgeMode> newSelection) {
                      settingsProvider.setDefaultForgeMode(newSelection.first);
                    },
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                _buildPreferenceItem(
                  icon: Icons.terminal_outlined,
                  title: 'View and Edit System Instructions',
                  subtitle: 'Inspect or customize the instructions sent to the AI',
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_document),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SystemPromptScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader('Model Provider'),
                const SizedBox(height: 12),
                _buildPreferenceItem(
                  icon: Icons.hub_outlined,
                  title: 'Use Local OpenAI API',
                  subtitle: 'Use an OpenAI compatible local backend (e.g. Ollama, LM Studio)',
                  trailing: Switch(
                    value: settingsProvider.useLocalOpenAi,
                    onChanged: (v) => settingsProvider.setUseLocalOpenAi(v),
                  ),
                ),
                if (settingsProvider.useLocalOpenAi) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 48, right: 0, top: 8, bottom: 16),
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'OpenAI API URL',
                        hintText: 'http://localhost:11434/v1/chat/completions',
                        helperText: 'Full endpoint URL for chat completions',
                        isDense: true,
                        filled: true,
                        fillColor: theme.brightness == Brightness.light
                            ? Colors.grey[100]
                            : Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                        ),
                      ),
                      controller: TextEditingController(text: settingsProvider.localOpenAiUrl)
                        ..selection = TextSelection.fromPosition(
                          TextPosition(offset: settingsProvider.localOpenAiUrl.length),
                        ),
                      onChanged: (v) => settingsProvider.setLocalOpenAiUrl(v),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                _buildSectionHeader('App access control'),
                const SizedBox(height: 12),
                _buildPreferenceItem(
                  icon: Icons.location_on_outlined,
                  title: 'Allow Geolocation',
                  subtitle: 'Enable geolocation access for your micro-apps',
                  trailing: Switch(
                    value: settingsProvider.allowGeolocation,
                    onChanged: (v) async {
                      if (v) {
                        final permission = await Geolocator.requestPermission();
                        if (permission == LocationPermission.denied ||
                            permission == LocationPermission.deniedForever) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Location permission denied'),
                              backgroundColor: Colors.redAccent,
                            ),
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
                  subtitle: 'Enable motion and tilt data for your micro-apps',
                  trailing: Switch(
                    value: settingsProvider.allowAccelerometer,
                    onChanged: (v) async {
                      // Note: On most platforms, sensors_plus doesn't require explicit runtime permission
                      // but some newer iOS/Android versions or Web might need it.
                      // For now, we simply update the provider.
                      settingsProvider.setAllowAccelerometer(v);
                    },
                  ),
                ),
                _buildPreferenceItem(
                  icon: Icons.notifications_active_outlined,
                  title: 'Allow Notifications',
                  subtitle: 'Enable local notifications for your micro-apps',
                  trailing: Switch(
                    value: settingsProvider.allowNotifications,
                    onChanged: (v) async {
                      if (v) {
                        await _requestNotificationPermissions();
                      }
                      settingsProvider.setAllowNotifications(v);
                    },
                  ),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader('Server access control'),
                const SizedBox(height: 12),
                _buildPreferenceItem(
                  icon: Icons.storage_outlined,
                  title: 'Allow database access',
                  subtitle: 'Enable database access for the backend engine',
                  trailing: Switch(
                    value: settingsProvider.allowBackendDatabase,
                    onChanged: (v) => settingsProvider.setAllowBackendDatabase(v),
                  ),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader('Background task access control'),
                const SizedBox(height: 12),
                _buildPreferenceItem(
                  icon: Icons.running_with_errors_outlined,
                  title: 'Allow Background Execution',
                  subtitle: 'Run periodic micro-app tasks in the background',
                  trailing: Switch(
                    value: settingsProvider.allowBackgroundExecution,
                    onChanged: (v) => settingsProvider.setAllowBackgroundExecution(v),
                  ),
                ),
                _buildPreferenceItem(
                  icon: Icons.notification_important_outlined,
                  title: 'Allow notifications toggles',
                  subtitle: 'Allow background tasks to show notifications',
                  trailing: Switch(
                    value: settingsProvider.allowBackgroundNotifications,
                    onChanged: (v) async {
                      if (v) {
                        await _requestNotificationPermissions();
                      }
                      settingsProvider.setAllowBackgroundNotifications(v);
                    },
                  ),
                ),
                _buildPreferenceItem(
                  icon: Icons.cloud_done_outlined,
                  title: 'Allow database access',
                  subtitle: 'Allow background tasks to access the database',
                  trailing: Switch(
                    value: settingsProvider.allowBackgroundDatabase,
                    onChanged: (v) => settingsProvider.setAllowBackgroundDatabase(v),
                  ),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader('Account'),
                const SizedBox(height: 12),
                _buildAccountAction(
                  icon: Icons.logout_rounded,
                  title: 'Sign Out',
                  onTap: () async {
                    await authProvider.signOut();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                _buildAccountAction(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete Account',
                  color: Colors.redAccent,
                  onTap: _deleteAccount,
                ),
                const SizedBox(height: 48),
                _buildAppInfo(theme),
                const SizedBox(height: 24),
                _buildLegalLinks(context, theme),
              ],
            ),
    );
  }

  Widget _buildLegalLinks(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LegalNoticeScreen(
                type: LegalNoticeType.privacyNotice,
              ),
            ),
          ),
          child: Text(
            'Privacy Notice',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
          ),
        ),
        Text(
          '•',
          style: TextStyle(fontSize: 12, color: theme.hintColor),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LegalNoticeScreen(
                type: LegalNoticeType.userAgreement,
              ),
            ),
          ),
          child: Text(
            'User Agreement',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordSection(ThemeData theme) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1.0,
            child: child,
          ),
        );
      },
      child: !_isChangingPassword
          ? Row(
              key: const ValueKey('password_button'),
              children: [
                const Icon(Icons.lock_outline, size: 20, color: Colors.blueGrey),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () => setState(() => _isChangingPassword = true),
                  icon: const Icon(Icons.lock_reset, size: 18),
                  label: const Text('Change Password'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            )
          : Container(
              key: const ValueKey('password_form'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_reset, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Change Password',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _oldPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Old Password',
                      isDense: true,
                      prefixIcon: const Icon(Icons.password, size: 18),
                      filled: true,
                      fillColor: theme.brightness == Brightness.light
                          ? Colors.grey[200]
                          : Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showOldPassword ? Icons.visibility : Icons.visibility_off,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _showOldPassword = !_showOldPassword),
                      ),
                    ),
                    obscureText: !_showOldPassword,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      isDense: true,
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      filled: true,
                      fillColor: theme.brightness == Brightness.light
                          ? Colors.grey[200]
                          : Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showNewPassword ? Icons.visibility : Icons.visibility_off,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
                      ),
                    ),
                    obscureText: !_showNewPassword,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      isDense: true,
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      filled: true,
                      fillColor: theme.brightness == Brightness.light
                          ? Colors.grey[200]
                          : Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                      ),
                    ),
                    obscureText: !_showConfirmPassword,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isChangingPassword = false;
                            _oldPasswordController.clear();
                            _newPasswordController.clear();
                            _confirmPasswordController.clear();
                            _showOldPassword = false;
                            _showNewPassword = false;
                            _showConfirmPassword = false;
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton.tonal(
                        onPressed: _changePassword,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Update Password'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(dynamic user, ThemeData theme, SettingsProvider settingsProvider) {
    final initials = (user?.displayName ?? user?.email ?? 'U')
        .toString()
        .substring(0, 1)
        .toUpperCase();

    return Row(
      crossAxisAlignment: _isEditingProfile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _pickAvatar,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: settingsProvider.localAvatarPath.isNotEmpty
                    ? FileImage(File(settingsProvider.localAvatarPath))
                    : null,
                child: settingsProvider.localAvatarPath.isEmpty
                    ? Text(
                        initials,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: 14,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _isEditingProfile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        hintText: 'Enter your name',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isEditingProfile = false;
                              _nameController.text = user?.displayName ?? '';
                            });
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () async {
                            await _updateProfile();
                            setState(() => _isEditingProfile = false);
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user?.displayName ?? 'Forgemaster',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (settingsProvider.halMode) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'HAL 9000',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'anonymous@microforge.ai',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
        ),
        if (!_isEditingProfile)
          IconButton(
            onPressed: () => setState(() => _isEditingProfile = true),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Colors.blueGrey,
      ),
    );
  }

  Widget _buildPreferenceItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.blueGrey[700]),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: trailing,
    );
  }

  Widget _buildTokenRow(String label, int value, ThemeData theme, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontFamily: 'monospace',
            color: isBold ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color ?? Colors.blueGrey[700]),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildAppInfo(ThemeData theme) {
    return Column(
      children: [
        const Text(
          'MicroForge v1.2.32',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          'Forged with Flutter AI Toolkit',
          style: TextStyle(color: theme.hintColor, fontSize: 11),
        ),
      ],
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
