import '../models/calendar_entry.dart';
import '../services/api/api_client.dart';

/// WHAT IS HAPPENING.
///
/// Events and festivals merged into one calendar by the server, because they
/// are two records and one question.
class EventRepository {
  const EventRepository(this._api);

  final ApiClient _api;

  /// Everything happening, split into upcoming, undated and past.
  ///
  /// `type` narrows it to one kind of occasion — town hall meetings, burials,
  /// launches. Festivals drop out of a filtered list unless the filter is
  /// festivals, so asking for town halls does not keep returning Leboku.
  Future<EventsCalendar> calendar({String? type}) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/events/calendar',
      authenticated: false,
      query: <String, dynamic>{'type': ?type},
    );
    return EventsCalendar.fromJson(data);
  }
}
