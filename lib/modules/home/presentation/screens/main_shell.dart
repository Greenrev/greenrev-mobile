import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/env.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/state/auth_provider.dart';
import '../../../../core/state/cart_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../about/presentation/screens/about_screen.dart';
import '../../../acquisitions/presentation/screens/acquisitions_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../cart/presentation/screens/cart_screen.dart';
import '../../../faq/presentation/screens/faq_screen.dart';
import '../../../legal/data/legal_content.dart';
import '../../../legal/presentation/screens/legal_screen.dart';
import '../../../mechanics/presentation/screens/mechanics_screen.dart';
import '../../../messages/presentation/screens/messages_screen.dart';
import '../../../parts/presentation/screens/parts_screen.dart';
import '../../../showroom/presentation/screens/showroom_screen.dart';
import '../../../vendor/presentation/screens/add_listing_screen.dart';
import 'home_screen.dart';

/// Role badge labels — same as the website navbar.
const _roleLabels = {
  'admin': 'Admin',
  'vendor': 'Vendor',
  'mechanic': 'Expert',
  'customer': 'Client',
};

class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  /// Lets nested screens switch tabs (e.g. "Browse Experts" from Messages).
  static void selectTab(BuildContext context, int index) {
    context.findAncestorStateOfType<_MainShellState>()?._select(index);
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex = widget.initialIndex;
  // Tabs are built the first time they're opened, then kept alive.
  late final Set<int> _visited = {_currentIndex};

  void _select(int index) {
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
      _visited.add(index);
    });
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
      // return HomeScreen(onSelectTab: _select);
      case 1:
        return const ShowroomScreen();
      case 2:
        return const PartsScreen();
      case 3:
        return const MechanicsScreen();
      default:
        return CartScreen(onBrowse: () => _select(HomeTabs.showroom));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              for (var i = 0; i < 5; i++)
                _visited.contains(i) ? _buildTab(i) : const SizedBox.shrink(),
            ],
          ),
          _buildAccountButton(context),
        ],
      ),
      bottomNavigationBar: _buildFloatingBottomBar(),
    );
  }

  Widget _buildFloatingBottomBar() {
    final padding = MediaQuery.of(context).padding;
    final double bottomMargin = padding.bottom > 0 ? 8 : 16;

    return SafeArea(
      top: false,
      child: Container(
        height: 68,
        margin: EdgeInsets.only(left: 16, right: 16, bottom: bottomMargin),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppTheme.obsidian.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  // _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                  _buildNavItem(
                    1,
                    Icons.directions_car_outlined,
                    Icons.directions_car,
                    'Showroom',
                  ),
                  _buildNavItem(
                    2,
                    Icons.settings_outlined,
                    Icons.settings,
                    'Parts',
                  ),
                  _buildNavItem(
                    3,
                    Icons.build_outlined,
                    Icons.build,
                    'Experts',
                  ),
                  _buildNavItem(
                    4,
                    Icons.shopping_bag_outlined,
                    Icons.shopping_bag,
                    'Selection',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData outlineIcon,
    IconData solidIcon,
    String label,
  ) {
    final isSelected = _currentIndex == index;
    final cartCount = context.watch<CartProvider>().items.length;

    return Expanded(
      child: GestureDetector(
        onTap: () => _select(index),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? solidIcon : outlineIcon,
                  color: isSelected ? AppTheme.accent : Colors.white54,
                  size: 20,
                ),
                const SizedBox(height: 5),
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.white38,
                  ),
                ),
              ],
            ),
            if (index == 4 && cartCount > 0)
              Positioned(
                top: 10,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    cartCount > 99 ? '99+' : '$cartCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountButton(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (auth.sessionExpired) {
      auth.acknowledgeSessionExpired();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          showGrSnack(
            context,
            'Your session has expired. Please sign in again.',
            error: true,
          );
      });
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 10, right: 16),
          child: user == null
              ? GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Text(
                          'SIGN IN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: () => _showAccountSheet(context, auth, user),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.5),
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _initial(user),
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  String _initial(UserModel user) {
    final source = (user.name?.trim().isNotEmpty ?? false)
        ? user.name!.trim()
        : user.email;
    return source.isEmpty ? '?' : source.substring(0, 1).toUpperCase();
  }

  Future<void> _openWebDashboard(String path) async {
    final ok = await launchUrl(
      Uri.parse('${Env.siteBaseUrl}$path'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted)
      showGrSnack(context, 'Could not open the website.', error: true);
  }

  void _showAccountSheet(
    BuildContext context,
    AuthProvider auth,
    UserModel user,
  ) {
    final roleLabel = _roleLabels[user.role] ?? user.role;
    final isClient = user.role == 'customer';
    final dashboardPath = switch (user.role) {
      'vendor' => '/vendor/dashboard',
      'mechanic' => '/mechanic/dashboard',
      'admin' => '/admin/dashboard',
      _ => null,
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        void go(Widget screen) {
          Navigator.pop(sheetContext);
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
        }

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.border),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _initial(user),
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name ?? 'Account',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: const TextStyle(
                                color: AppTheme.textSubtle,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GrPill(roleLabel),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: AppTheme.hairline, height: 1),
                  const SizedBox(height: 8),
                  if (isClient)
                    _menuItem(
                      Icons.receipt_long_outlined,
                      'My Requests',
                      () => go(const AcquisitionsScreen()),
                    )
                  else if (dashboardPath != null)
                    _menuItem(
                      Icons.dashboard_outlined,
                      'Dashboard',
                      () {
                        Navigator.pop(sheetContext);
                        _openWebDashboard(dashboardPath);
                      },
                      trailing: Icons.open_in_new,
                    ),
                  if (user.role == 'vendor' || user.role == 'admin')
                    _menuItem(
                      Icons.add_box_outlined,
                      'Add Listing',
                      () => go(const AddListingScreen()),
                    ),
                  _menuItem(Icons.storefront_outlined, 'Browse Boutique', () {
                    Navigator.pop(sheetContext);
                    _select(HomeTabs.showroom);
                  }),
                  _menuItem(
                    Icons.chat_bubble_outline,
                    'My Messages',
                    () => go(
                      MessagesScreen(
                        onBrowseExperts: () => _select(HomeTabs.experts),
                      ),
                    ),
                  ),
                  _menuItem(
                    Icons.info_outline,
                    'About GreenRev',
                    () => go(
                      AboutScreen(onExplore: () => _select(HomeTabs.showroom)),
                    ),
                  ),
                  _menuItem(
                    Icons.help_outline,
                    'Help & FAQ',
                    () => go(const FaqScreen()),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: AppTheme.hairline, height: 1),
                  const SizedBox(height: 8),
                  _menuItem(
                    Icons.description_outlined,
                    'Terms of Use',
                    () => go(const LegalScreen(document: termsOfUse)),
                    muted: true,
                  ),
                  _menuItem(
                    Icons.privacy_tip_outlined,
                    'Privacy Policy',
                    () => go(const LegalScreen(document: privacyPolicy)),
                    muted: true,
                  ),
                  const SizedBox(height: 8),
                  Divider(color: AppTheme.hairline, height: 1),
                  const SizedBox(height: 8),
                  _menuItem(Icons.logout, 'Sign Out', () async {
                    Navigator.pop(sheetContext);
                    await auth.logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }, color: Colors.red.shade300),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _menuItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
    bool muted = false,
    IconData? trailing,
  }) {
    final c =
        color ??
        (muted ? Colors.white54 : Colors.white.withValues(alpha: 0.85));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: color ?? (muted ? Colors.white38 : AppTheme.accent),
              size: 18,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: c, fontSize: muted ? 14 : 16),
              ),
            ),
            if (trailing != null)
              Icon(trailing, color: Colors.white30, size: 14),
          ],
        ),
      ),
    );
  }
}
