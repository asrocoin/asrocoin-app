import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/generated/app_localizations.dart';

const supabaseUrl = 'https://duddadnznisciylzmixf.supabase.co';
const supabasePublishableKey = 'sb_publishable_N-lLeJ7n0olf3A56VaEdOg_gvHJe0Tc';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  appLocaleController = LocaleController(preferences);
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  runApp(const AsroCoinApp());
}

final supabase = Supabase.instance.client;
late final LocaleController appLocaleController;

class LocaleController extends ValueNotifier<Locale?> {
  LocaleController(this.preferences) : super(_read(preferences));
  final SharedPreferences preferences;
  static const key = 'preferred_locale';
  static Locale? _read(SharedPreferences p) {
    final code = p.getString(key);
    if (code == null || code.isEmpty) return null;
    return code == 'pt_BR' ? const Locale('pt', 'BR') : Locale(code);
  }
  Future<void> setLocaleCode(String? code) async {
    if (code == null) {
      await preferences.remove(key);
      value = null;
    } else {
      await preferences.setString(key, code);
      value = code == 'pt_BR' ? const Locale('pt', 'BR') : Locale(code);
    }
  }
  String? get selectedCode {
    final locale = value;
    if (locale == null) return null;
    return locale.countryCode == null ? locale.languageCode : '${locale.languageCode}_${locale.countryCode}';
  }
}

extension LocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get localeName => Localizations.localeOf(this).toString();
}
String formatPercent(BuildContext context, double value) =>
    NumberFormat.percentPattern(context.localeName).format(value / 100);
String formatPrice(BuildContext context, double value) {
  final digits = value >= 1000 ? 0 : (value >= 1 ? 2 : 4);
  return NumberFormat.currency(locale: context.localeName, symbol: r'$', decimalDigits: digits).format(value);
}

class AsroCoinApp extends StatelessWidget {
  const AsroCoinApp({super.key});
  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1677FF);
    return ValueListenableBuilder<Locale?>(
      valueListenable: appLocaleController,
      builder: (context, locale, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (_) => 'ASROCOIN',
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
          scaffoldBackgroundColor: const Color(0xFF07111F),
          cardTheme: const CardThemeData(color: Color(0xFF101D2E), elevation: 0, margin: EdgeInsets.zero),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF101D2E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
          navigationBarTheme: const NavigationBarThemeData(backgroundColor: Color(0xFF0A1626), indicatorColor: Color(0xFF153D70)),
        ),
        home: const MainShell(),
      ),
    );
  }
}

class CoinData {
  const CoinData({
    required this.id,
    required this.symbol,
    required this.name,
    required this.binanceSymbol,
    required this.category,
    required this.sortOrder,
    required this.price,
    required this.change,
    required this.bullish,
    required this.totalVotes,
  });

  final int id;
  final String symbol;
  final String name;
  final String binanceSymbol;
  final String category;
  final int sortOrder;
  final double price;
  final double change;
  final double bullish;
  final int totalVotes;

  bool get major => category == 'major';

  CoinData copyWith({
    double? price,
    double? change,
    double? bullish,
    int? totalVotes,
  }) =>
      CoinData(
        id: id,
        symbol: symbol,
        name: name,
        binanceSymbol: binanceSymbol,
        category: category,
        sortOrder: sortOrder,
        price: price ?? this.price,
        change: change ?? this.change,
        bullish: bullish ?? this.bullish,
        totalVotes: totalVotes ?? this.totalVotes,
      );
}

class MarketService {
  static const fallbackCoins = <Map<String, dynamic>>[
    {'id': 1, 'symbol': 'BTC', 'name': 'Bitcoin', 'binance_symbol': 'BTCUSDT', 'category': 'major', 'sort_order': 1},
    {'id': 2, 'symbol': 'ETH', 'name': 'Ethereum', 'binance_symbol': 'ETHUSDT', 'category': 'major', 'sort_order': 2},
    {'id': 3, 'symbol': 'BNB', 'name': 'BNB', 'binance_symbol': 'BNBUSDT', 'category': 'major', 'sort_order': 3},
    {'id': 4, 'symbol': 'SOL', 'name': 'Solana', 'binance_symbol': 'SOLUSDT', 'category': 'major', 'sort_order': 4},
    {'id': 5, 'symbol': 'XRP', 'name': 'XRP', 'binance_symbol': 'XRPUSDT', 'category': 'major', 'sort_order': 5},
    {'id': 6, 'symbol': 'DOGE', 'name': 'Dogecoin', 'binance_symbol': 'DOGEUSDT', 'category': 'major', 'sort_order': 6},
    {'id': 7, 'symbol': 'ADA', 'name': 'Cardano', 'binance_symbol': 'ADAUSDT', 'category': 'alt', 'sort_order': 1},
    {'id': 8, 'symbol': 'AVAX', 'name': 'Avalanche', 'binance_symbol': 'AVAXUSDT', 'category': 'alt', 'sort_order': 2},
    {'id': 9, 'symbol': 'LINK', 'name': 'Chainlink', 'binance_symbol': 'LINKUSDT', 'category': 'alt', 'sort_order': 3},
    {'id': 10, 'symbol': 'DOT', 'name': 'Polkadot', 'binance_symbol': 'DOTUSDT', 'category': 'alt', 'sort_order': 4},
    {'id': 11, 'symbol': 'LTC', 'name': 'Litecoin', 'binance_symbol': 'LTCUSDT', 'category': 'alt', 'sort_order': 5},
    {'id': 12, 'symbol': 'SUI', 'name': 'Sui', 'binance_symbol': 'SUIUSDT', 'category': 'alt', 'sort_order': 6},
  ];

  Future<List<CoinData>> load() async {
    final coinRows = await _loadCoinCatalog();
    final results = await Future.wait([
      _loadBinanceTickers(
        coinRows.map((row) => row['binance_symbol'] as String).toList(),
      ),
      _loadSentiment(),
    ]);
    final tickerRows = results[0] as List<Map<String, dynamic>>;
    final sentimentRows = results[1] as List<Map<String, dynamic>>;
    final tickerBySymbol = {
      for (final row in tickerRows) row['symbol'] as String: row,
    };
    final sentimentById = {
      for (final row in sentimentRows) row['coin_id'] as int: row,
    };

    return coinRows.map((row) {
      final id = row['id'] as int;
      final ticker = tickerBySymbol[row['binance_symbol']] ?? const {};
      final sentiment = sentimentById[id] ?? const {};
      return CoinData(
        id: id,
        symbol: row['symbol'] as String,
        name: row['name'] as String,
        binanceSymbol: row['binance_symbol'] as String,
        category: row['category'] as String,
        sortOrder: row['sort_order'] as int,
        price: double.tryParse('${ticker['lastPrice'] ?? 0}') ?? 0,
        change: double.tryParse('${ticker['priceChangePercent'] ?? 0}') ?? 0,
        bullish: double.tryParse('${sentiment['up_percentage'] ?? 50}') ?? 50,
        totalVotes: int.tryParse('${sentiment['total_votes'] ?? 0}') ?? 0,
      );
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _loadCoinCatalog() async {
    try {
      final rows = List<Map<String, dynamic>>.from(
        await supabase
            .from('coins')
            .select('id,symbol,name,binance_symbol,category,sort_order')
            .eq('is_active', true)
            .order('category')
            .order('sort_order'),
      );
      if (rows.isNotEmpty) return rows;
    } catch (error) {
      debugPrint('Supabase coin catalog unavailable: $error');
    }
    return fallbackCoins.map(Map<String, dynamic>.from).toList();
  }

  Future<List<Map<String, dynamic>>> _loadSentiment() async {
    try {
      return List<Map<String, dynamic>>.from(
        await supabase.from('coin_sentiment').select(),
      );
    } catch (error) {
      debugPrint('Sentiment unavailable: $error');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadBinanceTickers(
    List<String> symbols,
  ) async {
    const hosts = [
      'api.binance.com',
      'api1.binance.com',
      'api2.binance.com',
      'api3.binance.com',
    ];
    Object? lastError;
    for (final host in hosts) {
      try {
        final response = await http
            .get(
              Uri.https(
                host,
                '/api/v3/ticker/24hr',
                {'symbols': jsonEncode(symbols)},
              ),
              headers: const {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) {
          lastError = 'HTTP ${response.statusCode} ($host)';
          continue;
        }
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
        lastError = 'Unexpected response from $host';
      } catch (error) {
        lastError = error;
      }
    }
    throw Exception('Binance prices unavailable: $lastError');
  }

  Future<Map<int, bool>> activeVotes() async {
    final user = supabase.auth.currentUser;
    if (user == null) return {};
    final rows = List<Map<String, dynamic>>.from(
      await supabase
          .from('predictions')
          .select('coin_id,direction')
          .eq('user_id', user.id)
          .eq('resolved', false),
    );
    return {
      for (final row in rows) row['coin_id'] as int: row['direction'] == 'up',
    };
  }

  Future<void> vote(CoinData coin, bool up) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw const AuthException('Authentication required.');
    await supabase.from('predictions').insert({
      'user_id': user.id,
      'coin_id': coin.id,
      'direction': up ? 'up' : 'down',
      'entry_price': coin.price,
    });
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  int refreshToken = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = [
      MarketPage(key: ValueKey(refreshToken)),
      const LeaguePage(),
      ProfilePage(onAuthChanged: () => setState(() => refreshToken++)),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.candlestick_chart_outlined),
            selectedIcon: Icon(Icons.candlestick_chart),
            label: l10n.navMarket,
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: l10n.navLeague,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  final service = MarketService();
  List<CoinData> coins = [];
  Map<int, bool> votes = {};
  Timer? timer;
  bool majors = true;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _refresh();
    timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final results =
          await Future.wait([service.load(), service.activeVotes()]);
      if (!mounted) return;
      setState(() {
        coins = results[0] as List<CoinData>;
        votes = results[1] as Map<int, bool>;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = context.l10n.dataRefreshError;
      });
    }
  }

  Future<void> _vote(CoinData coin, bool up) async {
    if (supabase.auth.currentUser == null) {
      _message(context.l10n.loginToPredict);
      return;
    }
    if (votes.containsKey(coin.id)) {
      _message(context.l10n.activePredictionExists);
      return;
    }
    try {
      await service.vote(coin, up);
      if (!mounted) return;
      setState(() => votes[coin.id] = up);
      final direction = up ? context.l10n.directionUp : context.l10n.directionDown;
      _message(context.l10n.predictionSaved(coin.symbol, direction));
      await _refresh();
    } catch (_) {
      _message(context.l10n.predictionSaveError);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visible = coins.where((coin) => coin.major == majors).toList();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            sliver: SliverList.list(
              children: [
                const _Header(),
                const SizedBox(height: 18),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(l10n.majorCoins),
                      icon: Icon(Icons.stars),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(l10n.altcoins),
                      icon: Icon(Icons.bubble_chart),
                    ),
                  ],
                  selected: {majors},
                  onSelectionChanged: (value) =>
                      setState(() => majors = value.first),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      majors ? l10n.majorCoins.toUpperCase() : l10n.altcoins.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.circle,
                      size: 9,
                      color: Color(0xFF24D18F),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.liveMarket,
                      style: TextStyle(fontSize: 11, color: Color(0xFF8EA4BD)),
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Colors.orange)),
                ],
              ],
            ),
          ),
          if (loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => CoinCard(
                  coin: visible[i],
                  vote: votes[visible[i].id],
                  onVote: _vote,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF1677FF),
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: Alignment.center,
          child: const Text(
            'A',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ASROCOIN',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              Text(
                l10n.tagline,
                style: TextStyle(fontSize: 12, color: Color(0xFF8EA4BD)),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class CoinCard extends StatelessWidget {
  const CoinCard({
    super.key,
    required this.coin,
    required this.vote,
    required this.onVote,
  });

  final CoinData coin;
  final bool? vote;
  final void Function(CoinData coin, bool up) onVote;

  String priceText(BuildContext context) => formatPrice(context, coin.price);

  @override
  Widget build(BuildContext context) {
    final positive = coin.change >= 0;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF17365C),
                  child: Text(
                    coin.symbol.substring(0, 1),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coin.symbol,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        coin.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8EA4BD),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceText(context),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${positive ? '+' : ''}${coin.change.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: positive
                            ? const Color(0xFF24D18F)
                            : const Color(0xFFFF5A6B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  flex: coin.bullish.round().clamp(1, 99).toInt(),
                  child: Container(
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF24D18F),
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: (100 - coin.bullish.round()).clamp(1, 99).toInt(),
                  child: Container(
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5A6B),
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  context.l10n.sentimentUp(formatPercent(context, coin.bullish)),
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF8EA4BD)),
                ),
                const Spacer(),
                Text(
                  context.l10n.activePredictions(coin.totalVotes),
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF8EA4BD)),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: vote == null ? () => onVote(coin, true) : null,
                    icon: const Icon(Icons.trending_up),
                    label: Text(vote == true ? context.l10n.selected : context.l10n.directionUp),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF147A5A),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: vote == null ? () => onVote(coin, false) : null,
                    icon: const Icon(Icons.trending_down),
                    label: Text(vote == false ? context.l10n.selected : context.l10n.directionDown),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF9C3345),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.predictionResolutionInfo,
              style: TextStyle(fontSize: 10, color: Color(0xFF6F849E)),
            ),
          ],
        ),
      ),
    );
  }
}

class LeaguePage extends StatefulWidget {
  const LeaguePage({super.key});

  @override
  State<LeaguePage> createState() => _LeaguePageState();
}

class _LeaguePageState extends State<LeaguePage> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async =>
      List<Map<String, dynamic>>.from(
        await supabase
            .from('profiles')
            .select(
              'id,username,display_name,points,correct_predictions,total_predictions',
            )
            .order('points', ascending: false)
            .limit(100),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.leagueTitle)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return Center(
              child: Text(l10n.leagueEmpty, textAlign: TextAlign.center),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              final next = await _load();
              if (mounted) setState(() => future = Future.value(next));
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final row = rows[index];
                final total = row['total_predictions'] as int? ?? 0;
                final correct = row['correct_predictions'] as int? ?? 0;
                final accuracy = total == 0 ? 0.0 : correct * 100.0 / total;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(
                      '${row['display_name'] ?? row['username'] ?? 'ASROCU'}',
                    ),
                    subtitle: Text(
                      l10n.accuracySummary(correct, total, formatPercent(context, accuracy)),
                    ),
                    trailing: Text(
                      l10n.points(NumberFormat.decimalPattern(context.localeName).format(row['points'] ?? 0)),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.onAuthChanged});

  final VoidCallback onAuthChanged;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;
  String? message;
  StreamSubscription<AuthState>? authSubscription;

  @override
  void initState() {
    super.initState();
    authSubscription = supabase.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (register) {
        await supabase.auth.signUp(
          email: email.text.trim(),
          password: password.text,
        );
        message = context.l10n.registrationComplete;
      } else {
        await supabase.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
        message = context.l10n.loginSuccess;
      }
      widget.onAuthChanged();
    } on AuthException catch (e) {
      message = e.message;
    } catch (_) {
      message = context.l10n.operationFailed;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    widget.onAuthChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = supabase.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.account_circle, size: 90, color: Color(0xFF1677FF)),
          const SizedBox(height: 18),
          Text(l10n.settings, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ValueListenableBuilder<Locale?>(
            valueListenable: appLocaleController,
            builder: (context, _, __) => DropdownButtonFormField<String?>(
              key: ValueKey(appLocaleController.selectedCode),
              initialValue: appLocaleController.selectedCode,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.language, prefixIcon: const Icon(Icons.language)),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.systemLanguage, overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'en', child: Text(l10n.english)),
                DropdownMenuItem(value: 'tr', child: Text(l10n.turkish)),
                DropdownMenuItem(value: 'es', child: Text(l10n.spanish)),
                DropdownMenuItem(value: 'pt_BR', child: Text(l10n.brazilianPortuguese)),
              ],
              onChanged: appLocaleController.setLocaleCode,
            ),
          ),
          const SizedBox(height: 28),
          if (user != null) ...[
            Text(
              user.email ?? l10n.userFallback,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.predictionsResolveInfo,
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8EA4BD)),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: Text(l10n.logout),
            ),
          ] else ...[
            Text(
              register ? l10n.createAccount : l10n.login,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.email,
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.password,
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(register ? l10n.register : l10n.loginButton),
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                        register = !register;
                        message = null;
                      }),
              child: Text(
                register
                    ? l10n.alreadyHaveAccount
                    : l10n.noAccount,
              ),
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(message!, textAlign: TextAlign.center),
              ),
          ],
        ],
      ),
    );
  }
}
