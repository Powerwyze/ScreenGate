import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screengate/models/user.dart';
import 'package:screengate/models/handler.dart';
import 'package:screengate/models/mission.dart';
import 'package:screengate/services/user_service.dart';
import 'package:screengate/services/handler_service.dart';
import 'package:screengate/services/mission_service.dart';
import 'package:screengate/services/achievement_service.dart';
import 'package:screengate/services/friend_service.dart';
import 'package:screengate/services/message_service.dart';
import 'package:screengate/services/social_service.dart';
import 'package:screengate/services/chat_service.dart';
import 'package:screengate/services/ai_service.dart';
import 'package:screengate/services/notification_service.dart';
import 'package:screengate/services/bug_report_service.dart';
import 'package:screengate/services/push_notification_service.dart';
import 'package:screengate/services/screen_time_service.dart';
import 'package:screengate/services/reward_service.dart';
import 'package:screengate/services/family_service.dart';
import 'package:screengate/supabase/supabase_config.dart';

class AppProvider extends ChangeNotifier with WidgetsBindingObserver {
  int _currentTab = 0;
  UsageMode _preferredUsageMode = UsageMode.family;
  UsageMode get preferredUsageMode => _preferredUsageMode;
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
  late final SocialService socialService;
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
  int _availableRewardSeconds = 0;
  Timer? _refreshTimer;
  bool _refreshInProgress = false;
  int _missionRequest = 0;

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
  int get availableRewardSeconds => _availableRewardSeconds;

  void setPairingChild(bool value) {
    _isPairingChild = value;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final preferences = await SharedPreferences.getInstance();
      _preferredUsageMode = UsageMode.fromJson(
        preferences.getString('screengate_usage_mode'),
      );
      // Initialize storage first

      // Initialize all services (synchronous - no risk of blocking)
      userService = UserService();
      missionService = MissionService();
      handlerService = HandlerService();
      achievementService = AchievementService();
      friendService = FriendService();
      notificationService = NotificationService();
      messageService = MessageService(notificationService: notificationService);
      socialService = SocialService(
        friendService: friendService,
        notificationService: notificationService,
      );
      chatService = ChatService();
      aiService = AIService();
      bugReportService = BugReportService();
      WidgetsBinding.instance.addObserver(this);

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
            _availableRewardSeconds = 0;
            _refreshTimer?.cancel();
            _refreshTimer = null;
            _currentUser = null;
            UserService.activeProfileId = null;
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
      _currentUser = await userService.getCurrentUser(_preferredUsageMode);

      if (_currentUser != null) {
        UserService.activeProfileId = _currentUser!.id;
        if (_currentUser!.accountRole == AccountRole.child) {
          await FamilyService().rememberChild(RememberedChild(
            id: _currentUser!.id,
            name: _currentUser!.codename,
          ));
        }
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
    UsageMode usageMode = UsageMode.family,
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
        usageMode: usageMode,
      );
      _preferredUsageMode = usageMode;
      UserService.activeProfileId = _currentUser!.id;

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
    final request = ++_missionRequest;
    try {
      final fetchedMissions = await missionService.getVisibleMissions();
      if (request != _missionRequest || _currentUser == null) return;
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
        _applyRewardMinutes(minutes);
      },
      onError: (Object error) {
        debugPrint('[AppProvider] Reward stream error: $error');
      },
    );
  }

  Future<void> _applyRewardMinutes(int awardedMinutes) async {
    var visibleMinutes = awardedMinutes;
    if (_currentUser != null && !kIsWeb) {
      try {
        final screenTime = ScreenTimeService();
        await screenTime.syncAllowance(
          awardedMinutes: awardedMinutes,
          soloMode: _currentUser!.usageMode == UsageMode.solo,
        );
        final configuration = await screenTime.getConfiguration();
        _availableRewardSeconds = configuration.remainingSeconds;
        visibleMinutes = (configuration.remainingSeconds / 60).ceil();
        await screenTime.registerCurrentDevice(
          role: _currentUser!.accountRole.name,
        );
      } catch (error) {
        debugPrint('[Screen Time] Allowance sync failed: $error');
      }
    }
    if (_availableRewardMinutes != visibleMinutes) {
      _availableRewardMinutes = visibleMinutes;
      notifyListeners();
    } else if (_currentUser != null && !kIsWeb) {
      notifyListeners();
    }
  }

  void _startRefreshFallback() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => refreshFamilyData(),
    );
  }

  Future<void> refreshFamilyData() async {
    if (_currentUser == null || _refreshInProgress) return;
    _refreshInProgress = true;
    try {
      await loadMissions();
      final minutes = await RewardService().getAvailableMinutes();
      await _applyRewardMinutes(minutes);
    } catch (error) {
      debugPrint('[AppProvider] Family refresh failed: $error');
    } finally {
      _refreshInProgress = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshFamilyData();
    }
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

  Future<void> setPreferredUsageMode(UsageMode mode,
      {bool reload = true}) async {
    _preferredUsageMode = mode;
    _currentTab = 0;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('screengate_usage_mode', mode.name);
    await _missionSubscription?.cancel();
    _missionSubscription = null;
    await _rewardSubscription?.cancel();
    _rewardSubscription = null;
    _currentUser = null;
    _currentHandler = null;
    _missions = [];
    UserService.activeProfileId = null;
    notifyListeners();
    if (reload && SupabaseConfig.auth.currentUser != null) {
      await reloadProfile();
    }
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
    await refreshFamilyData();
  }

  Future<void> signOut() async {
    try {
      if (_currentUser?.accountRole == AccountRole.child) {
        await FamilyService().rememberChild(RememberedChild(
          id: _currentUser!.id,
          name: _currentUser!.codename,
        ));
      }
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
      UserService.activeProfileId = null;
      _currentHandler = null;
      _missions = [];
      _availableRewardMinutes = 0;
      _availableRewardSeconds = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('[AppProvider] Sign out error: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _missionSubscription?.cancel();
    _rewardSubscription?.cancel();
    super.dispose();
  }
}
