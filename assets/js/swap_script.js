// Dependency initializer
function initializeDependencies(web3Lib, agentKitLib, bs58Lib) {
  try {
    console.log('[INIT] Starting dependency initialization');
    if (!web3Lib || !agentKitLib || !bs58Lib) throw new Error('Missing library');
    Connection = web3Lib.Connection;
    PublicKey = web3Lib.PublicKey;
    LAMPORTS_PER_SOL = web3Lib.LAMPORTS_PER_SOL;
    SolanaAgentKit = agentKitLib.SolanaAgentKit;
    bs58 = bs58Lib;
    if (!Connection || !PublicKey || !LAMPORTS_PER_SOL || !SolanaAgentKit || !bs58) {
      throw new Error('Dependency validation failed');
    }
    console.log('[INIT] Dependencies initialized successfully');
    return true;
  } catch (error) {
    console.log('[INIT] Error initializing dependencies:', error);
    return false;
  }
}

// Main swap function: sends a real on-chain trade via agentKit
async function executeSwap(userKeypair, outputMint, callbackChannel) {
  try {
    const rpcUrl = 'https://api.mainnet-beta.solana.com';
    // 1) RPC health
    const healthy = await checkRpcHealth(rpcUrl);
    if (!healthy) {
      return postMessage(callbackChannel, JSON.stringify({ success: false, error: 'RPC endpoint unhealthy' }));
    }

    console.log('[SWAP] Creating connection...');
    const connection = new Connection(rpcUrl, 'confirmed');

    // 2) Build PublicKey instances
    const userPubKey = new PublicKey(userKeypair.publicKey);
    console.log('[SWAP] User PublicKey:', userPubKey.toString());

    // 3) Encode secret and init agentKit
    const secretBase58 = bs58.encode(new Uint8Array(userKeypair.secretKey));
    const agent = new SolanaAgentKit(secretBase58, rpcUrl, { JUPITER_FEE_BPS: 0 });
    console.log('[SWAP] SolanaAgentKit initialized');

    // 4) Determine swap amount (5% of balance keeping a reserve)
    let balLamports = await connection.getBalance(userPubKey);
    let solBal = balLamports / LAMPORTS_PER_SOL;
    console.log('[SWAP] Retrieved SOL balance:', solBal);
    const reserve = 0.005;
    let rawAmt = solBal * 0.05;
    let swapAmt = Math.max(0, rawAmt - reserve);
    if (swapAmt <= 0) {
      return postMessage(callbackChannel, JSON.stringify({ success: false, error: 'Insufficient balance after reserve' }));
    }
    const amountStr = swapAmt.toFixed(9);
    console.log('[SWAP] Swap amount:', amountStr);

    // 5) Prepare mints and slippage
    const inputMint = new PublicKey('So11111111111111111111111111111111111111112'); // SOL
    const outputPk = new PublicKey(outputMint);
    const slippageBps = 50; // 0.5%

    // 6) Execute trade
    console.log('[SWAP] Executing trade via agent.trade');
    agent.trade(outputPk, amountStr, inputMint, slippageBps)
      .then(txSig => {
        console.log('[SWAP] Real trade signature:', txSig);
        postMessage(callbackChannel, JSON.stringify({
          success: true,
          signature: txSig,
          amount: parseFloat(amountStr),
          inputMint: 'SOL',
          outputMint: outputMint
        }));
      })
      .catch(err => {
        console.log('[SWAP] Trade failed:', err);
        postMessage(callbackChannel, JSON.stringify({ success: false, error: err.message || String(err) }));
      });

  } catch (error) {
    console.log('[SWAP] Top-level error in executeSwap:', error);
    postMessage(callbackChannel, JSON.stringify({ success: false, error: String(error) }));
  }
}

// Wrapper to parse Dart JSON and dispatch to executeSwap
function executeSwapWrapper(keypairJson, outputMint, callbackChannel) {
  try {
    console.log('[SWAP] executeSwapWrapper:', outputMint);
    const data = JSON.parse(keypairJson);
    const userKeypair = { publicKey: data.publicKey, secretKey: new Uint8Array(Object.values(data.secretKey)) };
    executeSwap(userKeypair, outputMint, callbackChannel);
    return 'Swap initiated';
  } catch (e) {
    console.log('[SWAP] Error in executeSwapWrapper:', e);
    postMessage(callbackChannel, JSON.stringify({ success: false, error: e.message || String(e) }));
    return 'Error';
  }
}

// Expose functions globally
this.checkRpcHealth = checkRpcHealth;
this.initializeDependencies = initializeDependencies;
this.executeSwap = executeSwap;
this.executeSwapWrapper = executeSwapWrapper;
