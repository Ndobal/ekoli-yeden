import 'package:flutter/material.dart';

import 'state_views.dart';

/// Renders a future with the three states every archive screen needs:
/// loading, failed, and loaded — including loaded-but-empty, which on this site
/// is the normal state of most sections until the community fills them.
class AsyncContent<T> extends StatefulWidget {
  const AsyncContent({
    required this.load,
    required this.builder,
    this.loadingMessage,
    this.isEmpty,
    this.emptyBuilder,
    super.key,
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;
  final String? loadingMessage;

  /// Decides whether the loaded value should render as empty.
  final bool Function(T data)? isEmpty;
  final WidgetBuilder? emptyBuilder;

  @override
  State<AsyncContent<T>> createState() => _AsyncContentState<T>();
}

class _AsyncContentState<T> extends State<AsyncContent<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  @override
  void didUpdateWidget(covariant AsyncContent<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new `load` closure means the query changed — a different filter, a new
    // page — so the request is reissued rather than showing stale results.
    if (oldWidget.load != widget.load) _reload();
  }

  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<T> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingView(message: widget.loadingMessage);
        }
        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error!, onRetry: _reload);
        }
        if (!snapshot.hasData) {
          return const EmptyView();
        }

        final T data = snapshot.data as T;
        if (widget.isEmpty?.call(data) ?? false) {
          return widget.emptyBuilder?.call(context) ?? const EmptyView();
        }
        return widget.builder(context, data);
      },
    );
  }
}
