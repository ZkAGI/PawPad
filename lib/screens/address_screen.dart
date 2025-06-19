// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:solana/solana.dart';
// import 'package:web3dart/credentials.dart';
// import '../services/agent_provider.dart';
//
// class AddressesScreen extends StatefulWidget {
//   const AddressesScreen({Key? key}) : super(key: key);
//
//   @override
//   State<AddressesScreen> createState() => _AddressesScreenState();
// }
//
// class _AddressesScreenState extends State<AddressesScreen> {
//   String? _solanaAddr;
//   String? _ethereumAddr;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadAddrs();
//   }
//
//   Future<void> _loadAddrs() async {
//     final agentProv = Provider.of<AgentProvider>(context, listen: false);
//     final both     = await agentProv.getOrCreateBothWallets();
//     final sol      = both['solana'] as Ed25519HDKeyPair;
//     final evm      = both['evm']    as EthPrivateKey;
//     final ethAddr  = (await evm.extractAddress()).hexEip55;
//
//     setState(() {
//       _solanaAddr   = sol.address;
//       _ethereumAddr = ethAddr;
//     });
//   }
//
//   String _shorten(String a, {int head = 5, int tail = 4}) =>
//       a.length > head + tail
//           ? '${a.substring(0, head)}…${a.substring(a.length - tail)}'
//           : a;
//
//   Widget _buildRow({
//     required String logoAsset,
//     required String title,
//     String? address,
//   }) {
//     return ListTile(
//       leading: Image.asset(logoAsset, width: 32, height: 32),
//       title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
//       subtitle: Text(address == null ? 'Loading…' : _shorten(address)),
//       trailing: IconButton(
//         icon: const Icon(Icons.copy),
//         onPressed: address == null
//             ? null
//             : () {
//           // Now address is non-null, so we can safely use !
//           Clipboard.setData(ClipboardData(text: address));
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('$title address copied')),
//           );
//         },
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         leading: const BackButton(),
//         title: const Text('Your addresses'),
//       ),
//       body: Column(
//         children: [
//           const SizedBox(height: 16),
//           _buildRow(
//             logoAsset: 'assets/images/eth_logo.png',
//             title:     'Ethereum',
//             address:   _ethereumAddr,
//           ),
//           const Divider(),
//           _buildRow(
//             logoAsset: 'assets/images/solana_logo.png',
//             title:     'Solana',
//             address:   _solanaAddr,
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/agent_provider.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({Key? key}) : super(key: key);

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  String? _solanaAddr, _ethereumAddr;

  @override
  void initState() {
    super.initState();
    _loadAddrs();
  }

  Future<void> _loadAddrs() async {
    final agent = Provider.of<AgentProvider>(context, listen: false);
    final both  = await agent.getOrCreateBothWallets();
    final sol   = both['solana'] as dynamic;
    final evm   = both['evm']    as dynamic;
    final eth   = (await evm.extractAddress()).hexEip55;

    setState(() {
      _solanaAddr   = sol.address;
      _ethereumAddr = eth;
    });
  }

  String _shorten(String a, {int head = 5, int tail = 4}) =>
      a.length > head + tail
          ? '${a.substring(0, head)}…${a.substring(a.length - tail)}'
          : a;

  Widget _buildRow({
    required String logoAsset,
    required String title,
    String? address,
  }) {
    return ListTile(
      leading: Image.asset(
        logoAsset,
        width: 32,
        height: 32,
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        address == null ? 'Loading…' : _shorten(address),
        style: const TextStyle(color: Colors.white70),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy, color: Colors.white),
        onPressed: address == null
            ? null
            : () {
          Clipboard.setData(ClipboardData(text: address));
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$title address copied')));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Your addresses', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          _buildRow(
            logoAsset: 'assets/images/eth_logo.png',
            title: 'Ethereum',
            address: _ethereumAddr,
          ),
          const Divider(color: Colors.white24),
          _buildRow(
            logoAsset: 'assets/images/solana_logo.png',
            title: 'Solana',
            address: _solanaAddr,
          ),
        ],
      ),
    );
  }
}
