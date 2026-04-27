import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/session_service.dart';
import '../home/home_shell.dart';

class TokenLoginScreen extends StatefulWidget {
  const TokenLoginScreen({super.key});

  @override
  State<TokenLoginScreen> createState() => _TokenLoginScreenState();
}

class _TokenLoginScreenState extends State<TokenLoginScreen> {
  final _tokenController =
      TextEditingController(text: DevConstants.defaultToken);
  final _dbController = TextEditingController(text: 'client_hrms_demo');

  Future<void> _login() async {
    final session = context.read<SessionService>();
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    await session.saveCompany(
      saasUrl: session.saasUrl,
      companyCode: session.companyCode,
      clientUrl: session.clientUrl,
      clientDb: _dbController.text.trim(),
    );
    await session.saveToken(token);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.token_rounded,
                    size: 56, color: AppTheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Token Login',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.clientUrl.isNotEmpty
                      ? 'Server: ${session.clientUrl}'
                      : '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _dbController,
                  decoration: const InputDecoration(
                    labelText: 'Database',
                    prefixIcon: Icon(Icons.storage_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tokenController,
                  decoration: const InputDecoration(
                    labelText: 'API Token',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _login,
                    child: const Text('Sign In'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
