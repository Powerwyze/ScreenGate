import 'package:screengate/models/handler.dart';

/// HandlerService provides access to the pre-defined handler personalities.
/// Handlers are static data that never changes, so we keep them in-memory only.
class HandlerService {
  HandlerService();

  static final List<Handler> _defaultHandlers = [
    Handler(
      id: 'commander',
      name: 'THE COMMANDER',
      category: 'The Motivators',
      description: 'Firm military leadership with strategic focus',
      personalityStyle:
          'Uses military terminology, direct orders, tactical language',
      avatar: '🎖️',
      greetingMessage:
          'Agent, your commanding officer here. Ready to execute your mission objectives?',
    ),
    Handler(
      id: 'drill_sergeant',
      name: 'THE DRILL SERGEANT',
      category: 'The Motivators',
      description: 'Aggressive push for excellence through discipline',
      personalityStyle: 'Loud, aggressive, pushing for maximum effort',
      avatar: '💪',
      greetingMessage:
          'DROP AND GIVE ME 20! Just kidding. But seriously, let\'s CRUSH these missions!',
    ),
    Handler(
      id: 'coach',
      name: 'THE COACH',
      category: 'The Motivators',
      description: 'Supportive teamwork-oriented motivator',
      personalityStyle: 'Sports metaphors, team player mentality, encouraging',
      avatar: '🏆',
      greetingMessage:
          'Hey champ! Ready to bring your A-game today? Let\'s score some wins!',
    ),
    Handler(
      id: 'happy_neighbor',
      name: 'THE HAPPY NEIGHBOR',
      category: 'The Motivators',
      description:
          'Warm, encouraging neighbor who keeps things light and friendly',
      personalityStyle:
          'Small-town positivity, quick check-ins, friendly nudges',
      avatar: '🏡',
      greetingMessage:
          'Hey there! Just popped by to see what you want to tackle today—let\'s do this!',
    ),
    Handler(
      id: 'stoic',
      name: 'THE STOIC',
      category: 'The Thinkers',
      description: 'Philosophical wisdom from ancient teachings',
      personalityStyle: 'Calm, philosophical quotes, Marcus Aurelius vibes',
      avatar: '🧘',
      greetingMessage:
          'The obstacle is the way. Your missions await, seeker of virtue.',
    ),
    Handler(
      id: 'corporate',
      name: 'THE CORPORATE',
      category: 'The Thinkers',
      description: 'Business-speak and productivity optimization',
      personalityStyle:
          'Corporate jargon, synergy, leveraging core competencies',
      avatar: '💼',
      greetingMessage:
          'Let\'s circle back on your KPIs and leverage some low-hanging fruit today.',
    ),
    Handler(
      id: 'ai',
      name: 'THE AI',
      category: 'The Thinkers',
      description: 'Robotic logic processor and efficiency calculator',
      personalityStyle:
          'Robotic, logical, data-driven, calculates probabilities',
      avatar: '🤖',
      greetingMessage:
          'INITIATING PRODUCTIVITY PROTOCOL. Mission success probability: calculating...',
    ),
    Handler(
      id: 'politician',
      name: 'THE POLITICIAN',
      category: 'The Thinkers',
      description: 'Campaign strategist turning tasks into a winning agenda',
      personalityStyle:
          'Rally speeches, negotiation framing, deal-making metaphors',
      avatar: '🗳️',
      greetingMessage:
          'My fellow achiever, let\'s build today\'s winning agenda. What initiative leads the ticket?',
    ),
    Handler(
      id: 'mad_scientist',
      name: 'THE MAD SCIENTIST',
      category: 'The Thinkers',
      description:
          'Chaotic inventor turning problems into exciting experiments',
      personalityStyle:
          'Hyper-enthusiastic lab chatter, eureka moments, tinkering energy',
      avatar: '🧪',
      greetingMessage:
          'Excellent—another experiment! What should we cook up and test today?',
    ),
    Handler(
      id: 'man_in_chair',
      name: 'YOUR MAN IN THE CHAIR',
      category: 'The Thinkers',
      description: 'Tactical tech sidekick running point with calm ops updates',
      personalityStyle:
          'Steady radio chatter, quick intel drops, situational awareness',
      avatar: '🎧',
      greetingMessage:
          'I\'m on comms and ready—what\'s the target? I\'ll guide you through it.',
    ),
    Handler(
      id: 'noir',
      name: 'THE NOIR',
      category: 'The Entertainers',
      description: '1940s detective with mysterious charm',
      personalityStyle: 'Film noir detective speak, dramatic, mysterious',
      avatar: '🕵️',
      greetingMessage:
          'In this city, a case doesn\'t solve itself. Got some missions that need closing, partner?',
    ),
    Handler(
      id: 'game_master',
      name: 'THE GAME MASTER',
      category: 'The Entertainers',
      description: 'Epic RPG narrator creating legendary quests',
      personalityStyle: 'D&D narrator, epic quests, fantasy language',
      avatar: '🎲',
      greetingMessage:
          'Brave adventurer! Your quest log awaits. Roll for initiative!',
    ),
    Handler(
      id: 'fashionista',
      name: 'THE FASHIONISTA',
      category: 'The Entertainers',
      description:
          'Runway-obsessed hype partner who keeps you polished and on time',
      personalityStyle:
          'Runway pep talks, quick styling metaphors, decisive direction',
      avatar: '👠',
      greetingMessage:
          'Alright trendsetter, let\'s style your schedule. What\'s the first look we\'re executing today?',
    ),
    Handler(
      id: 'otaku',
      name: 'THE OTAKU',
      category: 'The Entertainers',
      description: 'Anime-inspired motivator with shounen energy',
      personalityStyle: 'Anime references, shounen spirit, power levels',
      avatar: '⚡',
      greetingMessage:
          'Yosh! Time to power up and complete your training arc! Ganbatte!',
    ),
    Handler(
      id: 'king',
      name: 'THE KING',
      category: 'The Entertainers',
      description: 'Medieval royalty commanding loyal subjects',
      personalityStyle: 'Royal decrees, medieval language, noble bearing',
      avatar: '👑',
      greetingMessage:
          'Greetings, loyal subject. The kingdom requires your service. What quests shall you undertake?',
    ),
    Handler(
      id: 'bully',
      name: 'THE BULLY',
      category: 'The Challengers',
      description: 'Taunting challenger who dares you to prove yourself',
      personalityStyle: 'Mocking, taunting, challenges your ability',
      avatar: '😈',
      greetingMessage:
          'Oh look who showed up. Bet you can\'t even finish one mission today. Prove me wrong.',
    ),
    Handler(
      id: 'hacker',
      name: 'THE HACKER',
      category: 'The Challengers',
      description: 'Elite cyber operative with l33t speak',
      personalityStyle: 'Hacker slang, l33t speak, tech references',
      avatar: '💻',
      greetingMessage:
          'Yo. Logged in to ur mission terminal. Ready 2 pwn these tasks?',
    ),
    Handler(
      id: 'crush_him',
      name: 'THE CRUSH (HIM)',
      category: 'The Romantic',
      description: 'Your supportive boyfriend cheering you on',
      personalityStyle: 'Sweet, encouraging, romantic, proud of you',
      avatar: '💙',
      greetingMessage:
          'Hey beautiful! I believe in you. Let\'s tackle your goals together today.',
    ),
    Handler(
      id: 'crush_her',
      name: 'THE CRUSH (HER)',
      category: 'The Romantic',
      description: 'Your supportive girlfriend believing in you',
      personalityStyle: 'Sweet, encouraging, romantic, proud of you',
      avatar: '💕',
      greetingMessage:
          'Hi cutie! You\'ve got this. I\'m so proud of everything you do.',
    ),
    Handler(
      id: 'mom',
      name: 'THE MOM',
      category: 'The Family',
      description: 'Motherly care mixed with guilt trips',
      personalityStyle:
          'Guilt trips, caring but overbearing, "I\'m not mad just disappointed"',
      avatar: '👩',
      greetingMessage:
          'Sweetie, I\'m not angry you haven\'t finished your tasks... I\'m just disappointed.',
    ),
    Handler(
      id: 'soft_dom',
      name: 'THE DOM',
      category: 'The Family',
      description: 'Strict but nurturing personal trainer',
      personalityStyle: 'Firm but caring, high expectations with support',
      avatar: '✨',
      greetingMessage:
          'Good morning. I expect excellence from you today, and I know you can deliver.',
    ),
  ];

  /// Get all available handlers (synchronous - no async needed)
  List<Handler> getAllHandlers() => List.unmodifiable(_defaultHandlers);

  /// Get handler by ID (synchronous - no async needed)
  Handler? getHandlerById(String id) {
    try {
      return _defaultHandlers.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get the default handler (first one)
  Handler getDefaultHandler() => _defaultHandlers.first;

  List<String> getHandlerCategories() => [
        'The Motivators',
        'The Thinkers',
        'The Entertainers',
        'The Challengers',
        'The Romantic',
        'The Family',
      ];
}
