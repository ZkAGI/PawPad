// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:solana_hackathon_2025/screens/settings_screen.dart';
// import 'package:solana_hackathon_2025/services/agent_provider.dart';
// import 'services/auth_provider.dart';
// import 'screens/pin_setup_screen.dart';
// import 'screens/pin_login_screen.dart';
// import 'screens/home_screen.dart';
//
// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => AuthProvider()),
//         ChangeNotifierProvider(create: (_) => AgentProvider()),
//       ],
//       child: const SolanaWalletApp(),
//     ),
//   );
// }
//
// class SolanaWalletApp extends StatelessWidget {
//   const SolanaWalletApp({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//     title: 'PawPad',
//         routes: {
//           '/settings': (context) => const SettingsScreen(),
//         },
//     theme: ThemeData(
//     scaffoldBackgroundColor: const Color(0xFF000A19),
//     fontFamily: 'TT Firs Neue',
//     textTheme: const TextTheme(
//     // bodyText1: TextStyle(color: Colors.white),
//     // bodyText2: TextStyle(color: Colors.white),
//     // button: TextStyle(color: Colors.white),
//     // headline6: TextStyle(color: Colors.white), // AppBar title
//     ),
//     appBarTheme: const AppBarTheme(
//     backgroundColor: Color(0xFF000A19),
//     elevation: 0,
//     titleTextStyle: TextStyle(
//     fontFamily: 'TT Firs Neue',
//     fontSize: 20,
//     fontWeight: FontWeight.bold,
//     color: Colors.white,
//     ),
//     ),
//     ),
//     home: const AuthCheckScreen(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }
//
// class AuthCheckScreen extends StatefulWidget {
//   const AuthCheckScreen({Key? key}) : super(key: key);
//
//   @override
//   State<AuthCheckScreen> createState() => _AuthCheckScreenState();
// }
//
// class _AuthCheckScreenState extends State<AuthCheckScreen> {
//   bool _isInitialized = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _checkAuthStatus();
//   }
//
//   Future<void> _checkAuthStatus() async {
//     // Initialize the wallet provider
//
//     // Check if PIN is set
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final isPinSet = await authProvider.isPinSet();
//
//     if (!mounted) return;
//
//     setState(() {
//       _isInitialized = true;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (!_isInitialized) {
//       return const Scaffold(
//         body: Center(
//           child: CircularProgressIndicator(),
//         ),
//       );
//     }
//
//     final authProvider = Provider.of<AuthProvider>(context);
//
//     if (authProvider.isLoading) {
//       return const Scaffold(
//         body: Center(
//           child: CircularProgressIndicator(),
//         ),
//       );
//     }
//
//     return FutureBuilder<bool>(
//       future: authProvider.isPinSet(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Scaffold(
//             body: Center(
//               child: CircularProgressIndicator(),
//             ),
//           );
//         }
//
//         final isPinSet = snapshot.data ?? false;
//
//         if (!isPinSet) {
//           // PIN is not set, show PIN setup screen
//           return const PinSetupScreen();
//         } else if (!authProvider.isAuthenticated) {
//           // PIN is set but user is not authenticated, show login screen
//           return const PinLoginScreen();
//         } else {
//           // User is authenticated, show home screen
//           return const HomeScreen();
//         }
//       },
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solana_hackathon_2025/screens/settings_screen.dart';
import 'package:solana_hackathon_2025/services/agent_provider.dart';
import 'package:solana_hackathon_2025/services/solana_swap_service.dart';
import 'services/auth_provider.dart';
import 'screens/pin_setup_screen.dart';
import 'screens/pin_login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  // This needs to be called before any async operations in main()
  WidgetsFlutterBinding.ensureInitialized();

  // Create and initialize providers first
  final authProvider = AuthProvider();
  final agentProvider = AgentProvider();

  // Wait for initialization to complete
  await agentProvider.initialize();

  // Initialize the Solana swap service
  // final solanaSwapService = SolanaSwapService();
  // solanaSwapService.initialize().then((success) {
  //   if (success) {
  //     debugPrint("Solana Swap Service initialized successfully");
  //   } else {
  //     debugPrint("Solana Swap Service initialization failed, app will continue without swap functionality");
  //   }
  // }).catchError((e) {
  //   debugPrint("Failed to initialize SolanaSwapService, but app will continue: $e");
  // });

  // Now we can run the app with initialized providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: agentProvider),
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
      title: 'PawPad',
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF000A19),
        fontFamily: 'TT Firs Neue',
        textTheme: const TextTheme(
          // bodyText1: TextStyle(color: Colors.white),
          // bodyText2: TextStyle(color: Colors.white),
          // button: TextStyle(color: Colors.white),
          // headline6: TextStyle(color: Colors.white), // AppBar title
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF000A19),
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'TT Firs Neue',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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
    // Load stored wallets from WalletStorageService
    final agentProvider = Provider.of<AgentProvider>(context, listen: false);
    try {
      // Load wallet list from WalletStorageService - this assumes you've added the method to AgentProvider
      await agentProvider.loadStoredWallets();
    } catch (e) {
      print('Error loading stored wallets: $e');
    }

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