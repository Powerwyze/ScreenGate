import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:taskassassin/theme.dart';
import 'package:taskassassin/providers/app_provider.dart';
import 'package:taskassassin/screens/onboarding_screen.dart';
import 'package:taskassassin/screens/main_screen.dart';
import 'package:taskassassin/screens/create_mission_screen.dart';
import 'package:taskassassin/screens/mission_detail_screen.dart';
import 'package:taskassassin/screens/handler_chat_screen.dart';
import 'package:taskassassin/screens/handler_selection_screen.dart';
import 'package:taskassassin/screens/auth_screen.dart';
import 'package:taskassassin/screens/notifications_screen.dart';
import 'package:taskassassin/screens/bug_report_screen.dart';
import 'package:taskassassin/models/mission.dart';
import 'package:taskassassin/models/user.dart';
import 'package:taskassassin/supabase/supabase_config.dart';
import 'package:taskassassin/screens/progress_screen.dart';
import 'package:taskassassin/screens/leaderboard_screen.dart';
import 'package:taskassassin/screens/direct_message_screen.dart';
import 'package:taskassassin/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseConfig.initialize();
    debugPrint('[Supabase] Initialized successfully');
  } catch (e) {
    debugPrint('[Supabase] Initialization error: $e');
  }

  // Initialize push notifications silently - don't block app startup if it fails
  PushNotificationService().initialize().then((_) {
    debugPrint('[Push Notifications] Initialized successfully');
  }).catchError((e) {
    debugPrint('[Push Notifications] Initialization error (non-blocking): $e');
  });

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..initialize(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    // Access the provider properly since MyApp is now a child of ChangeNotifierProvider
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    _router = GoRouter(
      initialLocation: '/auth',
      refreshListenable: appProvider,
      redirect: (context, state) {
        final isInitialized = appProvider.isInitialized;
        final isLoggedIn = appProvider.isAuthenticated;
        final profileResolved = appProvider.profileResolved;
        final hasCompletedOnboarding = appProvider.hasCompletedOnboarding;
        final isLoggingIn = state.uri.toString() == '/auth';
        final isOnboarding = state.uri.toString() == '/onboarding';

        // 1. If app is not initialized yet, don't redirect (let the loading screen handle it)
        if (!isInitialized) return null;

        if (appProvider.isPairingChild) return null;

        // 2. If not logged in, force to auth
        if (!isLoggedIn) {
          return isLoggingIn ? null : '/auth';
        }

        // 3. If logged in but profile load is pending, wait (don't redirect yet)
        if (!profileResolved) return null;

        // 4. If logged in & profile loaded, check onboarding status
        if (!hasCompletedOnboarding) {
          return isOnboarding ? null : '/onboarding';
        }

        // 5. If logged in & onboarding complete, prevent access to auth/onboarding
        if (isLoggingIn || isOnboarding) {
          return '/home';
        }

        // 6. Otherwise allow access
        return null;
      },
      routes: [
        GoRoute(
          path: '/auth',
          builder: (context, state) => const AuthScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        // ShellRoute for persistent bottom navigation
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const MainScreen(),
            ),
            GoRoute(
              path: '/create-mission',
              builder: (context, state) {
                final friend = state.extra as User?;
                return CreateMissionScreen(assignee: friend);
              },
            ),
            GoRoute(
              path: '/mission-detail',
              builder: (context, state) {
                final extra = state.extra;
                Mission? mission;

                if (extra is Mission) {
                  mission = extra;
                } else if (extra is Map<String, dynamic>) {
                  mission = Mission.fromJson(extra);
                } else if (extra is Map) {
                  // Gracefully handle loosely typed maps from deep links or reloads
                  mission = Mission.fromJson(extra
                      .map((key, value) => MapEntry(key.toString(), value)));
                }

                if (mission == null) {
                  debugPrint(
                      '[Router] Missing or invalid mission payload for /mission-detail');
                  return const Scaffold(
                    body: Center(
                        child: Text(
                            'Quest details unavailable. Please reopen it from Quests.')),
                  );
                }

                return MissionDetailScreen(mission: mission);
              },
            ),
            GoRoute(
              path: '/handler-chat',
              builder: (context, state) => const HandlerChatScreen(),
            ),
            GoRoute(
              path: '/handler-selection',
              builder: (context, state) => const HandlerSelectionScreen(),
            ),
            GoRoute(
              path: '/notifications',
              builder: (context, state) => const NotificationsScreen(),
            ),
            GoRoute(
              path: '/bug-report',
              builder: (context, state) => const BugReportScreen(),
            ),
            GoRoute(
              path: '/progress',
              builder: (context, state) => const ProgressScreen(),
            ),
            GoRoute(
              path: '/leaderboard',
              builder: (context, state) => const LeaderboardScreen(),
            ),
            GoRoute(
              path: '/direct-message',
              builder: (context, state) {
                final extra = state.extra;
                if (extra is User) {
                  return DirectMessageScreen(peer: extra);
                }

                debugPrint(
                    '[Router] Missing or invalid user for /direct-message');
                return const Scaffold(
                  body: Center(
                      child: Text(
                          'Chat unavailable. Please reopen from your friends list.')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to provider changes to trigger rebuilds if needed (though GoRouter listens too)
    // We mostly need this to show the loading screen if not initialized.
    final provider = Provider.of<AppProvider>(context);

    if (!provider.isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Questime',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}

/// App shell - just passes through the child (MainScreen handles its own navigation)
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const GlobalBottomNavBar(),
    );
  }
}

class GlobalBottomNavBar extends StatelessWidget {
  const GlobalBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final isParent =
            provider.currentUser?.accountRole == AccountRole.parent;
        final destinations = isParent
            ? const [
                (Icons.home_rounded, 'Home'),
                (Icons.checklist_rounded, 'Quests'),
                (Icons.family_restroom_rounded, 'Family'),
                (Icons.settings_rounded, 'Settings'),
              ]
            : const [
                (Icons.today_rounded, 'Today'),
                (Icons.stars_rounded, 'Rewards'),
                (Icons.insights_rounded, 'Progress'),
                (Icons.settings_rounded, 'Settings'),
              ];
        return NavigationBar(
          height: 70,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFDDF4EE),
          selectedIndex: provider.currentTab.clamp(0, 3),
          onDestinationSelected: (index) {
            provider.setCurrentTab(index);
            context.go('/home');
          },
          destinations: destinations
              .map((item) => NavigationDestination(
                    icon: Icon(item.$1),
                    selectedIcon: Icon(item.$1, color: const Color(0xFF0B8F87)),
                    label: item.$2,
                  ))
              .toList(),
        );
      },
    );
  }
}

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({super.key});

  int _getSelectedIndex(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/handler-chat')) return 1;
    if (location.startsWith('/create-mission')) return 2;
    if (location.startsWith('/notifications')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _getSelectedIndex(location);

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/handler-chat');
            break;
          case 2:
            context.go('/create-mission');
            break;
          case 3:
            context.go('/notifications');
            break;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_outlined),
          selectedIcon: Icon(Icons.chat),
          label: 'Handler',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_circle_outline),
          selectedIcon: Icon(Icons.add_circle),
          label: 'New Mission',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications),
          label: 'Alerts',
        ),
      ],
    );
  }
}
