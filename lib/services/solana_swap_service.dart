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