import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';

/// Loading / error (with retry) / data wrapper for FutureProviders.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.onRetry, required this.builder});
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isNoInternet(e) ? Icons.wifi_off : Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(friendlyError(e), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: builder,
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(text, textAlign: TextAlign.center)));
}
