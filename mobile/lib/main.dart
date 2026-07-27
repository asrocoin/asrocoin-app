import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://duddadnznisciylzmixf.supabase.co';
const supabasePublishableKey = 'sb_publishable_N-lLeJ7n0olf3A56VaEdOg_gvHJe0Tc';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabasePublishableKey,
  );
  runApp(const AsroCoinApp());
}

final supabase = Supabase.instance.client;

class AsroCoinApp extends StatelessWidget {
  const AsroCoinApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1677FF);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ASROCOIN',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF07111F),
        cardTheme: const CardThemeData(
          color: Color(0xFF101D2E),
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF101D2E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF0A1626),
          indicatorColor: Color(0xFF153D70),
        ),
      ),
      home: const MainShell(),
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
  Future<List<CoinData>> load() async {
    final coinRows = List<Map<String, dynamic>>.from(
      await supabase
          .from('coins')
          .select('id,symbol,name,binance_symbol,category,sort_order')
          .eq('is_active', true)
          .order('category')
          .order('sort_order'),
    );
    final sentimentRows = List<Map<String, dynamic>>.from(
      await supabase.from('coin_sentiment').select(),
    );
    final sentimentById = {
      for (final row in sentimentRows) row['coin_id'] as int: row,
    };

    final symbols = coinRows.map((row) => row['binance_symbol']).join(',');
    final uri = Uri.https(
      'api.binance.com',
      '/api/v3/ticker/24hr',
      {'symbols': jsonEncode(symbols.split(','))},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Binance fiyatları alınamadı (${response.statusCode})');
    }
    final tickerRows =
        List<Map<String, dynamic>>.from(jsonDecode(response.body));
    final tickerBySymbol = {
      for (final row in tickerRows) row['symbol'] as String: row,
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
    if (user == null) throw const AuthException('Önce giriş yapmalısın.');
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.candlestick_chart_outlined),
            selectedIcon: Icon(Icons.candlestick_chart),
            label: 'Piyasa',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Lig',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
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
        error = 'Veriler yenilenemedi. İnternet bağlantını kontrol et.';
      });
    }
  }

  Future<void> _vote(CoinData coin, bool up) async {
    if (supabase.auth.currentUser == null) {
      _message('Tahmin yapmak için Profil bölümünden giriş yap.');
      return;
    }
    if (votes.containsKey(coin.id)) {
      _message('Bu coin için aktif 24 saatlik tahminin zaten var.');
      return;
    }
    try {
      await service.vote(coin, up);
      if (!mounted) return;
      setState(() => votes[coin.id] = up);
      _message(
        '${coin.symbol} tahminin kaydedildi: ${up ? 'YUKARI' : 'AŞAĞI'}',
      );
      await _refresh();
    } catch (_) {
      _message('Tahmin kaydedilemedi. Biraz sonra tekrar dene.');
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
    final visible = coins.where((coin) => coin.major == majors).toList();
    final allVotes = coins.fold<int>(0, (sum, coin) => sum + coin.totalVotes);
    final marketBullish = allVotes == 0
        ? 50.0
        : coins.fold<double>(
              0,
              (sum, coin) => sum + coin.bullish * coin.totalVotes,
            ) /
            allVotes;

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
                _MarketPulse(value: marketBullish, votes: allVotes),
                const SizedBox(height: 18),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Majör Coinler'),
                      icon: Icon(Icons.stars),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Altcoinler'),
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
                      majors ? 'MAJÖR COİNLER' : 'ALTCOİNLER',
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
                    const Text(
                      '7/24 CANLI',
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
        const Expanded(
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
                'Kriptonun yönünü tahmin et',
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

class _MarketPulse extends StatelessWidget {
  const _MarketPulse({required this.value, required this.votes});

  final double value;
  final int votes;

  @override
  Widget build(BuildContext context) {
    final up = value >= 50;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173F73), Color(0xFF102B50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF28558A)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PİYASA SENTİMENTİ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFAFC9E8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '%${value.toStringAsFixed(0)} ${up ? 'YUKARI' : 'AŞAĞI'}',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  votes == 0 ? 'İlk tahmini sen yap' : '$votes aktif tahmin',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFC7D6E8)),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 82,
            height: 82,
            child: CircularProgressIndicator(
              value: value / 100,
              strokeWidth: 8,
              color: up ? const Color(0xFF24D18F) : const Color(0xFFFF5A6B),
              backgroundColor: const Color(0xFF263D59),
            ),
          ),
        ],
      ),
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

  String get priceText {
    if (coin.price >= 1000) return '\$${coin.price.toStringAsFixed(0)}';
    if (coin.price >= 1) return '\$${coin.price.toStringAsFixed(2)}';
    return '\$${coin.price.toStringAsFixed(4)}';
  }

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
                      priceText,
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
                  '%${coin.bullish.toStringAsFixed(0)} yukarı',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF8EA4BD)),
                ),
                const Spacer(),
                Text(
                  '${coin.totalVotes} aktif tahmin',
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
                    label: Text(vote == true ? 'SEÇİLDİ' : 'YUKARI'),
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
                    label: Text(vote == false ? 'SEÇİLDİ' : 'AŞAĞI'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF9C3345),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Tahmin, verildiği andan 24 saat sonra sonuçlanır.',
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
    return Scaffold(
      appBar: AppBar(title: const Text('ASROCOIN LİGİ')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const Center(
              child: Text('Lig henüz boş. İlk puanı sen kazan!'),
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
                final accuracy = total == 0 ? 0 : correct * 100 / total;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(
                      '${row['display_name'] ?? row['username'] ?? 'ASROCU'}',
                    ),
                    subtitle: Text(
                      '$correct/$total doğru • %${accuracy.toStringAsFixed(0)} başarı',
                    ),
                    trailing: Text(
                      '${row['points'] ?? 0} P',
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
        message = 'Kayıt tamamlandı. E-postandaki onay bağlantısına dokun.';
      } else {
        await supabase.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
        message = 'Giriş başarılı.';
      }
      widget.onAuthChanged();
    } on AuthException catch (e) {
      message = e.message;
    } catch (_) {
      message = 'İşlem tamamlanamadı. Tekrar dene.';
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
    final user = supabase.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('PROFİL')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.account_circle, size: 90, color: Color(0xFF1677FF)),
          const SizedBox(height: 18),
          if (user != null) ...[
            Text(
              user.email ?? 'ASROCOIN kullanıcısı',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tahminlerin 24 saat sonra otomatik sonuçlanır.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8EA4BD)),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Çıkış yap'),
            ),
          ] else ...[
            Text(
              register ? 'Hesap oluştur' : 'Giriş yap',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre',
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
                    : Text(register ? 'KAYIT OL' : 'GİRİŞ YAP'),
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
                    ? 'Zaten hesabın var mı? Giriş yap'
                    : 'Hesabın yok mu? Kayıt ol',
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
