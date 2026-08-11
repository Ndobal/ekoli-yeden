/// Envelopes returned by the Cloudflare Worker API.
///
/// Every endpoint answers `{ success, data }` or `{ success: false, error }`,
/// so the client parses one shape rather than a different one per screen.
class ApiResult<T> {
  const ApiResult({required this.data, this.meta});

  final T data;
  final Map<String, dynamic>? meta;
}

/// A page of results from a list endpoint.
class PaginatedResult<T> {
  const PaginatedResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  factory PaginatedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final List<dynamic> raw = (json['items'] as List<dynamic>?) ?? const <dynamic>[];
    return PaginatedResult<T>(
      items: raw
          .whereType<Map<String, dynamic>>()
          .map(parse)
          .toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? 1,
      perPage: (json['perPage'] as num?)?.toInt() ?? raw.length,
      total: (json['total'] as num?)?.toInt() ?? raw.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  /// The empty page, which is the correct state for a section of the archive
  /// that the community has not filled in yet.
  static PaginatedResult<T> empty<T>() => PaginatedResult<T>(
    items: const <Never>[],
    page: 1,
    perPage: 0,
    total: 0,
    totalPages: 0,
  );

  final List<T> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  bool get hasMore => page < totalPages;
}
