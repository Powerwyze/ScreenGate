import 'dart:async';

import 'package:flutter/material.dart';
import 'package:taskassassin/models/user.dart';
import 'package:taskassassin/models/handler.dart';
import 'package:taskassassin/models/mission.dart';
import 'package:taskassassin/services/user_service.dart';
import 'package:taskassassin/services/handler_service.dart';
import 'package:taskassassin/services/mission_service.dart';
import 'package:taskassassin/services/achievement_service.dart';
import 'package:taskassassin/services/friend_service.dart';
import 'package:taskassassin/services/message_service.dart';
import 'package:taskassassin/services/chat_service.dart';
import 'package:taskassassin/services/ai_service.dart';
import 'package:taskassassin/services/notification_service.dart';
import 'package:taskassassin/services/bug_report_service.dart';
import 'package:taskassassin/services/push_notification_service.dart';
import 'package:taskassassin/services/screen_time_service.dart';
import 'package:taskassassin/services/reward_service.dart';
import 'package:taskassassin/supabase/supabase_config.dart';

class AppProvider extends ChangeNotifier {
  int _currentTab = 0;
  int get currentTab => _currentTab;

  void setCurrentTab(int index) {
    _currentTab = index;
    notifyListeners();
  }

  late final UserService userService;
  late final HandlerService handlerService;
  late final MissionService missionService;
  late final AchievementService achievementService;
  late final FriendService friendService;
  late final MessageService messageService;
  late final ChatService chatService;
  late final AIService aiService;
  late final NotificationService notificationService;
  late final BugReportService bugReportService;

  User? _currentUser;
  Handler? _currentHandler;
  List<Mission> _missions = [];
  bool _isInitialized = false;
  bool _profileResolved =
      false; // whether we've checked if the user profile exists
  bool _isPairingChild = false;
  StreamSubscription<List<Mission>>? _missionSubscription;
  StreamSubscription<int>? _rewardSubscription;
  int _availableRewardMinutes = 0;
  Timer? _refreshTimer;

  User? get currentUser => _currentUser;
  Handler? get currentHandler => _currentHandler;
  List<Mission> get missions => _missions;
  bool get isInitialized => _isInitialized;
  // True if a user profile exists. Requires profileResolved to be meaningful.
  bool get hasCompletedOnboarding => _currentUser != null;
  bool get profileResolved => _profileResolved;
  bool get isAuthenticated => SupabaseConfig.auth.currentUser != null;
  bool get isPairingChild => _isPairingChild;
  int get availableRewardMinutes => _availableRewardMinutes;

  void setPairingChild(bool value) {
    _isPairingChild = value;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize storage first

      // Initialize all services (synchronous - no risk of blocking)
      userService = UserService();
      missionService = MissionService();
      handlerService = HandlerService();
      achievementService = AchievementService();
      friendService = FriendService();
      messageService = MessageService();
      chatService = ChatService();
      aiService = AIService();
      notificationService = NotificationService();
      bugReportService = BugReportService();

      // Mark initialized early so the UI can render
      _isInitialized = true;
      _profileResolved = false;
      notifyListeners();

      // Load user if authenticated (non-blocking)
      _loadCurrentUserAndHandler().then((_) {
        _profileResolved = true;
        notifyListeners();
      }).catchError((e) {
        debugPrint('[AppProvider] Error loading user after init: $e');
        _profileResolved = true; // avoid blocking navigation on error
        notifyListeners();
      });

      // Listen to auth changes
      SupabaseConfig.auth.onAuthStateChange.listen((data) async {
        try {
          final user = data.session?.user;
          if (user == null) {
            await _missionSubscription?.cancel();
            _missionSubscription = null;
            await _rewardSubscription?.cancel();
            _rewardSubscription = null;
            _availableRewardMinutes = 0;
            _refreshTimer?.cancel();
            _refreshTimer = null;
            _currentUser = null;
            _currentHandler = null;
            _missions = [];
            _profileResolved = true; // nothing to resolve when signed out
            notifyListeners();
            return;
          }
          _profileResolved = false; // will resolve now
          notifyListeners();
          await _loadCurrentUserAndHandler();
          _profileResolved = true;
          notifyListeners();
        } catch (e) {
          debugPrint('[AppProvider] Auth state change error: $e');
        }
      });
    } catch (e) {
      debugPrint('[AppProvider] Initialization error: $e');
      // Still mark as initialized to prevent infinite loading
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Load current user and their handler
  Future<void> _loadCurrentUserAndHandler() async {
    if (SupabaseConfig.auth.currentUser == null) return;

    try {
      _currentUser = await userService.getCurrentUser();

      if (_currentUser != null) {
        // Get handler (synchronous - no async needed)
        _currentHandler =
            handlerService.getHandlerById(_currentUser!.selectedHandlerId);

        // Fallback to default handler if not found
        if (_currentHandler == null) {
          _currentHandler = handlerService.getDefaultHandler();
          debugPrint(
              '[AppProvider] Handler "${_currentUser!.selectedHandlerId}" not found, using default: ${_currentHandler!.id}');

          // Update the local user object with the default handler
          // so we don't get stuck in a loop
          _currentUser =
              _currentUser!.copyWith(selectedHandlerId: _currentHandler!.id);

          // Try to persist this to the database (fire and forget - don't block)
          userService.updateUser(_currentUser!).catchError((e) {
            debugPrint('[AppProvider] Failed to persist handler fix: $e');
          });
        }

        // Load missions (don't let this block initialization either)
        loadMissions().catchError((e) {
          debugPrint('[AppProvider] Failed to load missions: $e');
        });
        _subscribeToMissions();
        _subscribeToRewards();
        _startRefreshFallback();
        ScreenTimeService()
            .registerCurrentDevice(role: _currentUser!.accountRole.name)
            .catchError((e) => debugPrint('[Device] Registration failed: $e'));
      }
    } catch (e) {
      debugPrint('[AppProvider] Error loading user/handler: $e');
      // Ensure we still have a default handler even on error
      _currentHandler ??= handlerService.getDefaultHandler();
    }
  }

  Future<void> completeOnboarding({
    required String codename,
    required String handlerId,
    required String lifeGoals,
    required AccountRole accountRole,
  }) async {
    try {
      final supaUser = SupabaseConfig.auth.currentUser;
      if (supaUser == null) {
        throw Exception(
            'No authenticated user. Please sign in before creating a profile.');
      }

      final authEmail = supaUser.email ?? '';
      _currentUser = await userService.createUser(
        codename: codename,
        email: authEmail,
        selectedHandlerId: handlerId,
        lifeGoals: lifeGoals,
        accountRole: accountRole,
      );

      // Get handler (synchronous)
      _currentHandler = handlerService.getHandlerById(handlerId) ??
          handlerService.getDefaultHandler();

      notifyListeners();
    } catch (e) {
      debugPrint('[AppProvider] Onboarding error: $e');
      rethrow;
    }
  }

  Future<void> loadMissions() async {
    if (_currentUser == null) return;
    try {
      final fetchedMissions = await missionService.getVisibleMissions();

      _missions = fetchedMissions;
      _missions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e) {
      debugPrint('[AppProvider] Error loading missions: $e');
    }
  }

  void _subscribeToMissions() {
    _missionSubscription?.cancel();
    _missionSubscription = missionService.getVisibleMissionsStream().listen(
      (missions) {
        _missions = missions;
        notifyListeners();
      },
      onError: (Object error) {
        debugPrint('[AppProvider] Mission stream error: $error');
      },
    );
  }

  void _subscribeToRewards() {
    _rewardSubscription?.cancel();
    _rewardSubscription = RewardService().watchAvailableMinutes().listen(
      (minutes) {
        _availableRewardMinutes = minutes;
        notifyListeners();
      },
      onError: (Object error) {
        debugPrint('[AppProvider] Reward stream error: $error');
      },
    );
  }

  void _startRefreshFallback() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (_currentUser == null) return;
      await loadMissions();
      try {
        final minutes = await RewardService().getAvailableMinutes();
        if (_availableRewardMinutes != minutes) {
          _availableRewardMinutes = minutes;
          notifyListeners();
        }
      } catch (error) {
        debugPrint('[AppProvider] Reward refresh failed: $error');
      }
    });
  }

  Future<void> refreshUser() async {
    if (_currentUser == null) return;
    try {
      _currentUser = await userService.getUserById(_currentUser!.id);
      notifyListeners();
    } catch (e) {
      debugPrint('[AppProvider] Error refreshing user: $e');
    }
  }

  Future<void> reloadProfile() async {
    _profileResolved = false;
    notifyListeners();
    await _loadCurrentUserAndHandler();
    _profileResolved = true;
    notifyListeners();
  }

  Future<void> updateHandler(String handlerId) async {
    if (_currentUser == null) return;
    try {
      await userService
          .updateUser(_currentUser!.copyWith(selectedHandlerId: handlerId));
      _currentUser = await userService.getUserById(_currentUser!.id);
      _currentHandler = handlerService.getHandlerById(handlerId) ??
          handlerService.getDefaultHandler();
      notifyListeners();
    } catch (e) {
      debugPrint('[AppProvider] Error updating handler: $e');
    }
  }

  Future<void> addMission(Mission mission) async {
    _missions.insert(0, mission);
    notifyListeners();
  }

  Future<void> updateMission(Mission mission) async {
    final index = _missions.indexWhere((m) => m.id == mission.id);
    if (index != -1) {
      _missions[index] = mission;
      notifyListeners();
    }
  }

  Future<void> approveMission(String missionId) async {
    final mission = await missionService.approveFamilyQuest(missionId);
    await updateMission(mission);
  }

  Future<void> signOut() async {
    try {
      // Delete FCM token before signing out (silently fail if push notifications aren't available)
      try {
        await PushNotificationService().deleteToken();
      } catch (e) {
        debugPrint(
            '[AppProvider] Failed to delete FCM token (non-blocking): $e');
      }

      await _missionSubscription?.cancel();
      _missionSubscription = null;
      await _rewardSubscription?.cancel();
      _rewardSubscription = null;
      _refreshTimer?.cancel();
      _refreshTimer = null;
      await SupabaseConfig.auth.signOut();
      _currentUser = null;
      _currentHandler = null;
      _missions = [];
      _availableRewardMinutes = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('[AppProvider] Sign out error: $e');
      rethrow;
    }
  }
}
