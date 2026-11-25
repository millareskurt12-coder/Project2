import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database.dart';
import 'database_factory.dart';
import 'image_storage.dart';

const primary = Color(0xFF2563EB);
const canvas = Color(0xFFF9FAFB);
const categories = [
  'Electronics',
  'Wallet',
  'Keys',
  'ID Card',
  'Books',
  'Clothing',
  'Accessories',
  'Other',
];
final dateFormat = DateFormat('MMM d, yyyy');
final database = FindItDatabase.instance;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupDatabaseFactory();
  runApp(const FindItApp());
}

class FindItApp extends StatefulWidget {
  const FindItApp({super.key});

  @override
  State<FindItApp> createState() => _FindItAppState();
}

class _FindItAppState extends State<FindItApp> {
  Map<String, Object?>? _user;
  bool _loading = true;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final id = preferences.getInt('user_id');
      if (id != null) _user = await database.userById(id);
    } catch (error) {
      debugPrint('Could not restore session: $error');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _login(Map<String, Object?> user) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('user_id', user['id'] as int);
    if (mounted) setState(() => _user = user);
  }

  Future<void> _logout() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('user_id');
    if (mounted) setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FindIt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _user != null
          ? AppShell(
              user: _user!,
              onUserChanged: (user) => setState(() => _user = user),
              onLogout: _logout,
            )
          : !_started
          ? WelcomePage(onStart: () => setState(() => _started = true))
          : AuthPage(
              onAuthenticated: _login,
              onBack: () => setState(() => _started = false),
            ),
    );
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const LogoMark(size: 48),
                  const SizedBox(width: 12),
                  Text(
                    'FindIt',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: Column(
                  children: [
                    Container(
                      height: 224,
                      width: 224,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: .08),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.travel_explore_rounded,
                          color: primary,
                          size: 112,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Lost Something?\nFind It Here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'A better way to reconnect campus belongings with their owners.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: Colors.black54, height: 1.5),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onStart,
                  child: const Text('Get Started'),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'Made for your campus community',
                  style: TextStyle(color: Colors.black45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: primary,
      borderRadius: BorderRadius.circular(size * .28),
    ),
    child: Icon(Icons.search_rounded, color: Colors.white, size: size * .66),
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.onAuthenticated,
    required this.onBack,
  });
  final ValueChanged<Map<String, Object?>> onAuthenticated;
  final VoidCallback onBack;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _studentId = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _studentId.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_register) {
        await database.register(
          fullName: _name.text,
          studentId: _studentId.text,
          email: _email.text,
          password: _password.text,
        );
      }
      final user = await database.login(_email.text, _password.text);
      if (user == null) {
        throw StateError('Unable to sign in with those details.');
      }
      widget.onAuthenticated(user);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().contains('UNIQUE constraint failed')
          ? 'An account with this email already exists.'
          : error.toString().replaceFirst('Bad state: ', '');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_register) {
              setState(() => _register = false);
            } else {
              widget.onBack();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LogoMark(size: 48),
                    const SizedBox(height: 24),
                    Text(
                      _register ? 'Create your account' : 'Welcome back',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _register
                          ? 'Join your campus lost and found community.'
                          : 'Sign in to find or report a campus item.',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 28),
                    if (_register) ...[
                      _textField(
                        _name,
                        'Full name',
                        Icons.person_outline,
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                      _textField(
                        _studentId,
                        'Student ID',
                        Icons.badge_outlined,
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                    ],
                    _textField(
                      _email,
                      'Email',
                      Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null ||
                            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(v.trim())) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 8) {
                          return 'Use at least 8 characters.';
                        }
                        return null;
                      },
                    ),
                    if (_register) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirm,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) => value != _password.text
                            ? 'Passwords do not match.'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_register ? 'Create Account' : 'Sign In'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _register = !_register),
                        child: Text(
                          _register
                              ? 'Already have an account? Sign in'
                              : 'New to FindIt? Create an account',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.user,
    required this.onUserChanged,
    required this.onLogout,
  });
  final Map<String, Object?> user;
  final ValueChanged<Map<String, Object?>> onUserChanged;
  final VoidCallback onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  int _refresh = 0;
  int get _userId => widget.user['id'] as int;

  Future<void> _openReport(String type, {Map<String, Object?>? item}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportFormPage(
          userId: _userId,
          type: item?['item_type'] as String? ?? type,
          item: item,
        ),
      ),
    );
    if (saved == true && mounted) setState(() => _refresh++);
  }

  Future<void> _openItem(Map<String, Object?> item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ItemDetailPage(
          item: item,
          currentUserId: _userId,
          onEdit: () => _openReport(item['item_type'] as String, item: item),
        ),
      ),
    );
    if (changed == true && mounted) setState(() => _refresh++);
  }

  void _openMessages() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConversationsPage(userId: _userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        user: widget.user,
        refreshToken: _refresh,
        onSearch: () => setState(() => _tab = 1),
        onReport: _openReport,
        onItem: _openItem,
        onNotifications: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NotificationsPage(userId: _userId),
            ),
          );
          if (mounted) setState(() => _refresh++);
        },
      ),
      SearchPage(userId: _userId, refreshToken: _refresh, onItem: _openItem),
      MyReportsPage(
        userId: _userId,
        refreshToken: _refresh,
        onItem: _openItem,
        onEdit: (item) => _openReport(item['item_type'] as String, item: item),
      ),
      ProfilePage(
        user: widget.user,
        onUserChanged: widget.onUserChanged,
        onLogout: widget.onLogout,
        onMessages: _openMessages,
        onReports: () => setState(() => _tab = 2),
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'My Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.user,
    required this.refreshToken,
    required this.onSearch,
    required this.onReport,
    required this.onItem,
    required this.onNotifications,
  });
  final Map<String, Object?> user;
  final int refreshToken;
  final VoidCallback onSearch;
  final ValueChanged<String> onReport;
  final ValueChanged<Map<String, Object?>> onItem;
  final VoidCallback onNotifications;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, Object?>> _items = [];
  List<int> _counts = [0, 0, 0];
  int _unread = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    final userId = widget.user['id'] as int;
    try {
      final values = await Future.wait([
        database.searchItems(),
        database.itemCounts(),
        database.unreadNotificationCount(userId),
      ]);
      if (!mounted) return;
      setState(() {
        _items = (values[0] as List<Map<String, Object?>>).take(6).toList();
        _counts = values[1] as List<int>;
        _unread = values[2] as int;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load reports: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.user['full_name'] as String).split(' ').first;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            LogoMark(size: 34),
            SizedBox(width: 9),
            Text('FindIt', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: widget.onNotifications,
            icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text('$_unread'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Hi, $name 👋',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            const Text(
              'Let’s reunite something with its owner.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 22),
            InkWell(
              onTap: widget.onSearch,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Colors.black45),
                    SizedBox(width: 10),
                    Text(
                      'Search lost or found items',
                      style: TextStyle(color: Colors.black45),
                    ),
                    Spacer(),
                    Icon(Icons.tune, color: primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.search_off_rounded,
                    title: 'Report Lost',
                    subtitle: 'Something missing?',
                    tint: const Color(0xFFFFF1F2),
                    color: const Color(0xFFDC2626),
                    onTap: () => widget.onReport('Lost'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'Report Found',
                    subtitle: 'Found an item?',
                    tint: const Color(0xFFECFDF5),
                    color: const Color(0xFF059669),
                    onTap: () => widget.onReport('Found'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                _StatCard(
                  label: 'Lost',
                  count: _counts[0],
                  icon: Icons.search_off,
                  color: const Color(0xFFDC2626),
                ),
                const SizedBox(width: 9),
                _StatCard(
                  label: 'Found',
                  count: _counts[1],
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF059669),
                ),
                const SizedBox(width: 9),
                _StatCard(
                  label: 'Returned',
                  count: _counts[2],
                  icon: Icons.favorite_border,
                  color: primary,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recently reported',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: widget.onSearch,
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_items.isEmpty)
              const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'No reports yet',
                subtitle: 'New campus reports will show up here.',
              )
            else
              ..._items.map(
                (item) =>
                    ItemTile(item: item, onTap: () => widget.onItem(item)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 5),
          Text(
            '$count',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.userId,
    required this.refreshToken,
    required this.onItem,
  });
  final int userId;
  final int refreshToken;
  final ValueChanged<Map<String, Object?>> onItem;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _query = TextEditingController();
  final _location = TextEditingController();
  String _category = 'All';
  String _type = 'All';
  DateTime? _date;
  List<Map<String, Object?>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  @override
  void dispose() {
    _query.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await database.searchItems(
        query: _query.text,
        category: _category,
        type: _type,
        date: _date,
        location: _location.text,
      );
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Search failed: $error')));
      }
    }
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected != null) setState(() => _date = selected);
    _load();
  }

  void _clear() {
    _query.clear();
    _location.clear();
    setState(() {
      _category = 'All';
      _type = 'All';
      _date = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search items',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: Column(
              children: [
                TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Name or description',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: _clear,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: ['All', 'Lost', 'Found']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() => _type = v ?? 'All');
                          _load();
                        },
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: ['All', ...categories]
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() => _category = v ?? 'All');
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _location,
                        onChanged: (_) => _load(),
                        decoration: const InputDecoration(
                          hintText: 'Location',
                          prefixIcon: Icon(Icons.place_outlined),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _chooseDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 17),
                      label: Text(
                        _date == null
                            ? 'Date'
                            : DateFormat('MMM d').format(_date!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off,
                    title: 'No matching items',
                    subtitle: 'Try adjusting or clearing your filters.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                    itemCount: _items.length,
                    itemBuilder: (_, index) => ItemTile(
                      item: _items[index],
                      onTap: () => widget.onItem(_items[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({
    super.key,
    required this.userId,
    required this.refreshToken,
    required this.onItem,
    required this.onEdit,
  });
  final int userId;
  final int refreshToken;
  final ValueChanged<Map<String, Object?>> onItem;
  final ValueChanged<Map<String, Object?>> onEdit;

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  int _filter = 0;
  List<Map<String, Object?>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MyReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    try {
      final items = await database.myItems(widget.userId);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load your reports: $error')),
        );
      }
    }
  }

  List<Map<String, Object?>> get _filtered => _items.where((item) {
    switch (_filter) {
      case 1:
        return item['item_type'] == 'Lost';
      case 2:
        return item['item_type'] == 'Found';
      case 3:
        return item['status'] == 'Active';
      case 4:
        return item['status'] == 'Returned';
      case 5:
        return item['has_match'] == 1;
      default:
        return true;
    }
  }).toList();

  @override
  Widget build(BuildContext context) {
    const filters = ['All', 'Lost', 'Found', 'Active', 'Matched', 'Returned'];
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Reports',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, index) => const SizedBox(width: 7),
              itemBuilder: (_, index) => ChoiceChip(
                label: Text(filters[index]),
                selected: _filter == index,
                onSelected: (_) => setState(() => _filter = index),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No reports in this view',
                    subtitle: 'Your lost and found reports will appear here.',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                      itemCount: _filtered.length,
                      itemBuilder: (_, index) {
                        final item = _filtered[index];
                        return ItemTile(
                          item: item,
                          onTap: () => widget.onItem(item),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') widget.onEdit(item);
                              if (value == 'delete') {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Delete report?'),
                                    content: const Text(
                                      'This cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await database.deleteItem(
                                    item['id'] as int,
                                    widget.userId,
                                  );
                                  _load();
                                }
                              }
                              if (value == 'returned') {
                                await database.updateItemStatus(
                                  item['id'] as int,
                                  widget.userId,
                                  'Returned',
                                );
                                _load();
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit report'),
                              ),
                              if (item['status'] != 'Returned')
                                const PopupMenuItem(
                                  value: 'returned',
                                  child: Text('Mark returned'),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete report'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ReportFormPage extends StatefulWidget {
  const ReportFormPage({
    super.key,
    required this.userId,
    required this.type,
    this.item,
  });
  final int userId;
  final String type;
  final Map<String, Object?>? item;

  @override
  State<ReportFormPage> createState() => _ReportFormPageState();
}

class _ReportFormPageState extends State<ReportFormPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _storage = TextEditingController();
  final _picker = ImagePicker();
  String _category = categories.first;
  DateTime _date = DateTime.now();
  String? _imagePath;
  bool _saving = false;

  bool get _isFound => widget.type == 'Found';

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _name.text = item['item_name'] as String;
      _description.text = item['description'] as String;
      _location.text = item['location'] as String;
      _storage.text = item['storage_location'] as String? ?? '';
      _category = item['category'] as String;
      _date = DateTime.tryParse(item['item_date'] as String) ?? DateTime.now();
      _imagePath = item['image_path'] as String?;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _location.dispose();
    _storage.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (image == null) return;
      final savedPath = await database.saveImage(image);
      if (mounted) setState(() => _imagePath = savedPath);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save photo: $error')));
      }
    }
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await database.saveItem({
        'user_id': widget.userId,
        'item_name': _name.text.trim(),
        'category': _category,
        'description': _description.text.trim(),
        'image_path': _imagePath,
        'item_type': widget.type,
        'item_date': _date.toIso8601String(),
        'location': _location.text.trim(),
        'storage_location': _isFound && _storage.text.trim().isNotEmpty
            ? _storage.text.trim()
            : null,
        'status': widget.item?['status'] ?? 'Active',
      }, id: widget.item?['id'] as int?);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.item == null
                  ? 'Report submitted successfully.'
                  : 'Report updated.',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save report: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.type.toLowerCase();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.item == null ? 'Report' : 'Edit'} $kind item',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                'Item details',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Item name'),
                validator: _required,
              ),
              const SizedBox(height: 13),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Row(
                          children: [
                            Icon(categoryIcon(category), size: 19),
                            const SizedBox(width: 10),
                            Text(category),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _category = value ?? categories.first),
              ),
              const SizedBox(height: 13),
              TextFormField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
                validator: _required,
              ),
              const SizedBox(height: 13),
              OutlinedButton.icon(
                onPressed: _chooseDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  '${_isFound ? 'Date found' : 'Date lost'}: ${dateFormat.format(_date)}',
                ),
              ),
              const SizedBox(height: 13),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                validator: _required,
              ),
              if (_isFound) ...[
                const SizedBox(height: 13),
                TextFormField(
                  controller: _storage,
                  decoration: const InputDecoration(
                    labelText: 'Current storage location (optional)',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Item photo (optional)',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 9),
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 170,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child:
                      _imagePath != null &&
                          storedImageProvider(_imagePath!) != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image(
                              image: storedImageProvider(_imagePath!)!,
                              fit: BoxFit.cover,
                            ),
                            const Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: EdgeInsets.all(10),
                                child: CircleAvatar(
                                  backgroundColor: Colors.white,
                                  child: Icon(Icons.edit, color: primary),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 34,
                              color: primary,
                            ),
                            SizedBox(height: 8),
                            Text('Add a photo from your device'),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.item == null
                              ? 'Submit Report'
                              : 'Save Changes',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
}

class ItemDetailPage extends StatefulWidget {
  const ItemDetailPage({
    super.key,
    required this.item,
    required this.currentUserId,
    required this.onEdit,
  });
  final Map<String, Object?> item;
  final int currentUserId;
  final VoidCallback onEdit;

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  List<Map<String, Object?>> _matches = [];
  bool _loadingMatches = false;
  bool get _isOwner => widget.item['user_id'] == widget.currentUserId;

  Future<void> _showMatches() async {
    setState(() => _loadingMatches = true);
    try {
      final matches = await database.matchesForItem(widget.item['id'] as int);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _loadingMatches = false;
      });
      if (matches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No possible matches yet. We’ll keep checking new reports.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loadingMatches = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load matches: $error')),
        );
      }
    }
  }

  Future<void> _contact() async {
    final otherId = widget.item['user_id'] as int;
    if (otherId == widget.currentUserId) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('This is your report.')));
      return;
    }
    try {
      final conversationId = await database.conversation(
        widget.currentUserId,
        otherId,
      );
      if (!mounted) return;
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            userId: widget.currentUserId,
            otherUserId: otherId,
            otherName:
                widget.item['reporter_name'] as String? ?? 'Campus member',
          ),
        ),
      );
      if (changed == true && mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start conversation: $error')),
        );
      }
    }
  }

  Future<void> _markReturned() async {
    try {
      await database.updateItemStatus(
        widget.item['id'] as int,
        widget.currentUserId,
        'Returned',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item marked as returned.')));
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update item: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final imagePath = item['image_path'] as String?;
    final isFound = item['item_type'] == 'Found';
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Item details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_isOwner)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') widget.onEdit();
                if (value == 'delete') {
                  final yes = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete report?'),
                      content: const Text('This cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (yes == true) {
                    await database.deleteItem(
                      item['id'] as int,
                      widget.currentUserId,
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit report')),
                PopupMenuItem(value: 'delete', child: Text('Delete report')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          if (imagePath != null && storedImageProvider(imagePath) != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image(
                image: storedImageProvider(imagePath)!,
                height: 230,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                categoryIcon(item['category'] as String),
                color: primary,
                size: 72,
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  item['item_name'] as String,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              StatusChip(label: item['item_type'] as String, green: isFound),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              StatusChip(label: item['category'] as String, neutral: true),
              StatusChip(
                label: item['status'] as String,
                green: item['status'] == 'Returned',
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            item['description'] as String,
            style: const TextStyle(color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 20),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: isFound ? 'Date found' : 'Date lost',
            value: _formatDate(item['item_date'] as String),
          ),
          _DetailRow(
            icon: Icons.place_outlined,
            label: 'Location',
            value: item['location'] as String,
          ),
          if (item['storage_location'] != null &&
              (item['storage_location'] as String).isNotEmpty)
            _DetailRow(
              icon: Icons.inventory_2_outlined,
              label: 'Stored at',
              value: item['storage_location'] as String,
            ),
          _DetailRow(
            icon: Icons.person_outline,
            label: 'Reported by',
            value: item['reporter_name'] as String? ?? 'Campus member',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isOwner ? null : _contact,
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(isFound ? 'Contact Finder' : 'Contact Owner'),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: _loadingMatches ? null : _showMatches,
            icon: const Icon(Icons.compare_arrows),
            label: Text(
              _loadingMatches ? 'Checking matches...' : 'Report Possible Match',
            ),
          ),
          if (_isOwner && item['status'] != 'Returned') ...[
            const SizedBox(height: 9),
            TextButton.icon(
              onPressed: _markReturned,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Mark as Returned'),
            ),
          ],
          if (_matches.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Possible matches',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            ..._matches.map(
              (match) => ItemTile(
                item: match,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ItemDetailPage(
                      item: match,
                      currentUserId: widget.currentUserId,
                      onEdit: () {},
                    ),
                  ),
                ),
                trailing: Text(
                  '${((match['match_score'] as num) * 100).round()}%',
                  style: const TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatDate(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? value : dateFormat.format(date);
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: primary),
        const SizedBox(width: 12),
        SizedBox(
          width: 98,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.user,
    required this.onUserChanged,
    required this.onLogout,
    required this.onMessages,
    required this.onReports,
  });
  final Map<String, Object?> user;
  final ValueChanged<Map<String, Object?>> onUserChanged;
  final VoidCallback onLogout;
  final VoidCallback onMessages;
  final VoidCallback onReports;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _busy = false;

  Future<void> _editProfile() async {
    final name = TextEditingController(
      text: widget.user['full_name'] as String,
    );
    final studentId = TextEditingController(
      text: widget.user['student_id'] as String,
    );
    final email = TextEditingController(text: widget.user['email'] as String);
    String? imagePath = widget.user['profile_image_path'] as String?;
    final picker = ImagePicker();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Edit profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: studentId,
                  decoration: const InputDecoration(labelText: 'Student ID'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      final image = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 82,
                      );
                      if (image != null) {
                        imagePath = await database.saveImage(image);
                        update(() {});
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not choose photo: $error'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    imagePath == null
                        ? 'Add profile photo'
                        : 'Change profile photo',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      if (name.text.trim().isEmpty ||
          studentId.text.trim().isEmpty ||
          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enter a name, student ID and valid email.'),
            ),
          );
        }
      } else {
        try {
          await database.updateProfile(widget.user['id'] as int, {
            'full_name': name.text.trim(),
            'student_id': studentId.text.trim(),
            'email': email.text.trim(),
            'profile_image_path': imagePath,
          });
          final updated = await database.userById(widget.user['id'] as int);
          if (updated != null) widget.onUserChanged(updated);
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not update profile: $error')),
            );
          }
        }
      }
    }
    name.dispose();
    studentId.dispose();
    email.dispose();
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirmed = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmed,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (save == true) {
      if (next.text.length < 8 || next.text != confirmed.text) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'New passwords must match and be at least 8 characters.',
              ),
            ),
          );
        }
      } else {
        try {
          final changed = await database.changePassword(
            widget.user['id'] as int,
            current.text,
            next.text,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  changed
                      ? 'Password updated.'
                      : 'Current password is incorrect.',
                ),
              ),
            );
          }
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not change password: $error')),
            );
          }
        }
      }
    }
    current.dispose();
    next.dispose();
    confirmed.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = widget.user['profile_image_path'] as String?;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFFDBEAFE),
              backgroundImage: imagePath == null
                  ? null
                  : storedImageProvider(imagePath),
              child: imagePath == null
                  ? const Icon(Icons.person, size: 48, color: primary)
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              widget.user['full_name'] as String,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Center(
            child: Text(
              widget.user['email'] as String,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(height: 26),
          Card(
            child: Column(
              children: [
                _ProfileRow(
                  icon: Icons.badge_outlined,
                  label: 'Student ID',
                  value: widget.user['student_id'] as String,
                ),
                const Divider(height: 1, indent: 55),
                _ProfileAction(
                  icon: Icons.edit_outlined,
                  label: 'Edit profile',
                  onTap: _editProfile,
                ),
                const Divider(height: 1, indent: 55),
                _ProfileAction(
                  icon: Icons.lock_outline,
                  label: 'Change password',
                  onTap: _changePassword,
                ),
                const Divider(height: 1, indent: 55),
                _ProfileAction(
                  icon: Icons.inventory_2_outlined,
                  label: 'My reports',
                  onTap: widget.onReports,
                ),
                const Divider(height: 1, indent: 55),
                _ProfileAction(
                  icon: Icons.forum_outlined,
                  label: 'Messages',
                  onTap: widget.onMessages,
                ),
                const Divider(height: 1, indent: 55),
                _ProfileAction(
                  icon: Icons.notifications_none,
                  label: 'Notifications',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          NotificationsPage(userId: widget.user['id'] as int),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    widget.onLogout();
                  },
            icon: const Icon(Icons.logout, color: Color(0xFFDC2626)),
            label: const Text(
              'Log out',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: primary),
    title: Text(
      label,
      style: const TextStyle(color: Colors.black54, fontSize: 13),
    ),
    subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: primary),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.userId});
  final int userId;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, Object?>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await database.notifications(widget.userId);
      await database.markNotificationsRead(widget.userId);
      if (mounted) setState(() => _notifications = rows);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load notifications: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Notifications',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: _notifications.isEmpty
        ? const EmptyState(
            icon: Icons.notifications_none,
            title: 'You’re all caught up',
            subtitle: 'Matches, messages and status updates will appear here.',
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final note = _notifications[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      color: primary,
                    ),
                  ),
                  title: Text(
                    note['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${note['message']}\n${_formatDate(note['created_at'] as String)}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
  );
}

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key, required this.userId});
  final int userId;

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  List<Map<String, Object?>> _conversations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await database.conversationsFor(widget.userId);
      if (mounted) setState(() => _conversations = rows);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load messages: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Messages',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: _conversations.isEmpty
        ? const EmptyState(
            icon: Icons.forum_outlined,
            title: 'No conversations yet',
            subtitle:
                'Contact a reporter from an item to start a conversation.',
          )
        : ListView.builder(
            itemCount: _conversations.length,
            itemBuilder: (_, i) {
              final row = _conversations[i];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDBEAFE),
                  child: Icon(Icons.person, color: primary),
                ),
                title: Text(
                  row['full_name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  row['last_message'] as String? ?? 'Start the conversation',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        conversationId: row['conversation_id'] as int,
                        userId: widget.userId,
                        otherUserId: row['other_user_id'] as int,
                        otherName: row['full_name'] as String,
                      ),
                    ),
                  );
                  _load();
                },
              );
            },
          ),
  );
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.otherUserId,
    required this.otherName,
  });
  final int conversationId;
  final int userId;
  final int otherUserId;
  final String otherName;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, Object?>> _messages = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final messages = await database.messages(widget.conversationId);
      if (mounted) {
        setState(() => _messages = messages);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load conversation: $error')),
        );
      }
    }
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await database.sendMessage(
        widget.conversationId,
        widget.userId,
        widget.otherUserId,
        _controller.text,
      );
      _controller.clear();
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send message: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.otherName,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'Say hello',
                  subtitle: 'Messages stay on this device.',
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final message = _messages[i];
                    final mine = message['sender_id'] == widget.userId;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .75,
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: mine ? primary : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              message['message'] as String,
                              style: TextStyle(
                                color: mine ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('h:mm a').format(
                                DateTime.parse(message['created_at'] as String),
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                color: mine ? Colors.white70 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Write a message...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    required this.onTap,
    this.trailing,
  });
  final Map<String, Object?> item;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isFound = item['item_type'] == 'Found';
    final imagePath = item['image_path'] as String?;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child:
                      imagePath != null &&
                          storedImageProvider(imagePath) != null
                      ? Image(
                          image: storedImageProvider(imagePath)!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: const Color(0xFFEFF6FF),
                          child: Icon(
                            categoryIcon(item['category'] as String),
                            color: primary,
                            size: 30,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['item_name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        StatusChip(
                          label: item['item_type'] as String,
                          green: isFound,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item['description'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            item['location'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _formatDate(item['item_date'] as String),
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                const Padding(
                  padding: EdgeInsets.only(left: 5),
                  child: Icon(Icons.chevron_right, color: Colors.black38),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.green = false,
    this.neutral = false,
  });
  final String label;
  final bool green;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final color = neutral
        ? const Color(0xFF64748B)
        : green
        ? const Color(0xFF059669)
        : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 50, color: Colors.black26),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    ),
  );
}

IconData categoryIcon(String category) {
  switch (category) {
    case 'Electronics':
      return Icons.devices_other;
    case 'Wallet':
      return Icons.account_balance_wallet_outlined;
    case 'Keys':
      return Icons.key_outlined;
    case 'ID Card':
      return Icons.badge_outlined;
    case 'Books':
      return Icons.menu_book_outlined;
    case 'Clothing':
      return Icons.checkroom_outlined;
    case 'Accessories':
      return Icons.watch_outlined;
    default:
      return Icons.category_outlined;
  }
}
