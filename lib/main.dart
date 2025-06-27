// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
  if (notificationResponse.payload != null) {
    debugPrint('notification payload: ${notificationResponse.payload}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  final DarwinInitializationSettings initializationSettingsDarwin =
  DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neko-CLI Updates',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF111827), // Sfondo scuro profondo
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Color(0xFF4274C5), fontFamily: 'Inter', fontWeight: FontWeight.bold),
          displayMedium: TextStyle(color: Color(0xFF4274C5), fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 28), // Titolo compatto
          headlineLarge: TextStyle(color: Color(0xFF4274C5), fontFamily: 'Inter', fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(color: Color(0xFF4274C5), fontFamily: 'Inter', fontWeight: FontWeight.bold),
          titleLarge: TextStyle(color: Color(0xFF4274C5), fontFamily: 'Inter', fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Color(0xFF4274C5), fontFamily: 'Inter', fontSize: 15), // Titolo compatto
          bodyLarge: TextStyle(color: Color(0xFFD1D5DB), fontFamily: 'Inter', fontSize: 13), // Corpo compatto
          bodyMedium: TextStyle(color: Color(0xFF9CA3AF), fontFamily: 'Inter', fontSize: 11), // Secondario compatto
          labelLarge: TextStyle(color: Color(0xFF111827), fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13), // Testo pulsante compatto
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111827),
          foregroundColor: Color(0xFF4274C5),
          titleTextStyle: TextStyle(
            color: Color(0xFF4274C5),
            fontSize: 18, // Titolo AppBar molto compatto
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
          elevation: 0,
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF4274C5),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4274C5),
          background: const Color(0xFF111827),
          onBackground: const Color(0xFF4274C5),
          surface: const Color(0xFF1F2937), // Sfondo delle card
          onSurface: const Color(0xFF4274C5),
          primary: const Color(0xFF4274C5), // Blu accento
          onPrimary: const Color(0xFF111827), // Testo su blu accento
        ).copyWith(
          secondary: const Color(0xFF4274C5),
        ),
        useMaterial3: true,
      ),
      home: const NekoCLINewsletterPage(),
    );
  }
}

class NekoCLINewsletterPage extends StatefulWidget {
  const NekoCLINewsletterPage({super.key});

  @override
  State<NekoCLINewsletterPage> createState() {
    return _NekoCLINewsletterPageState();
  }
}

class _NekoCLINewsletterPageState extends State<NekoCLINewsletterPage> {
  List<dynamic> _commits = [];
  Map<String, int>? _npmDownloads;
  String? _currentNekoCliVersion;
  bool _isLoadingCommits = true;
  bool _isLoadingNpm = true;
  bool _isLoadingVersion = true;
  String? _errorMessageCommits;
  String? _errorMessageNpm;
  String? _errorMessageVersion;
  String? _latestCommitSha;

  final NumberFormat _numberFormat = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _fetchCommits();
    _fetchNpmDownloads();
    _fetchNekoCliVersion();
  }

  Future<void> _fetchCommits({bool showNotification = false}) async {
    setState(() {
      _isLoadingCommits = true;
      _errorMessageCommits = null;
    });

    const String owner = 'Neko-CLI';
    const String repo = 'Neko-CLI';
    final String url = 'https://api.github.com/repos/$owner/$repo/commits';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> newCommits = json.decode(response.body);

        if (showNotification && _latestCommitSha != null && newCommits.isNotEmpty && newCommits[0]['sha'] != _latestCommitSha) {
          _showNotification('New Neko-CLI Update! 🚀', 'A new commit has been released: ${newCommits[0]['commit']['message']}');
        }

        setState(() {
          _commits = newCommits;
          _isLoadingCommits = false;
          if (newCommits.isNotEmpty) {
            _latestCommitSha = newCommits[0]['sha'];
          }
        });
      } else {
        setState(() {
          _errorMessageCommits = 'Error loading commits: ${response.statusCode}';
          _isLoadingCommits = false;
        });
        print('Failed to load commits: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessageCommits = 'Could not connect to GitHub. Check your internet connection.';
        _isLoadingCommits = false;
      });
      print('Error fetching commits: $e');
    }
  }

  Future<void> _fetchNpmDownloads() async {
    setState(() {
      _isLoadingNpm = true;
      _errorMessageNpm = null;
    });

    const String packageName = 'neko-cli';
    final String urlWeekly = 'https://api.npmjs.org/downloads/point/last-week/$packageName';
    final String urlMonthly = 'https://api.npmjs.org/downloads/point/last-month/$packageName';
    final String urlYearly = 'https://api.npmjs.org/downloads/point/last-year/$packageName';

    try {
      final responseWeekly = await http.get(Uri.parse(urlWeekly));
      final responseMonthly = await http.get(Uri.parse(urlMonthly));
      final responseYearly = await http.get(Uri.parse(urlYearly));

      if (responseWeekly.statusCode == 200 && responseMonthly.statusCode == 200 && responseYearly.statusCode == 200) {
        setState(() {
          _npmDownloads = {
            'weekly': json.decode(responseWeekly.body)['downloads'] ?? 0,
            'monthly': json.decode(responseMonthly.body)['downloads'] ?? 0,
            'yearly': json.decode(responseYearly.body)['downloads'] ?? 0,
          };
          _isLoadingNpm = false;
        });
      } else {
        setState(() {
          _errorMessageNpm = 'Error loading NPM downloads: ${responseWeekly.statusCode}, ${responseMonthly.statusCode}, ${responseYearly.statusCode}';
          _isLoadingNpm = false;
        });
        print('Failed to load NPM downloads: ${responseWeekly.statusCode}, ${responseMonthly.statusCode}, ${responseYearly.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessageNpm = 'Could not fetch NPM download data.';
        _isLoadingNpm = false;
      });
      print('Error fetching NPM downloads: $e');
    }
  }

  Future<void> _fetchNekoCliVersion() async {
    setState(() {
      _isLoadingVersion = true;
      _errorMessageVersion = null;
    });

    const String packageName = 'neko-cli';
    final String url = 'https://registry.npmjs.org/$packageName';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> packageInfo = json.decode(response.body);
        setState(() {
          _currentNekoCliVersion = packageInfo['dist-tags']['latest'];
          _isLoadingVersion = false;
        });
      } else {
        setState(() {
          _errorMessageVersion = 'Error loading Neko-CLI version: ${response.statusCode}';
          _isLoadingVersion = false;
        });
        print('Failed to load Neko-CLI version: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessageVersion = 'Could not fetch Neko-CLI version data.';
        _isLoadingVersion = false;
      });
      print('Error fetching Neko-CLI version: $e');
    }
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'neko_cli_updates_channel',
      'Neko-CLI Updates',
      channelDescription: 'Notifications for new Neko-CLI updates',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
    DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true);

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'new_update',
    );
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url 😿')),
      );
    }
  }

  Widget _buildSkeletonLine({double width = double.infinity, double height = 12.0}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildNpmDownloadDisplay(BuildContext context) {
    if (_isLoadingNpm) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildSkeletonLine(width: 100),
            const SizedBox(height: 8),
            _buildSkeletonLine(width: 120),
            const SizedBox(height: 8),
            _buildSkeletonLine(width: 80),
          ],
        ),
      );
    }
    if (_errorMessageNpm != null) {
      return Center(
        child: Text('NPM Data Error: ${_errorMessageNpm!} ❌', style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    if (_npmDownloads == null || _npmDownloads!.isEmpty) {
      return Center(
        child: Text('No NPM download data available. 🤷‍♂️', style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDownloadRow('Weekly Downloads:', _npmDownloads!['weekly']!),
          const Divider(height: 15, thickness: 0.5, color: Color(0xFF4274C5)),
          _buildDownloadRow('Monthly Downloads:', _npmDownloads!['monthly']!),
          const Divider(height: 15, thickness: 0.5, color: Color(0xFF4274C5)),
          _buildDownloadRow('Annual Downloads:', _npmDownloads!['yearly']!),
        ],
      ),
    );
  }

  Widget _buildDownloadRow(String label, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 13),
        ),
        Text(
          _numberFormat.format(count),
          style: Theme.of(context).textTheme.titleMedium!.copyWith(
            color: Colors.blueAccent[400],
            fontFamily: 'Fira Code',
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  String _getCommitTypeEmoji(String message) {
    if (message.startsWith('feat')) return '✨ Feature:';
    if (message.startsWith('fix')) return '🐛 Bugfix:';
    if (message.startsWith('docs')) return '📚 Docs:';
    if (message.startsWith('style')) return '🎨 Style:';
    if (message.startsWith('refactor')) return '♻️ Refactor:';
    if (message.startsWith('perf')) return '⚡️ Perf:';
    if (message.startsWith('test')) return '🧪 Test:';
    if (message.startsWith('chore')) return '🧹 Chore:';
    if (message.startsWith('build')) return '🏗️ Build:';
    if (message.startsWith('ci')) return '🤖 CI:';
    return '📝 Commit:';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 120,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0, top: 2.0, bottom: 2.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                'https://i.imgur.com/DJzajwA.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.code,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              _isLoadingVersion
                  ? _buildSkeletonLine(width: 40, height: 10)
                  : _errorMessageVersion != null
                  ? Tooltip(
                message: _errorMessageVersion!,
                child: const Icon(Icons.error, size: 12, color: Colors.redAccent),
              )
                  : Text(
                'v$_currentNekoCliVersion',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Colors.blueAccent,
                  fontFamily: 'Fira Code',
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        title: const Text('Neko-CLI Updates 🐾'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: (_isLoadingCommits || _isLoadingNpm || _isLoadingVersion) ? null : () {
              _fetchCommits(showNotification: true);
              _fetchNpmDownloads();
              _fetchNekoCliVersion();
            },
            tooltip: 'Refresh All Updates ✨',
            iconSize: 20,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchCommits(showNotification: true);
          await _fetchNpmDownloads();
          await _fetchNekoCliVersion();
        },
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Neko-CLI Devlog 💻',
                      style: Theme.of(context).textTheme.displayMedium!.copyWith(
                        fontSize: 28,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Neko-CLI is your custom package manager for Node.js, designed to simplify and optimize your project\'s dependency management, making it faster, more efficient, and more secure. Stay updated with real-time commits and source transparency directly from GitHub. 😼',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: () => _launchUrl('https://neko-cli.com'),
                        icon: const Icon(Icons.public, size: 18, color: Color(0xFF111827)),
                        label: const Text('WebSite'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Download Stats 📈',
                      style: Theme.of(context).textTheme.headlineSmall!.copyWith(fontSize: 18, color: const Color(0xFFD1D5DB)),
                    ),
                    const SizedBox(height: 15),
                    _buildNpmDownloadDisplay(context),
                    const SizedBox(height: 30),
                    Text(
                      'Commit Log 📜',
                      style: Theme.of(context).textTheme.headlineSmall!.copyWith(fontSize: 18, color: const Color(0xFFD1D5DB)),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
              if (_isLoadingCommits)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                  child: Column(
                    children: List.generate(5, (index) =>
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), width: 1.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                      ),
                                      const SizedBox(width: 12),
                                      _buildSkeletonLine(width: 180, height: 16),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _buildSkeletonLine(height: 10),
                                  const SizedBox(height: 8),
                                  _buildSkeletonLine(width: 150, height: 10),
                                  const SizedBox(height: 8),
                                  _buildSkeletonLine(width: 80, height: 10),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ),
                  ),
                )
              else if (_errorMessageCommits != null)
                Padding(
                  padding: const EdgeInsets.only(top: 50.0, bottom: 20.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 60, color: Theme.of(context).textTheme.bodyMedium!.color),
                        const SizedBox(height: 15),
                        Text(
                          'Error: ${_errorMessageCommits!} ❌',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(context).textTheme.bodyMedium!.color,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _fetchCommits(showNotification: true),
                          icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF111827)),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            elevation: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_commits.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 50.0, bottom: 20.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, size: 60, color: Theme.of(context).textTheme.bodyMedium!.color),
                          const SizedBox(height: 15),
                          Text(
                            'No commits found. Check the repository or try again later. 🤷‍♀️',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
                    itemCount: _commits.length,
                    itemBuilder: (context, index) {
                      final commit = _commits[index];
                      final commitMessage = commit['commit']['message'] as String;
                      final authorName = commit['commit']['author']['name'] as String;
                      final authorEmail = commit['commit']['author']['email'] as String;
                      final dateString = commit['commit']['author']['date'] as String;

                      final committerName = commit['committer']?['login'] ?? (commit['commit']['committer']['name'] as String);
                      final committerEmail = commit['commit']['committer']['email'] as String;

                      final String? avatarUrl = commit['author']?['avatar_url'] as String?;
                      final String commitSha = commit['sha'] as String;
                      final String commitUrl = commit['html_url'] as String;

                      final bool isVerified = commit['commit']['verification']?['verified'] ?? false;
                      final String verificationReason = commit['commit']['verification']?['reason'] ?? 'unverified';

                      final DateTime commitDate = DateTime.parse(dateString);
                      final String formattedDate = DateFormat('MMM dd,yyyy HH:mm').format(commitDate);

                      final String commitTypeEmoji = _getCommitTypeEmoji(commitMessage);

                      final List<String> commitMessageLines = commitMessage.split('\n');
                      final String firstLine = commitMessageLines.isNotEmpty ? commitMessageLines[0].trim() : '';
                      final String remainingMessage = commitMessageLines.length > 1
                          ? commitMessageLines.sublist(1).join('\n').trim()
                          : '';

                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Interval(index * 0.05, 1.0, curve: Curves.easeOut),
                        )),
                        child: FadeTransition(
                          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                            CurvedAnimation(
                              parent: ModalRoute.of(context)!.animation!,
                              curve: Interval(index * 0.05, 1.0, curve: Curves.easeIn),
                            ),
                          ),
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
                            color: Theme.of(context).colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                              side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), width: 1.0),
                            ),
                            elevation: 8,
                            shadowColor: Colors.black.withOpacity(0.7),
                            child: InkWell(
                              onTap: () => _launchUrl(commitUrl),
                              borderRadius: BorderRadius.circular(10.0),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (avatarUrl != null)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 12.0),
                                            child: ClipOval(
                                              child: Image.network(
                                                avatarUrl,
                                                width: 36,
                                                height: 36,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                                  child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary, size: 20),
                                                ),
                                              ),
                                            ),
                                          ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '$commitTypeEmoji $firstLine',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15.0,
                                                  color: Theme.of(context).textTheme.titleMedium!.color,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (isVerified)
                                                Row(
                                                  children: [
                                                    Icon(Icons.verified_user, size: 14, color: Colors.blueAccent),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Signed: Verified ($verificationReason)',
                                                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                        fontSize: 10,
                                                        color: Colors.blueAccent[100],
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              else
                                                Row(
                                                  children: [
                                                    Icon(Icons.cancel, size: 14, color: Colors.orangeAccent),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Signed: Not Verified',
                                                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                        fontSize: 10,
                                                        color: Colors.orangeAccent[100],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (remainingMessage.isNotEmpty) ...[
                                      const SizedBox(height: 8.0),
                                      Text(
                                        remainingMessage,
                                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 12),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 10.0),
                                    Divider(color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
                                    const SizedBox(height: 10.0),
                                    _buildDetailRow('Author:', '$authorName <$authorEmail>', Theme.of(context).textTheme.bodyMedium!),
                                    if (authorName != committerName || authorEmail != committerEmail)
                                      _buildDetailRow('Committer:', '$committerName <$committerEmail>', Theme.of(context).textTheme.bodyMedium!),
                                    _buildDetailRow('Date:', formattedDate, Theme.of(context).textTheme.bodyMedium!),

                                    const SizedBox(height: 5.0),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () => _launchUrl(commitUrl),
                                        icon: const Icon(Icons.code, size: 16, color: Colors.blueAccent),
                                        label: Text(
                                          'SHA: ${commitSha.substring(0, 10)}',
                                          style: TextStyle(
                                            fontFamily: 'Fira Code',
                                            fontFamilyFallback: const ['monospace'],
                                            fontSize: 12.0,
                                            color: Colors.blueAccent[400],
                                            decoration: TextDecoration.underline,
                                            decorationColor: Colors.blueAccent[400],
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 5.0),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _launchUrl(commitUrl),
                                        icon: const FaIcon(FontAwesomeIcons.github, size: 14, color: Color(0xFF111827)),
                                        label: const Text('View on GitHub'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).colorScheme.primary,
                                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          elevation: 3,
                                          textStyle: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 11),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF1F2937),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCompactSocialButton(FontAwesomeIcons.xTwitter, 'https://x.com/NekoCLI'),
              _buildCompactSocialButton(FontAwesomeIcons.youtube, 'https://www.youtube.com/@Neko-CLI'),
              _buildCompactSocialButton(FontAwesomeIcons.discord, 'https://discord.com/invite/5wuywh8zcb'),
              _buildCompactSocialButton(FontAwesomeIcons.instagram, 'https://www.instagram.com/nekocliofficial/'),
              _buildCompactSocialButton(FontAwesomeIcons.whatsapp, 'https://wa.me/14016777229'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSocialButton(IconData icon, String url) {
    return IconButton(
      icon: FaIcon(icon),
      color: Theme.of(context).colorScheme.primary,
      iconSize: 22,
      onPressed: () => _launchUrl(url),
      splashRadius: 24,
    );
  }

  Widget _buildDetailRow(String label, String value, TextStyle valueStyle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle.copyWith(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}