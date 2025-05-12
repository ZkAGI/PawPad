import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'services/solana_wallet_provider.dart';
import 'screens/pin_setup_screen.dart';
import 'screens/pin_login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SolanaWalletProvider()),
      ],
      child: const SolanaWalletApp(),
    ),
  );
}

class SolanaWalletApp extends StatelessWidget {
  const SolanaWalletApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solana Wallet',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthCheckScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({Key? key}) : super(key: key);

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Initialize the wallet provider
    final walletProvider = Provider.of<SolanaWalletProvider>(context, listen: false);
    await walletProvider.initialize();

    // Check if PIN is set
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isPinSet = await authProvider.isPinSet();

    if (!mounted) return;

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return FutureBuilder<bool>(
      future: authProvider.isPinSet(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final isPinSet = snapshot.data ?? false;

        if (!isPinSet) {
          // PIN is not set, show PIN setup screen
          return const PinSetupScreen();
        } else if (!authProvider.isAuthenticated) {
          // PIN is set but user is not authenticated, show login screen
          return const PinLoginScreen();
        } else {
          // User is authenticated, show home screen
          return const HomeScreen();
        }
      },
    );
  }
}