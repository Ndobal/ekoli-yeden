/// Errors raised by the client.
///
/// Everything a screen shows a visitor comes from `message`, which is always
/// written in plain language. Technical detail stays in `debugDetail`, which is
/// logged in development and never rendered.
sealed class AppException implements Exception {
  const AppException(this.message, {this.debugDetail});

  final String message;
  final String? debugDetail;

  @override
  String toString() => '$runtimeType: $message${debugDetail == null ? '' : ' ($debugDetail)'}';
}

/// The request never reached the Worker, or its answer was blocked.
///
/// THE MESSAGE HERE USED TO BLAME THE VISITOR'S CONNECTION.
///
/// A browser does not tell a page why a cross-origin request failed. A rejected
/// origin, a blocked response and an unplugged cable are one indistinguishable
/// event to Dart — so when the API's allow-list did not include the address
/// people were actually visiting, everybody trying to register was told to
/// check an internet connection that was working perfectly.
///
/// It cost real people real time, and it sent them looking in the one place the
/// fault could not be. So the wording no longer asserts a cause it cannot know,
/// and it names the address it was trying to reach — which is the single most
/// useful thing somebody can pass on when reporting this.
class NetworkException extends AppException {
  const NetworkException({super.debugDetail})
    : super(
        'We could not reach the archive. This is usually a connection problem, but it can also '
        'mean the address you are visiting is not one the archive recognises. Please try again, '
        'and if it keeps happening tell us the address in your browser bar.',
      );
}

/// The request reached the Worker but took too long.
///
/// Named `Request…` rather than `TimeoutException` so it does not collide with
/// `dart:async`'s type of that name, which the API client also has to catch.
class RequestTimeoutException extends AppException {
  const RequestTimeoutException({super.debugDetail})
    : super('The archive is taking longer than usual to respond. Please try again.');
}

/// The caller is not signed in, or the session has expired.
class UnauthorizedException extends AppException {
  const UnauthorizedException([String? message, String? debugDetail])
    : super(message ?? 'Please sign in to continue.', debugDetail: debugDetail);
}

/// The caller is signed in but is not permitted to do this.
class ForbiddenException extends AppException {
  const ForbiddenException([String? message, String? debugDetail])
    : super(
        message ?? 'You do not have permission to do that.',
        debugDetail: debugDetail,
      );
}

class NotFoundException extends AppException {
  const NotFoundException([String? message, String? debugDetail])
    : super(message ?? 'That page could not be found.', debugDetail: debugDetail);
}

/// Field-level validation rejected by the server.
class ValidationException extends AppException {
  const ValidationException(super.message, this.fieldErrors, {super.debugDetail});

  /// Field name to the messages for that field, ready to attach to form fields.
  final Map<String, List<String>> fieldErrors;

  String? firstErrorFor(String field) {
    final List<String>? errors = fieldErrors[field];
    return (errors == null || errors.isEmpty) ? null : errors.first;
  }
}

/// The upload exceeded a limit the server enforces.
class UploadException extends AppException {
  const UploadException(super.message, {super.debugDetail});
}

/// Anything else the server rejected.
class ApiException extends AppException {
  const ApiException(super.message, this.statusCode, {this.code, super.debugDetail});

  final int statusCode;
  final String? code;
}

/// A failure with no better classification.
class UnexpectedException extends AppException {
  const UnexpectedException({super.debugDetail})
    : super('Something went wrong. Please try again.');
}
