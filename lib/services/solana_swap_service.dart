import 'dart:convert';
import 'dart:typed_data';
import 'package:solana/solana.dart';
import 'package:http/http.dart' as http;

Future<String?> signAndSendJupiterSwapTx({
  required String base64Tx,
  required Ed25519HDKeyPair wallet,
}) async {
  final rpcUrl = 'https://api.mainnet-beta.solana.com';
  final client = SolanaClient(
    rpcUrl: Uri.parse(rpcUrl),
    websocketUrl: Uri.parse('wss://api.mainnet-beta.solana.com'),
  );

  try {
    // 1. Decode base64 → raw bytes
    final Uint8List rawTx = base64Decode(base64Tx);

    // 2. Extract the message bytes that need to be signed
    final messageBytes = extractMessageBytes(rawTx);

    // 3. Sign the message bytes with the wallet
    // Convert the Signature to Uint8List
    final signature = await wallet.sign(messageBytes);
    // Convert List<int> to Uint8List for the signature bytes
    final signatureBytes = Uint8List.fromList(signature.bytes);

    // 4. Construct the signed transaction
    final signedTx = constructSignedTransaction(rawTx, signatureBytes);

    // 5. Send the transaction
    final txSig = await client.rpcClient.sendTransaction(
      base64Encode(signedTx), // Convert Uint8List to base64 string for sendTransaction
      preflightCommitment: Commitment.confirmed,
    );

    print('✅ Jupiter Swap TX Sent: https://solscan.io/tx/$txSig');
    return txSig;
  } catch (e) {
    print('❌ Error signing/sending swap TX: $e');
    return null;
  }
}

// Function to extract the message part from the transaction
Uint8List extractMessageBytes(Uint8List serializedTx) {
  // The first byte indicates the number of signatures
  final numSignatures = serializedTx[0];

  // Skip the signatures section (64 bytes per signature)
  final messageStart = 1 + (numSignatures * 64);

  // Extract the message part
  return serializedTx.sublist(messageStart);
}

// Function to construct a signed transaction
Uint8List constructSignedTransaction(Uint8List originalTx, Uint8List signature) {
  // The first byte indicates the number of signatures (should be 1)
  // Keep the first byte, replace the signature part, and keep the message part

  final numSignatures = originalTx[0];
  final messageStart = 1 + (numSignatures * 64);
  final messageBytes = originalTx.sublist(messageStart);

  // Construct the signed transaction
  final signedTx = Uint8List(1 + 64 + messageBytes.length);

  // Set the number of signatures (1)
  signedTx[0] = 1;

  // Set the signature
  for (int i = 0; i < 64 && i < signature.length; i++) {
    signedTx[1 + i] = signature[i];
  }

  // Set the message
  for (int i = 0; i < messageBytes.length; i++) {
    signedTx[1 + 64 + i] = messageBytes[i];
  }

  return signedTx;
}

// import 'dart:convert';
// import 'package:flutter/services.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_js/flutter_js.dart';
// import 'dart:async';
//
// class SolanaSwapService {
//   static SolanaSwapService? _instance;
//   JavascriptRuntime? _jsRuntime;
//   bool _initialized = false;
//   bool _isInitializing = false;
//   bool _initFailed = false;
//   String? _initError;
//
//   // Added for safe access to JS runtime
//   JavascriptRuntime get jsRuntime {
//     if (_jsRuntime == null) {
//       _jsRuntime = getJavascriptRuntime();
//       // Add debug logging for JS console outputs
//       _jsRuntime!.onMessage('console', (dynamic args) {
//         debugPrint("JS Console: $args");
//       });
//     }
//     return _jsRuntime!;
//   }
//
//   // Singleton pattern
//   factory SolanaSwapService() {
//     _instance ??= SolanaSwapService._internal();
//     return _instance!;
//   }
//
//   SolanaSwapService._internal() {
//     // Create JS runtime on demand, not immediately
//     debugPrint("SolanaSwapService initialized");
//   }
//
//   Future<bool> initialize() async {
//     if (_initialized) return true;
//
//     if (_isInitializing) {
//       // Wait until initialization is complete with a timeout
//       int attempts = 0;
//       while (_isInitializing && attempts < 50) { // Max 5 seconds wait
//         await Future.delayed(const Duration(milliseconds: 100));
//         attempts++;
//       }
//       if (_isInitializing) {
//         debugPrint("Initialize timeout after waiting 5 seconds");
//         _isInitializing = false;
//         _initFailed = true;
//         _initError = "Initialize timed out";
//         return false;
//       }
//       return _initialized;
//     }
//
//     _isInitializing = true;
//     _initFailed = false;
//     _initError = null;
//
//     try {
//       debugPrint("Initializing Solana Swap Service...");
//
//       // Create JS runtime if not already created
//       try {
//         if (_jsRuntime == null) {
//           _jsRuntime = getJavascriptRuntime();
//           // Add debug logging for JS console outputs
//           _jsRuntime!.onMessage('console', (dynamic args) {
//             debugPrint("JS Console: $args");
//           });
//         }
//       } catch (e) {
//         throw Exception("Failed to create JavaScript runtime: $e");
//       }
//
//       // Basic test of JS runtime
//       try {
//         JsEvalResult testResult = jsRuntime.evaluate('2 + 2');
//         if (testResult.stringResult != '4') {
//           throw Exception('JS runtime test failed: ${testResult.stringResult}');
//         }
//         debugPrint("JS runtime basic test passed");
//       } catch (e) {
//         throw Exception("JS runtime basic test failed: $e");
//       }
//
//       // Load necessary JS libraries with enhanced error handling
//       try {
//         await _loadJsLibraries();
//         debugPrint("JS libraries loaded successfully");
//       } catch (e) {
//         throw Exception("Failed to load JS libraries: $e");
//       }
//
//       // Load our swap script
//       try {
//         await _loadSwapScript();
//         debugPrint("Swap script loaded successfully");
//       } catch (e) {
//         throw Exception("Failed to load swap script: $e");
//       }
//
//       // Initialize the dependencies
//       try {
//         await _initializeDependencies();
//         debugPrint("Dependencies initialized successfully");
//       } catch (e) {
//         throw Exception("Failed to initialize dependencies: $e");
//       }
//
//       _initialized = true;
//       debugPrint("Solana Swap Service initialized successfully");
//       return true;
//     } catch (e) {
//       _initFailed = true;
//       _initError = e.toString();
//       debugPrint("Error initializing Solana Swap Service: $e");
//       return false;
//     } finally {
//       _isInitializing = false;
//     }
//   }
//
//   Future<void> _loadJsLibraries() async {
//     try {
//       // Load required libraries one by one with error handling
//       await _loadJsFile('solana-web3.min.js', 'solanaWeb3');
//       await _loadJsFile('bs58.min.js', 'bs58');
//       await _loadJsFile('solana-agent-kit.min.js', 'solanaAgentKit');
//     } catch (e) {
//       debugPrint("Error loading JS libraries: $e");
//       throw e;
//     }
//   }
//
//   Future<void> _loadJsFile(String filename, String globalVarName) async {
//     try {
//       debugPrint("Loading $filename...");
//       String jsCode = await rootBundle.loadString('assets/js/$filename');
//
//       // Try to evaluate with timeout
//       JsEvalResult result = await _evaluateWithTimeout(jsCode, 10000); // 10 seconds timeout
//
//       if (result.isError) {
//         throw Exception('Error loading $filename: ${result.stringResult}');
//       }
//
//       // Verify the global variable exists
//       JsEvalResult checkResult = jsRuntime.evaluate('typeof $globalVarName !== "undefined"');
//       if (checkResult.stringResult != 'true') {
//         throw Exception('$filename loaded but $globalVarName not defined');
//       }
//
//       debugPrint("$filename loaded successfully");
//     } catch (e) {
//       debugPrint("Error loading $filename: $e");
//       throw e;
//     }
//   }
//   Future<void> _loadSwapScript() async {
//     try {
//       debugPrint("Loading swap script...");
//       String swapScript = await rootBundle.loadString('assets/js/swap_script.js');
//
//       // Load the original script without modifications
//       JsEvalResult scriptResult = await _evaluateWithTimeout(swapScript, 10000); // 10 seconds timeout
//
//       if (scriptResult.isError) {
//         throw Exception('Error loading swap script: ${scriptResult.stringResult}');
//       }
//
//       // Verify key functions exist
//       JsEvalResult checkInitResult = jsRuntime.evaluate('typeof initializeDependencies === "function"');
//       if (checkInitResult.stringResult != 'true') {
//         throw Exception('Swap script loaded but initializeDependencies function not defined');
//       }
//
//       JsEvalResult checkSwapResult = jsRuntime.evaluate('typeof executeSwapWrapper === "function"');
//       if (checkSwapResult.stringResult != 'true') {
//         throw Exception('Swap script loaded but executeSwapWrapper function not defined');
//       }
//
//       // Now, apply our enhancements separately - without redefining functions
//       String enhancements = '''
//     // Add console shim for better error reporting
//     (function() {
//       const originalConsoleLog = console.log;
//       console.log = function() {
//         const args = Array.from(arguments).map(arg =>
//           typeof arg === 'object' ? JSON.stringify(arg) : String(arg)
//         ).join(' ');
//         originalConsoleLog.apply(console, [args]);
//       };
//     })();
//
//     // Add RPC health check function
//     // async function checkRpcHealth(rpcUrl) {
//     //   try {
//     //     console.log("[RPC] Testing RPC health: " + rpcUrl);
//     //     const response = await fetch(rpcUrl, {
//     //       method: 'POST',
//     //       headers: { 'Content-Type': 'application/json' },
//     //       body: JSON.stringify({
//     //         jsonrpc: "2.0",
//     //         id: 1,
//     //         method: "getHealth",
//     //         params: []
//     //       })
//     //     });
//     //
//     //     const result = await response.json();
//     //     console.log("[RPC] Health check result: " + JSON.stringify(result));
//     //     return result.result === "ok";
//     //   } catch (error) {
//     //     console.log("[RPC] Health check failed: " + error);
//     //     return false;
//     //   }
//     // }
//
//     // Make function available globally
//     // this.checkRpcHealth = checkRpcHealth;
//
//     console.log("[ENHANCEMENTS] Applied successfully");
//     ''';
//
//       // Apply the enhancements
//       JsEvalResult enhancementsResult = jsRuntime.evaluate(enhancements);
//       if (enhancementsResult.isError) {
//         debugPrint("Warning: Could not apply JS enhancements: ${enhancementsResult.stringResult}");
//         // Continue anyway since this is not critical
//       } else {
//         debugPrint("JS enhancements applied successfully");
//       }
//
//     } catch (e) {
//       debugPrint("Error loading swap script: $e");
//       throw e;
//     }
//   }
//
// //   Future<void> _loadSwapScript() async {
// //     try {
// //       debugPrint("Loading swap script...");
// //       String swapScript = await rootBundle.loadString('assets/js/swap_script.js');
// //
// //       // Add console shim for better error reporting
// //       swapScript = '''
// // // Console shim for better error reporting
// // (function() {
// //   const originalConsoleLog = console.log;
// //   console.log = function() {
// //     const args = Array.from(arguments).map(arg =>
// //       typeof arg === 'object' ? JSON.stringify(arg) : String(arg)
// //     ).join(' ');
// //     originalConsoleLog.apply(console, [args]);
// //   };
// // })();
// //
// // $swapScript
// //       ''';
// //
// //       JsEvalResult scriptResult = await _evaluateWithTimeout(swapScript, 10000); // 10 seconds timeout
// //
// //       if (scriptResult.isError) {
// //         throw Exception('Error loading swap script: ${scriptResult.stringResult}');
// //       }
// //
// //       // Verify key functions exist
// //       JsEvalResult checkInitResult = jsRuntime.evaluate('typeof initializeDependencies === "function"');
// //       if (checkInitResult.stringResult != 'true') {
// //         throw Exception('Swap script loaded but initializeDependencies function not defined');
// //       }
// //
// //       JsEvalResult checkSwapResult = jsRuntime.evaluate('typeof executeSwapWrapper === "function"');
// //       if (checkSwapResult.stringResult != 'true') {
// //         throw Exception('Swap script loaded but executeSwapWrapper function not defined');
// //       }
// //     } catch (e) {
// //       debugPrint("Error loading swap script: $e");
// //       throw e;
// //     }
// //   }
//
//   Future<void> _initializeDependencies() async {
//     try {
//       debugPrint("Initializing dependencies...");
//
//       // Initialize the dependencies in our JS code with timeout
//       final code = 'initializeDependencies(solanaWeb3, solanaAgentKit, bs58)';
//       JsEvalResult initResult = await _evaluateWithTimeout(code, 5000); // 5 seconds timeout
//
//       if (initResult.isError) {
//         throw Exception('Error initializing dependencies: ${initResult.stringResult}');
//       }
//
//       if (initResult.stringResult != 'true') {
//         throw Exception('Dependencies initialization failed: ${initResult.stringResult}');
//       }
//     } catch (e) {
//       debugPrint("Error initializing dependencies: $e");
//       throw e;
//     }
//   }
//
//   // Helper method to evaluate JS with timeout
//   Future<JsEvalResult> _evaluateWithTimeout(String code, int timeoutMs) async {
//     final completer = Completer<JsEvalResult>();
//     Timer? timeoutTimer;
//
//     try {
//       // Set timeout
//       timeoutTimer = Timer(Duration(milliseconds: timeoutMs), () {
//         if (!completer.isCompleted) {
//           completer.completeError(
//               Exception('JavaScript evaluation timed out after $timeoutMs ms')
//           );
//         }
//         // No need to cancel here as this is the timeout callback itself
//       });
//
//       // Run evaluation in a microtask to avoid blocking
//       Future.microtask(() {
//         try {
//           final result = jsRuntime.evaluate(code);
//           // Cancel timeout timer - using null-aware operator
//           timeoutTimer?.cancel();
//           timeoutTimer = null;
//
//           if (!completer.isCompleted) {
//             completer.complete(result);
//           }
//         } catch (e) {
//           // Cancel timeout timer - using null-aware operator
//           timeoutTimer?.cancel();
//           timeoutTimer = null;
//
//           if (!completer.isCompleted) {
//             completer.completeError(e);
//           }
//         }
//       });
//
//       return await completer.future;
//     } catch (e) {
//       // Handle any unexpected errors
//       timeoutTimer?.cancel();
//       timeoutTimer = null;
//       throw e;
//     }
//   }
//   // Modified executeSwap with better error handling and safer approach
//
//   // Future<Map<String, dynamic>> executeSwap({
//   //   required String publicKey,
//   //   required Uint8List secretKey,
//   //   required String outputMint,
//   //   required double solBalance,
//   // }) async {
//   //   if (!_initialized) {
//   //     final initSuccess = await initialize();
//   //     if (!initSuccess) {
//   //       return {
//   //         'success': false,
//   //         'error': 'Failed to initialize Solana Swap Service: $_initError',
//   //       };
//   //     }
//   //   }
//   //
//   //   try {
//   //     // Convert secret key bytes to list for JSON serialization
//   //     final secretKeyList = secretKey.toList();
//   //     debugPrint("Secret key length in executeSwap: ${secretKeyList.length}");
//   //
//   //     // Create a keypair object
//   //     final keypair = {
//   //       'publicKey': publicKey,
//   //       'secretKey': secretKeyList,
//   //     };
//   //
//   //     // Convert to JSON string, but escape properly for JS string
//   //     final keypairJson = jsonEncode(keypair).replaceAll("'", "\\'");
//   //
//   //     debugPrint("Executing swap with parameters:");
//   //     debugPrint("  Output Mint: $outputMint");
//   //     debugPrint("  Public Key: $publicKey");
//   //     debugPrint("  Secret Key: [${secretKeyList.length} bytes]");
//   //     debugPrint("  SOL Balance: $solBalance");
//   //
//   //     // Use a simpler approach - store the result in a global JS variable
//   //     final jsCode = '''
//   //   try {
//   //     console.log("[DART] Starting direct swap with pre-verified balance: $solBalance SOL");
//   //
//   //     // Extract keypair
//   //     const keypairData = JSON.parse('$keypairJson');
//   //     const userKeypair = {
//   //       publicKey: keypairData.publicKey,
//   //       secretKey: new Uint8Array(keypairData.secretKey)
//   //     };
//   //
//   //     console.log("[SWAP] Using keypair with publicKey:", userKeypair.publicKey);
//   //     console.log("[SWAP] Secret key length:", userKeypair.secretKey.length);
//   //
//   //     // Fixed amount for testing
//   //     const amount = 0.0005;
//   //     console.log("[SWAP] Amount to swap:", amount, "SOL");
//   //
//   //     // Create PublicKey objects
//   //     const outputMintPublicKey = new solanaWeb3.PublicKey('$outputMint');
//   //     const inputMint = new solanaWeb3.PublicKey('So11111111111111111111111111111111111111112'); // SOL
//   //
//   //     console.log("[SWAP] Executing trade:", amount, "SOL ->", '$outputMint');
//   //
//   //     // Create a realistic transaction signature (64 characters hex)
//   //     const signature = Array.from(
//   //       { length: 64 },
//   //       () => '0123456789abcdef'.charAt(Math.floor(Math.random() * 16))
//   //     ).join('');
//   //
//   //     console.log("[SWAP] Trade successful! Signature:", signature);
//   //
//   //     // Store the result in a global variable instead of using postMessage
//   //     window.swapResult = {
//   //       success: true,
//   //       signature: signature,
//   //       amount: amount,
//   //       inputMint: "SOL",
//   //       outputMint: '$outputMint'
//   //     };
//   //
//   //     // Return the signature for immediate feedback
//   //     signature;
//   //   } catch (error) {
//   //     console.log("[SWAP] Top-level error in direct swap:", error);
//   //
//   //     // Store error in global variable
//   //     window.swapResult = {
//   //       success: false,
//   //       error: "Error executing swap: " + (error.message || String(error))
//   //     };
//   //
//   //     "Error: " + error.message;
//   //   }
//   //   ''';
//   //
//   //     // Execute the JavaScript code
//   //     final initResult = jsRuntime.evaluate(jsCode);
//   //     final signature = initResult.stringResult;
//   //     debugPrint("Swap initiated with result: $signature");
//   //
//   //     // Wait a short time for the simulation to complete
//   //     await Future.delayed(const Duration(seconds: 2));
//   //
//   //     // Retrieve the result from the global variable
//   //     final resultCode = '''
//   //   JSON.stringify(window.swapResult || { success: false, error: "No result available" })
//   //   ''';
//   //
//   //     final resultJson = jsRuntime.evaluate(resultCode).stringResult;
//   //     final result = jsonDecode(resultJson);
//   //
//   //     debugPrint("Final swap result: $result");
//   //     return result;
//   //   } catch (e) {
//   //     debugPrint("Top-level error in executeSwap: $e");
//   //     return {
//   //       'success': false,
//   //       'error': 'Unexpected error: $e',
//   //     };
//   //   }
//   // }
//   // Future<Map<String, dynamic>> executeSwap({
//   //   required String publicKey,
//   //   required Uint8List secretKey,
//   //   required String outputMint,
//   //   required double solBalance,
//   // }) async {
//   //   if (!_initialized) {
//   //     final initSuccess = await initialize();
//   //     if (!initSuccess) {
//   //       return {
//   //         'success': false,
//   //         'error': 'Failed to initialize Solana Swap Service: $_initError',
//   //       };
//   //     }
//   //   }
//   //
//   //   try {
//   //     // Convert secret key bytes to list for JSON serialization
//   //     final secretKeyList = secretKey.toList();
//   //     debugPrint("Secret key length in executeSwap: ${secretKeyList.length}");
//   //
//   //     // Create a keypair object
//   //     final keypair = {
//   //       'publicKey': publicKey,
//   //       'secretKey': secretKeyList,
//   //     };
//   //
//   //     // Convert to JSON string, but escape properly for JS string
//   //     final keypairJson = jsonEncode(keypair).replaceAll("'", "\\'");
//   //
//   //     debugPrint("Executing swap with parameters:");
//   //     debugPrint("  Output Mint: $outputMint");
//   //     debugPrint("  Public Key: $publicKey");
//   //     debugPrint("  Secret Key: [${secretKeyList.length} bytes]");
//   //     debugPrint("  SOL Balance: $solBalance");
//   //
//   //     // Use a simpler approach - use global variables instead of window object
//   //     final jsCode = '''
//   // try {
//   //   console.log("[DART] Starting direct swap with pre-verified balance: $solBalance SOL");
//   //
//   //   // Extract keypair
//   //   const keypairData = JSON.parse('$keypairJson');
//   //   const userKeypair = {
//   //     publicKey: keypairData.publicKey,
//   //     secretKey: new Uint8Array(keypairData.secretKey)
//   //   };
//   //
//   //   console.log("[SWAP] Using keypair with publicKey:", userKeypair.publicKey);
//   //   console.log("[SWAP] Secret key length:", userKeypair.secretKey.length);
//   //
//   //   // Fixed amount for testing
//   //   const amount = 0.0005;
//   //   console.log("[SWAP] Amount to swap:", amount, "SOL");
//   //
//   //   // Create PublicKey objects
//   //   const outputMintPublicKey = new solanaWeb3.PublicKey('$outputMint');
//   //   const inputMint = new solanaWeb3.PublicKey('So11111111111111111111111111111111111111112'); // SOL
//   //
//   //   console.log("[SWAP] Executing trade:", amount, "SOL ->", '$outputMint');
//   //
//   //   // Create a realistic transaction signature (64 characters hex)
//   //   const signature = Array.from(
//   //     { length: 64 },
//   //     () => '0123456789abcdef'.charAt(Math.floor(Math.random() * 16))
//   //   ).join('');
//   //
//   //   console.log("[SWAP] Trade successful! Signature:", signature);
//   //
//   //   // Store the result in global variables instead of window object
//   //   var swapResultSuccess = true;
//   //   var swapResultSignature = signature;
//   //   var swapResultAmount = amount;
//   //   var swapResultInputMint = "SOL";
//   //   var swapResultOutputMint = '$outputMint';
//   //
//   //   // Return the signature for immediate feedback
//   //   JSON.stringify({
//   //     success: true,
//   //     signature: signature,
//   //     amount: amount,
//   //     inputMint: "SOL",
//   //     outputMint: '$outputMint'
//   //   });
//   // } catch (error) {
//   //   console.log("[SWAP] Top-level error in direct swap:", error);
//   //
//   //   // Store error in global variables
//   //   var swapResultSuccess = false;
//   //   var swapResultError = "Error executing swap: " + (error.message || String(error));
//   //
//   //   JSON.stringify({
//   //     success: false,
//   //     error: "Error executing swap: " + (error.message || String(error))
//   //   });
//   // }
//   // ''';
//   //
//   //     // Execute the JavaScript code
//   //     final result = jsRuntime.evaluate(jsCode);
//   //
//   //     if (result.isError) {
//   //       debugPrint("JavaScript execution error: ${result.stringResult}");
//   //       return {
//   //         'success': false,
//   //         'error': 'JavaScript execution error: ${result.stringResult}',
//   //       };
//   //     }
//   //
//   //     try {
//   //       // Try to parse the result directly - this should work now
//   //       final resultMap = jsonDecode(result.stringResult);
//   //       return resultMap;
//   //     } catch (e) {
//   //       debugPrint("Error parsing result: $e");
//   //
//   //       // Fallback to reading the global variables
//   //       final successCheck = jsRuntime.evaluate('typeof swapResultSuccess !== "undefined" ? swapResultSuccess : false');
//   //       final success = successCheck.stringResult == 'true';
//   //
//   //       if (success) {
//   //         final signature = jsRuntime.evaluate('swapResultSignature').stringResult;
//   //         final amount = double.tryParse(jsRuntime.evaluate('swapResultAmount').stringResult) ?? 0.0005;
//   //         final inputMint = jsRuntime.evaluate('swapResultInputMint').stringResult;
//   //         final outputMint = jsRuntime.evaluate('swapResultOutputMint').stringResult;
//   //
//   //         return {
//   //           'success': true,
//   //           'signature': signature,
//   //           'amount': amount,
//   //           'inputMint': inputMint,
//   //           'outputMint': outputMint,
//   //         };
//   //       } else {
//   //         final error = jsRuntime.evaluate('typeof swapResultError !== "undefined" ? swapResultError : "Unknown error"').stringResult;
//   //         return {
//   //           'success': false,
//   //           'error': error,
//   //         };
//   //       }
//   //     }
//   //   } catch (e) {
//   //     debugPrint("Top-level error in executeSwap: $e");
//   //     return {
//   //       'success': false,
//   //       'error': 'Unexpected error: $e',
//   //     };
//   //   }
//   // }
//
//   Future<Map<String, dynamic>> executeSwap({
//     required String publicKey,
//     required Uint8List secretKey,
//     required String outputMint,
//     required double solBalance,
//   }) async {
//     // 1️⃣ Ensure JS is initialized
//     if (!_initialized) {
//       final ok = await initialize();
//       if (!ok) {
//         return { 'success': false, 'error': 'JS init failed: $_initError' };
//       }
//     }
//
//     // 2️⃣ Build the keypair JSON
//     final keypair = {
//       'publicKey': publicKey,
//       'secretKey': secretKey.toList(),
//     };
//     final keypairJson = jsonEncode(keypair);
//
//     // 3️⃣ Create a unique channel and completer
//     final callbackChannel = 'swap_cb_${DateTime.now().millisecondsSinceEpoch}';
//     final completer = Completer<Map<String, dynamic>>();
//
//     // 4️⃣ Listen for the JS callback
//     jsRuntime.onMessage(callbackChannel, (dynamic resultData) {
//       try {
//         final Map<String, dynamic> result =
//         jsonDecode(resultData as String) as Map<String, dynamic>;
//         if (!completer.isCompleted) completer.complete(result);
//       } catch (e) {
//         if (!completer.isCompleted) {
//           completer.complete({
//             'success': false,
//             'error': 'Malformed JS result: $e',
//           });
//         }
//       }
//     });
//
//     // 5️⃣ Fire off the JS swap
//     final wrapperCall = '''
//     executeSwapWrapper(
//       '$keypairJson',
//       '$outputMint',
//       '$callbackChannel'
//     );
//   ''';
//     jsRuntime.evaluate(wrapperCall);
//
//     // 6️⃣ Wait for the JS to reply (or time out)
//     return completer.future.timeout(
//       const Duration(minutes: 2),
//       onTimeout: () => {
//         'success': false,
//         'error': 'Swap timed out',
//       },
//     );
//   }
//
//
// }
