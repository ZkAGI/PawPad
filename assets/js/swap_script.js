// Real swap implementation adapted for flutter_js
// Globals for dependencies
var Connection;
var PublicKey;
var LAMPORTS_PER_SOL;
var SolanaAgentKit;
var bs58;

// At the very top of swap_script.js, before you ever call sendMessage...
// Use a namespaced version of sendMessage to avoid conflicts
let solanaSwapSendMessage;
if (typeof sendMessage !== 'undefined') {
  // Use the existing sendMessage if available
  solanaSwapSendMessage = sendMessage;
} else {
  // Define our own version if it doesn't exist
  solanaSwapSendMessage = (channel, message) => {
    try {
      postMessage(channel, message);
    } catch (e) {
      // if bridging isn't present, silently drop it
    }
  };
  // Make it available globally
  this.sendMessage = solanaSwapSendMessage;
}


// Initialize dependencies
//function initializeDependencies(web3Lib, agentKitLib, bs58Lib) {
//  try {
//    // Set globals from passed libraries
//    Connection = web3Lib.Connection;
//    PublicKey = web3Lib.PublicKey;
//    LAMPORTS_PER_SOL = web3Lib.LAMPORTS_PER_SOL;
//    SolanaAgentKit = agentKitLib.SolanaAgentKit;
//    bs58 = bs58Lib;
//
//    console.log("[INIT] Dependencies initialized successfully");
//    return true;
//  } catch (error) {
//    console.log("[INIT] Error initializing dependencies:", error);
//    return false;
//  }
//}

function initializeDependencies(web3Lib, agentKitLib, bs58Lib) {
  try {
    console.log("[INIT] Starting dependency initialization");

    // Validate inputs
    if (!web3Lib) throw new Error("web3Lib is undefined");
    if (!agentKitLib) throw new Error("agentKitLib is undefined");
    if (!bs58Lib) throw new Error("bs58Lib is undefined");

    // Set globals from passed libraries
    Connection = web3Lib.Connection;
    PublicKey = web3Lib.PublicKey;
    LAMPORTS_PER_SOL = web3Lib.LAMPORTS_PER_SOL;
    SolanaAgentKit = agentKitLib.SolanaAgentKit;
    bs58 = bs58Lib;

    // Verify critical components
    if (!Connection) throw new Error("Connection is undefined");
    if (!PublicKey) throw new Error("PublicKey is undefined");
    if (!LAMPORTS_PER_SOL) throw new Error("LAMPORTS_PER_SOL is undefined");
    if (!SolanaAgentKit) throw new Error("SolanaAgentKit is undefined");
    if (!bs58) throw new Error("bs58 is undefined");

    console.log("[INIT] Dependencies initialized successfully");
    return true;
  } catch (error) {
    console.log("[INIT] Error initializing dependencies:", error);
    return false;
  }
}

async function checkRpcHealth(rpcUrl) {
  try {
    console.log(`[RPC] Testing RPC health: ${rpcUrl}`);
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
    console.log(`[RPC] Health check result: ${JSON.stringify(result)}`);
    return result.result === "ok";
  } catch (error) {
    console.log(`[RPC] Health check failed: ${error}`);
    return false;
  }
}


// Main swap function - NO SIMULATION
function executeSwap(userKeypair, outputMint, callbackChannel) {
  try {
    var rpcUrl = 'https://frosty-maximum-dawn.solana-mainnet.quiknode.pro/5b5a5d932ff429c60633ec8a5239eeeb8fd859eb';

      checkRpcHealth(rpcUrl).then(isHealthy => {
          if (!isHealthy) {
            console.log("[SWAP] RPC endpoint is not healthy");
            sendMessage(callbackChannel, JSON.stringify({
              success: false,
              error: "RPC endpoint is not healthy or unresponsive"
            }));
            return;
          }

          // Continue with swap if RPC is healthy
          proceedWithSwap();
        }).catch(error => {
          console.log("[SWAP] Error checking RPC health:", error);
          sendMessage(callbackChannel, JSON.stringify({
            success: false,
            error: "Failed to check RPC health: " + error.message
          }));
        });

    console.log("[SWAP] Creating connection...");
    var connection = new Connection(rpcUrl, 'confirmed');
    console.log("[SWAP] Connection created successfully");

    // Get the wallet address from the passed keypair
    var walletAddress = userKeypair.publicKey;
    console.log("[SWAP] Selected wallet address:", walletAddress);

    // Create PublicKey from the wallet address
    var userPublicKey;
    try {
      userPublicKey = new PublicKey(walletAddress);
      console.log("[SWAP] PublicKey created successfully:", userPublicKey.toString());
      console.log("[SWAP] PublicKey constructor type:", typeof PublicKey);

      // Check if PublicKey was correctly instantiated
      if (typeof userPublicKey !== 'object') {
        throw new Error("PublicKey not created correctly - returned " + typeof userPublicKey);
      }
    } catch (pkError) {
      console.log("[SWAP] Error creating PublicKey:", pkError);
      sendMessage(callbackChannel, JSON.stringify({
        success: false,
        error: "Failed to create PublicKey: " + pkError.message
      }));
      return;
    }

    // Encode private key
    var privateKeyBase58;
    try {
      privateKeyBase58 = bs58.encode(new Uint8Array(userKeypair.secretKey));
      console.log("[SWAP] PrivateKey encoded successfully, length:", privateKeyBase58.length);
    } catch (encodeError) {
      console.log("[SWAP] Error encoding private key:", encodeError);
      sendMessage(callbackChannel, JSON.stringify({
        success: false,
        error: "Failed to encode private key: " + encodeError.message
      }));
      return;
    }

    // Initialize SolanaAgentKit with the wallet's private key
    var agent;
    try {
      agent = new SolanaAgentKit(privateKeyBase58, rpcUrl, { JUPITER_FEE_BPS: 0 });
      console.log("[SWAP] SolanaAgentKit initialized successfully");
    } catch (agentError) {
      console.log("[SWAP] Error initializing SolanaAgentKit:", agentError);
      sendMessage(callbackChannel, JSON.stringify({
        success: false,
        error: "Failed to initialize SolanaAgentKit: " + agentError.message
      }));
      return;
    }

    // Get balance from agent directly
    console.log("[SWAP] Attempting to get balance for wallet:", walletAddress);

    // Try using SolanaAgentKit's methods if available
    if (agent.getWalletBalance && typeof agent.getWalletBalance === 'function') {
      console.log("[SWAP] Using agent.getWalletBalance method");

      agent.getWalletBalance()
        .then(function(balance) {
          console.log("[SWAP] Balance retrieved from agent:", balance);
          var solBalance = parseFloat(balance);
          continueWithSwap(solBalance);
        })
        .catch(function(error) {
          console.log("[SWAP] Error getting balance from agent:", error);
          sendMessage(callbackChannel, JSON.stringify({
            success: false,
            error: "Failed to get wallet balance: " + (error.message || JSON.stringify(error))
          }));
        });
    }
    // If agent.getWalletBalance is not available, try connection.getBalance
    else if (connection && connection.getBalance) {
      console.log("[SWAP] Using connection.getBalance with address:", walletAddress);

      // Using the wallet address directly with getBalance
     // Modify the getBalance part:
     connection.getBalance(userPublicKey)
       .then(function(balance) {
         console.log("[SWAP] Balance retrieved from connection:", balance);
         var solBalance = balance / LAMPORTS_PER_SOL;
         continueWithSwap(solBalance);
       })
       .catch(function(error) {
         console.log("[SWAP] Error getting balance from connection:", error);
         console.log("[SWAP] Error details:", JSON.stringify(error));
         sendMessage(callbackChannel, JSON.stringify({
           success: false,
           error: "Failed to get wallet balance: " + (error.message || JSON.stringify(error))
         }));
       });
    }
    // If neither method is available, send an error
    else {
      console.log("[SWAP] No method available to get wallet balance");
      sendMessage(callbackChannel, JSON.stringify({
        success: false,
        error: "No method available to get wallet balance"
      }));
      return;
    }

    // Function to continue with the swap using the retrieved balance
    function continueWithSwap(solBalance) {
      console.log("[SWAP] SOL balance for selected wallet:", solBalance);

      // Fail if no balance is available
      if (solBalance <= 0) {
        sendMessage(callbackChannel, JSON.stringify({
          success: false,
          error: "No SOL balance available for swap in the selected wallet"
        }));
        return;
      }

      // Calculate 5% of user's SOL balance
      var rawAmount = solBalance * 0.05;
      var roundedAmount = Math.floor(rawAmount * 100000) / 100000;

      // Safety checks
      const MIN_SOL_RESERVE = 0.005;
      if (roundedAmount > (solBalance - MIN_SOL_RESERVE)) {
        roundedAmount = Math.max(0, solBalance - MIN_SOL_RESERVE);
        console.log(`[SWAP] Adjusted amount to ${roundedAmount} SOL to keep reserve`);
      }

      if (roundedAmount <= 0) {
        sendMessage(callbackChannel, JSON.stringify({
          success: false,
          error: "Insufficient balance for swap after keeping minimum reserve"
        }));
        return;
      }

      console.log("[SWAP] Amount to swap:", roundedAmount, "SOL");

      var inputMint = new PublicKey('So11111111111111111111111111111111111111112'); // SOL
      var outputMintPublicKey;

      try {
        outputMintPublicKey = new PublicKey(outputMint);
        console.log("[SWAP] Output mint PublicKey created:", outputMintPublicKey.toString());
      } catch (outputError) {
        console.log("[SWAP] Error creating output mint PublicKey:", outputError);
        sendMessage(callbackChannel, JSON.stringify({
          success: false,
          error: "Failed to create output mint PublicKey: " + outputError.message
        }));
        return;
      }

      var slippage = 50; // 0.5%
      console.log("[SWAP] Initiating token swap:", roundedAmount, "SOL ->", outputMint);
      var amountStr = roundedAmount.toFixed(9);

      // Execute the trade with the selected wallet
      agent.trade(outputMintPublicKey, amountStr, inputMint, slippage)
        .then(function(txSignature) {
          console.log("[SWAP] Trade successful! Signature:", txSignature);

          sendMessage(callbackChannel, JSON.stringify({
            success: true,
            signature: txSignature,
            amount: roundedAmount,
            inputMint: "SOL",
            outputMint: outputMint
          }));
        })
        .catch(function(tradeError) {
          console.log("[SWAP] Trade error:", tradeError);
          sendMessage(callbackChannel, JSON.stringify({
            success: false,
            error: "Trade failed: " + (tradeError.message || JSON.stringify(tradeError))
          }));
        });
    }

    // Return immediately with a "processing" status
    return "processing";

  } catch (error) {
    console.log("[SWAP] Top-level error in executeSwap:", error);
    sendMessage(callbackChannel, JSON.stringify({
      success: false,
      error: "Error executing swap: " + (error.message || JSON.stringify(error))
    }));
    return "error";
  }
}

// Wrapper function
function executeSwapWrapper(keypairJson, outputMint, callbackChannel) {
  try {
    console.log("[SWAP] Executing swap wrapper with outputMint:", outputMint);

    // Parse the keypair JSON
    var keypairData = JSON.parse(keypairJson);
    console.log("[SWAP] Parsed keypair data, publicKey:", keypairData.publicKey);

    // Create keypair object with the selected wallet's information
    var userKeypair = {
      publicKey: keypairData.publicKey,
      secretKey: new Uint8Array(Object.values(keypairData.secretKey))
    };
    console.log("[SWAP] Created userKeypair object with secretKey length:", userKeypair.secretKey.length);

    // Execute the swap with the selected wallet
    executeSwap(userKeypair, outputMint, callbackChannel);

    // Return immediate status
    return "Swap initiated with selected wallet";
  } catch (error) {
    console.log("[SWAP] Error in executeSwapWrapper:", error);
    sendMessage(callbackChannel, JSON.stringify({
      success: false,
      error: "Failed to process swap parameters: " + (error.message || JSON.stringify(error))
    }));
    return "Error: " + error.message;
  }
}

// Make functions available globally
this.initializeDependencies = initializeDependencies;
this.executeSwap = executeSwap;
this.executeSwapWrapper = executeSwapWrapper;