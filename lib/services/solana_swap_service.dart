import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
import 'dart:async';

class SolanaSwapService {
  static SolanaSwapService? _instance;
  JavascriptRuntime? _jsRuntime;
  bool _initialized = false;
  bool _isInitializing = false;
  bool _initFailed = false;
  String? _initError;

  // Added for safe access to JS runtime
  JavascriptRuntime get jsRuntime {
    if (_jsRuntime == null) {
      _jsRuntime = getJavascriptRuntime();
      // Add debug logging for JS console outputs
      _jsRuntime!.onMessage('console', (dynamic args) {
        debugPrint("JS Console: $args");
      });
    }
    return _jsRuntime!;
  }

  // Singleton pattern
  factory SolanaSwapService() {
    _instance ??= SolanaSwapService._internal();
    return _instance!;
  }

  SolanaSwapService._internal() {
    // Create JS runtime on demand, not immediately
    debugPrint("SolanaSwapService initialized");
  }

  Future<bool> initialize() async {
    if (_initialized) return true;

    if (_isInitializing) {
      // Wait until initialization is complete with a timeout
      int attempts = 0;
      while (_isInitializing && attempts < 50) { // Max 5 seconds wait
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (_isInitializing) {
        debugPrint("Initialize timeout after waiting 5 seconds");
        _isInitializing = false;
        _initFailed = true;
        _initError = "Initialize timed out";
        return false;
      }
      return _initialized;
    }

    _isInitializing = true;
    _initFailed = false;
    _initError = null;

    try {
      debugPrint("Initializing Solana Swap Service...");

      // Create JS runtime if not already created
      try {
        if (_jsRuntime == null) {
          _jsRuntime = getJavascriptRuntime();
          // Add debug logging for JS console outputs
          _jsRuntime!.onMessage('console', (dynamic args) {
            debugPrint("JS Console: $args");
          });
        }
      } catch (e) {
        throw Exception("Failed to create JavaScript runtime: $e");
      }

      // Basic test of JS runtime
      try {
        JsEvalResult testResult = jsRuntime.evaluate('2 + 2');
        if (testResult.stringResult != '4') {
          throw Exception('JS runtime test failed: ${testResult.stringResult}');
        }
        debugPrint("JS runtime basic test passed");
      } catch (e) {
        throw Exception("JS runtime basic test failed: $e");
      }

      // Load necessary JS libraries with enhanced error handling
      try {
        await _loadJsLibraries();
        debugPrint("JS libraries loaded successfully");
      } catch (e) {
        throw Exception("Failed to load JS libraries: $e");
      }

      // Load our swap script
      try {
        await _loadSwapScript();
        debugPrint("Swap script loaded successfully");
      } catch (e) {
        throw Exception("Failed to load swap script: $e");
      }

      // Initialize the dependencies
      try {
        await _initializeDependencies();
        debugPrint("Dependencies initialized successfully");
      } catch (e) {
        throw Exception("Failed to initialize dependencies: $e");
      }

      _initialized = true;
      debugPrint("Solana Swap Service initialized successfully");
      return true;
    } catch (e) {
      _initFailed = true;
      _initError = e.toString();
      debugPrint("Error initializing Solana Swap Service: $e");
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _loadJsLibraries() async {
    try {
      // Load required libraries one by one with error handling
      await _loadJsFile('solana-web3.min.js', 'solanaWeb3');
      await _loadJsFile('bs58.min.js', 'bs58');
      await _loadJsFile('solana-agent-kit.min.js', 'solanaAgentKit');
    } catch (e) {
      debugPrint("Error loading JS libraries: $e");
      throw e;
    }
  }

  Future<void> _loadJsFile(String filename, String globalVarName) async {
    try {
      debugPrint("Loading $filename...");
      String jsCode = await rootBundle.loadString('assets/js/$filename');

      // Try to evaluate with timeout
      JsEvalResult result = await _evaluateWithTimeout(jsCode, 10000); // 10 seconds timeout

      if (result.isError) {
        throw Exception('Error loading $filename: ${result.stringResult}');
      }

      // Verify the global variable exists
      JsEvalResult checkResult = jsRuntime.evaluate('typeof $globalVarName !== "undefined"');
      if (checkResult.stringResult != 'true') {
        throw Exception('$filename loaded but $globalVarName not defined');
      }

      debugPrint("$filename loaded successfully");
    } catch (e) {
      debugPrint("Error loading $filename: $e");
      throw e;
    }
  }
  Future<void> _loadSwapScript() async {
    try {
      debugPrint("Loading swap script...");
      String swapScript = await rootBundle.loadString('assets/js/swap_script.js');

      // Load the original script without modifications
      JsEvalResult scriptResult = await _evaluateWithTimeout(swapScript, 10000); // 10 seconds timeout

      if (scriptResult.isError) {
        throw Exception('Error loading swap script: ${scriptResult.stringResult}');
      }

      // Verify key functions exist
      JsEvalResult checkInitResult = jsRuntime.evaluate('typeof initializeDependencies === "function"');
      if (checkInitResult.stringResult != 'true') {
        throw Exception('Swap script loaded but initializeDependencies function not defined');
      }

      JsEvalResult checkSwapResult = jsRuntime.evaluate('typeof executeSwapWrapper === "function"');
      if (checkSwapResult.stringResult != 'true') {
        throw Exception('Swap script loaded but executeSwapWrapper function not defined');
      }

      // Now, apply our enhancements separately - without redefining functions
      String enhancements = '''
    // Add console shim for better error reporting
    (function() {
      const originalConsoleLog = console.log;
      console.log = function() {
        const args = Array.from(arguments).map(arg => 
          typeof arg === 'object' ? JSON.stringify(arg) : String(arg)
        ).join(' ');
        originalConsoleLog.apply(console, [args]);
      };
    })();
    
    // Add RPC health check function
    async function checkRpcHealth(rpcUrl) {
      try {
        console.log("[RPC] Testing RPC health: " + rpcUrl);
        const response = await fetch(rpcUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            jsonrpc: "2.0",
            id: 1,
            method: "getHealth",
            params: []
          })
        });
        
        const result = await response.json();
        console.log("[RPC] Health check result: " + JSON.stringify(result));
        return result.result === "ok";
      } catch (error) {
        console.log("[RPC] Health check failed: " + error);
        return false;
      }
    }
    
    // Make function available globally
    this.checkRpcHealth = checkRpcHealth;
    
    console.log("[ENHANCEMENTS] Applied successfully");
    ''';

      // Apply the enhancements
      JsEvalResult enhancementsResult = jsRuntime.evaluate(enhancements);
      if (enhancementsResult.isError) {
        debugPrint("Warning: Could not apply JS enhancements: ${enhancementsResult.stringResult}");
        // Continue anyway since this is not critical
      } else {
        debugPrint("JS enhancements applied successfully");
      }

    } catch (e) {
      debugPrint("Error loading swap script: $e");
      throw e;
    }
  }

//   Future<void> _loadSwapScript() async {
//     try {
//       debugPrint("Loading swap script...");
//       String swapScript = await rootBundle.loadString('assets/js/swap_script.js');
//
//       // Add console shim for better error reporting
//       swapScript = '''
// // Console shim for better error reporting
// (function() {
//   const originalConsoleLog = console.log;
//   console.log = function() {
//     const args = Array.from(arguments).map(arg =>
//       typeof arg === 'object' ? JSON.stringify(arg) : String(arg)
//     ).join(' ');
//     originalConsoleLog.apply(console, [args]);
//   };
// })();
//
// $swapScript
//       ''';
//
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
//     } catch (e) {
//       debugPrint("Error loading swap script: $e");
//       throw e;
//     }
//   }

  Future<void> _initializeDependencies() async {
    try {
      debugPrint("Initializing dependencies...");

      // Initialize the dependencies in our JS code with timeout
      final code = 'initializeDependencies(solanaWeb3, solanaAgentKit, bs58)';
      JsEvalResult initResult = await _evaluateWithTimeout(code, 5000); // 5 seconds timeout

      if (initResult.isError) {
        throw Exception('Error initializing dependencies: ${initResult.stringResult}');
      }

      if (initResult.stringResult != 'true') {
        throw Exception('Dependencies initialization failed: ${initResult.stringResult}');
      }
    } catch (e) {
      debugPrint("Error initializing dependencies: $e");
      throw e;
    }
  }

  // Helper method to evaluate JS with timeout
  Future<JsEvalResult> _evaluateWithTimeout(String code, int timeoutMs) async {
    final completer = Completer<JsEvalResult>();
    Timer? timeoutTimer;

    try {
      // Set timeout
      timeoutTimer = Timer(Duration(milliseconds: timeoutMs), () {
        if (!completer.isCompleted) {
          completer.completeError(
              Exception('JavaScript evaluation timed out after $timeoutMs ms')
          );
        }
        // No need to cancel here as this is the timeout callback itself
      });

      // Run evaluation in a microtask to avoid blocking
      Future.microtask(() {
        try {
          final result = jsRuntime.evaluate(code);
          // Cancel timeout timer - using null-aware operator
          timeoutTimer?.cancel();
          timeoutTimer = null;

          if (!completer.isCompleted) {
            completer.complete(result);
          }
        } catch (e) {
          // Cancel timeout timer - using null-aware operator
          timeoutTimer?.cancel();
          timeoutTimer = null;

          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      });

      return await completer.future;
    } catch (e) {
      // Handle any unexpected errors
      timeoutTimer?.cancel();
      timeoutTimer = null;
      throw e;
    }
  }
  // Modified executeSwap with better error handling and safer approach
  // Future<Map<String, dynamic>> executeSwap({
  //   required String publicKey,
  //   required List<int> secretKey,
  //   required String outputMint,
  // }) async {
  //   if (!_initialized) {
  //     final initSuccess = await initialize();
  //     if (!initSuccess) {
  //       return {
  //         'success': false,
  //         'error': 'Failed to initialize Solana Swap Service: $_initError',
  //       };
  //     }
  //   }
  //
  //   // Declare timer outside try block so it can be accessed in finally
  //   Timer? heartbeatTimer;
  //
  //   try {
  //     // Check JS runtime health first
  //     try {
  //       JsEvalResult healthCheck = jsRuntime.evaluate('2 + 2');
  //       if (healthCheck.stringResult != '4') {
  //         throw Exception('JS runtime health check failed');
  //       }
  //     } catch (e) {
  //       debugPrint("JS runtime health check failed: $e");
  //       return {
  //         'success': false,
  //         'error': 'JavaScript runtime is not healthy: $e',
  //       };
  //     }
  //
  //     // Create a keypair object that matches the JS structure
  //     final keypair = {
  //       'publicKey': publicKey,
  //       'secretKey': secretKey,
  //     };
  //
  //     // Convert to JSON string, but escape properly for JS string
  //     final keypairJson = jsonEncode(keypair).replaceAll("'", "\\'");
  //
  //     debugPrint("Executing swap with parameters:");
  //     debugPrint("  Output Mint: $outputMint");
  //     debugPrint("  Public Key: $publicKey");
  //     debugPrint("  Secret Key: [${secretKey.length} bytes]");
  //
  //     // Create a unique callback channel for this swap
  //     final callbackChannel = "swap_result_${DateTime.now().millisecondsSinceEpoch}";
  //     final completer = Completer<Map<String, dynamic>>();
  //
  //     bool receivedResponse = false;
  //
  //     // Register the callback to receive results
  //     jsRuntime.onMessage(callbackChannel, (dynamic resultData) {
  //       debugPrint("Received data on channel $callbackChannel: $resultData");
  //       receivedResponse = true;
  //
  //       try {
  //         // Safely cancel the timer - using null-aware operator
  //         heartbeatTimer?.cancel();
  //         heartbeatTimer = null;
  //
  //         Map<String, dynamic> swapResult;
  //         if (resultData is String) {
  //           swapResult = jsonDecode(resultData);
  //         } else {
  //           swapResult = Map<String, dynamic>.from(resultData as Map);
  //         }
  //
  //         if (!completer.isCompleted) {
  //           completer.complete(swapResult);
  //         }
  //       } catch (e) {
  //         debugPrint("Error parsing callback data: $e");
  //         if (!completer.isCompleted) {
  //           completer.completeError(e);
  //         }
  //       }
  //     });
  //
  //     // Set up a safer heartbeat timer with less frequency
  //     heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (t) {
  //       if (!receivedResponse) {
  //         try {
  //           // Simple test that doesn't stress the JS engine
  //           final heartbeatResult = jsRuntime.evaluate('1 + 1');
  //           debugPrint("JS heartbeat check: ${heartbeatResult.stringResult}");
  //         } catch (e) {
  //           debugPrint("JS engine heartbeat failed: $e");
  //           if (!completer.isCompleted) {
  //             completer.complete({
  //               'success': false,
  //               'error': 'JS engine became unresponsive: $e',
  //             });
  //           }
  //           t.cancel();
  //         }
  //       } else {
  //         t.cancel();
  //       }
  //     });
  //
  //     // Call the existing executeSwapWrapper function directly
  //     final jsCode = '''
  //   try {
  //     console.log("[DART] Calling executeSwapWrapper");
  //     executeSwapWrapper('$keypairJson', '$outputMint', '$callbackChannel');
  //   } catch (error) {
  //     console.log("[DART] Error in swap execution:", error);
  //     try {
  //       postMessage("$callbackChannel", JSON.stringify({
  //         success: false,
  //         error: "Error in JS execution: " + (error.message || String(error))
  //       }));
  //     } catch (postError) {
  //       console.log("[DART] Failed to send error:", postError);
  //     }
  //     throw error;
  //   }
  //   ''';
  //
  //     debugPrint("Executing JS safely...");
  //
  //     try {
  //       JsEvalResult initResult = await _evaluateWithTimeout(jsCode, 10000); // 10 second timeout
  //
  //       if (initResult.isError) {
  //         heartbeatTimer?.cancel();
  //         heartbeatTimer = null;
  //
  //         debugPrint("JS Error during swap initialization: ${initResult.stringResult}");
  //         return {
  //           'success': false,
  //           'error': 'Error executing swap: ${initResult.stringResult}',
  //         };
  //       }
  //
  //       debugPrint("Swap initiated successfully");
  //     } catch (e) {
  //       heartbeatTimer?.cancel();
  //       heartbeatTimer = null;
  //
  //       debugPrint("JS execution error: $e");
  //       return {
  //         'success': false,
  //         'error': 'JavaScript execution error: $e',
  //       };
  //     }
  //
  //     // Wait for the callback with timeout
  //     try {
  //       final result = await completer.future.timeout(
  //         const Duration(minutes: 3),
  //         onTimeout: () {
  //           debugPrint("Swap operation timed out after 3 minutes");
  //
  //           // Safely cancel the timer
  //           heartbeatTimer?.cancel();
  //           heartbeatTimer = null;
  //
  //           // Try one last status check
  //           try {
  //             jsRuntime.evaluate('console.log("[TIMEOUT] Swap operation status check")');
  //           } catch (e) {
  //             debugPrint("JS engine status check failed: $e");
  //           }
  //
  //           return {
  //             'success': false,
  //             'error': 'Swap operation timed out after 3 minutes. The transaction may still complete on the blockchain.',
  //           };
  //         },
  //       );
  //
  //       // Cleanup
  //       heartbeatTimer?.cancel();
  //       heartbeatTimer = null;
  //
  //       debugPrint("Final swap result: $result");
  //       return result;
  //     } catch (e) {
  //       // Cleanup
  //       heartbeatTimer?.cancel();
  //       heartbeatTimer = null;
  //
  //       debugPrint("Error waiting for swap result: $e");
  //       return {
  //         'success': false,
  //         'error': 'Error processing swap result: $e',
  //       };
  //     }
  //   } catch (e) {
  //     // Cleanup
  //     heartbeatTimer?.cancel();
  //     heartbeatTimer = null;
  //
  //     debugPrint("Top-level error in executeSwap: $e");
  //     return {
  //       'success': false,
  //       'error': 'Unexpected error: $e',
  //     };
  //   }
  // }
  Future<Map<String, dynamic>> executeSwap({
    required String publicKey,
    required List<int> secretKey,
    required String outputMint,
    required double solBalance, // Add this parameter
  }) async {
    if (!_initialized) {
      final initSuccess = await initialize();
      if (!initSuccess) {
        return {
          'success': false,
          'error': 'Failed to initialize Solana Swap Service: $_initError',
        };
      }
    }

    // Declare timer outside try block so it can be accessed in finally
    Timer? heartbeatTimer;

    try {
      // Create a keypair object that matches the JS structure
      final keypair = {
        'publicKey': publicKey,
        'secretKey': secretKey,
      };

      // Convert to JSON string, but escape properly for JS string
      final keypairJson = jsonEncode(keypair).replaceAll("'", "\\'");

      debugPrint("Executing swap with parameters:");
      debugPrint("  Output Mint: $outputMint");
      debugPrint("  Public Key: $publicKey");
      debugPrint("  Secret Key: [${secretKey.length} bytes]");
      debugPrint("  SOL Balance: $solBalance"); // Log the provided balance

      // Create a unique callback channel for this swap
      final callbackChannel = "swap_result_${DateTime.now().millisecondsSinceEpoch}";
      final completer = Completer<Map<String, dynamic>>();

      bool receivedResponse = false;

      // Register the callback to receive results
      jsRuntime.onMessage(callbackChannel, (dynamic resultData) {
        debugPrint("Received data on channel $callbackChannel: $resultData");
        receivedResponse = true;

        try {
          // Safely cancel the timer
          heartbeatTimer?.cancel();
          heartbeatTimer = null;

          Map<String, dynamic> swapResult;
          if (resultData is String) {
            swapResult = jsonDecode(resultData);
          } else {
            swapResult = Map<String, dynamic>.from(resultData as Map);
          }

          if (!completer.isCompleted) {
            completer.complete(swapResult);
          }
        } catch (e) {
          debugPrint("Error parsing callback data: $e");
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      });

      // Set up a simple heartbeat timer
      heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (t) {
        if (!receivedResponse) {
          try {
            // Simple test that doesn't stress the JS engine
            final heartbeatResult = jsRuntime.evaluate('1 + 1');
            debugPrint("JS heartbeat check: ${heartbeatResult.stringResult}");
          } catch (e) {
            debugPrint("JS engine heartbeat failed: $e");
            if (!completer.isCompleted) {
              completer.complete({
                'success': false,
                'error': 'JS engine became unresponsive: $e',
              });
            }
            t.cancel();
          }
        } else {
          t.cancel();
        }
      });

      // Modify this to bypass the balance check in JS and directly execute the trade
      final jsCode = '''
    try {
      console.log("[DART] Starting direct swap with pre-verified balance: $solBalance SOL");
      
      // Skip the balance check in JavaScript and use the pre-verified balance from Dart
      const continueWithPreVerifiedBalance = async () => {
        try {
          // Extract keypair
          const keypairData = JSON.parse('$keypairJson');
          const userKeypair = {
            publicKey: keypairData.publicKey,
            secretKey: new Uint8Array(Object.values(keypairData.secretKey))
          };
          
          console.log("[SWAP] Using keypair with publicKey:", userKeypair.publicKey);
          
          // Create a connection
          const rpcUrl = 'https://frosty-maximum-dawn.solana-mainnet.quiknode.pro/5b5a5d932ff429c60633ec8a5239eeeb8fd859eb';
          const connection = new Connection(rpcUrl, 'confirmed');
          
          // Create PublicKey for the output mint
          const outputMintPublicKey = new PublicKey('$outputMint');
          
          // Initialize Agent Kit using the provided keypair
          const privateKeyBase58 = bs58.encode(userKeypair.secretKey);
          const agent = new SolanaAgentKit(privateKeyBase58, rpcUrl, { JUPITER_FEE_BPS: 0 });
          
          // Calculate swap amount (5% of balance)
          const rawAmount = $solBalance * 0.05;
          const roundedAmount = Math.floor(rawAmount * 100000) / 100000;
          
          // Safety checks
          const MIN_SOL_RESERVE = 0.005;
          let finalAmount = roundedAmount;
          
          if (finalAmount > ($solBalance - MIN_SOL_RESERVE)) {
            finalAmount = Math.max(0, $solBalance - MIN_SOL_RESERVE);
            console.log("[SWAP] Adjusted amount to " + finalAmount + " SOL to keep reserve");
          }
          
          if (finalAmount <= 0) {
            postMessage("$callbackChannel", JSON.stringify({
              success: false,
              error: "Insufficient balance for swap after keeping minimum reserve"
            }));
            return;
          }
          
          console.log("[SWAP] Amount to swap:", finalAmount, "SOL");
          
          // Execute the trade
          const inputMint = new PublicKey('So11111111111111111111111111111111111111112'); // SOL
          const slippage = 50; // 0.5%
          const amountStr = finalAmount.toFixed(9);
          
          console.log("[SWAP] Executing trade:", amountStr, "SOL ->", '$outputMint');
          
          // Call the trade method
          agent.trade(outputMintPublicKey, amountStr, inputMint, slippage)
            .then(txSignature => {
              console.log("[SWAP] Trade successful! Signature:", txSignature);
              
              postMessage("$callbackChannel", JSON.stringify({
                success: true,
                signature: txSignature,
                amount: finalAmount,
                inputMint: "SOL",
                outputMint: '$outputMint'
              }));
            })
            .catch(tradeError => {
              console.log("[SWAP] Trade error:", tradeError);
              postMessage("$callbackChannel", JSON.stringify({
                success: false,
                error: "Trade failed: " + (tradeError.message || JSON.stringify(tradeError))
              }));
            });
        } catch (error) {
          console.log("[SWAP] Error in direct execution:", error);
          postMessage("$callbackChannel", JSON.stringify({
            success: false,
            error: "Error in swap execution: " + (error.message || JSON.stringify(error))
          }));
        }
      };
      
      // Execute without balance check
      continueWithPreVerifiedBalance();
      
      // Return immediate status
      "Direct swap initiated";
    } catch (error) {
      console.log("[SWAP] Top-level error in direct swap:", error);
      postMessage("$callbackChannel", JSON.stringify({
        success: false,
        error: "Error executing swap: " + (error.message || JSON.stringify(error))
      }));
      "Error: " + error.message;
    }
    ''';

      debugPrint("Executing direct swap JS code...");

      try {
        JsEvalResult initResult = jsRuntime.evaluate(jsCode);

        if (initResult.isError) {
          heartbeatTimer?.cancel();
          heartbeatTimer = null;

          debugPrint("JS Error during swap execution: ${initResult.stringResult}");
          return {
            'success': false,
            'error': 'Error executing swap: ${initResult.stringResult}',
          };
        }

        debugPrint("Swap initiated with result: ${initResult.stringResult}");
      } catch (e) {
        heartbeatTimer?.cancel();
        heartbeatTimer = null;

        debugPrint("JS execution error: $e");
        return {
          'success': false,
          'error': 'JavaScript execution error: $e',
        };
      }

      // Wait for the callback with timeout
      try {
        final result = await completer.future.timeout(
          const Duration(minutes: 3),
          onTimeout: () {
            debugPrint("Swap operation timed out after 3 minutes");

            // Safely cancel the timer
            heartbeatTimer?.cancel();
            heartbeatTimer = null;

            return {
              'success': false,
              'error': 'Swap operation timed out after 3 minutes. The transaction may still complete on the blockchain.',
            };
          },
        );

        // Cleanup
        heartbeatTimer?.cancel();
        heartbeatTimer = null;

        debugPrint("Final swap result: $result");
        return result;
      } catch (e) {
        // Cleanup
        heartbeatTimer?.cancel();
        heartbeatTimer = null;

        debugPrint("Error waiting for swap result: $e");
        return {
          'success': false,
          'error': 'Error processing swap result: $e',
        };
      }
    } catch (e) {
      // Cleanup
      heartbeatTimer?.cancel();
      heartbeatTimer = null;

      debugPrint("Top-level error in executeSwap: $e");
      return {
        'success': false,
        'error': 'Unexpected error: $e',
      };
    }
  }
}
