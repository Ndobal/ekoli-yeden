/**
 * Application errors.
 *
 * Every error that reaches the client goes through one of these, so that the
 * response body is always predictable and never leaks a stack trace, an SQL
 * fragment, a binding name or a secret.
 */
export class AppError extends Error {
  readonly status: number;
  readonly code: string;
  readonly details?: Record<string, string[]>;
  /** When false, the error handler logs the cause but returns a generic body. */
  readonly expose: boolean;

  constructor(
    status: number,
    code: string,
    message: string,
    options: { details?: Record<string, string[]>; expose?: boolean; cause?: unknown } = {},
  ) {
    super(message, { cause: options.cause });
    this.name = 'AppError';
    this.status = status;
    this.code = code;
    this.details = options.details;
    this.expose = options.expose ?? true;
  }
}

export class ValidationError extends AppError {
  constructor(details: Record<string, string[]>, message = 'The submitted data is not valid.') {
    super(422, 'VALIDATION_FAILED', message, { details });
    this.name = 'ValidationError';
  }
}

export class BadRequestError extends AppError {
  constructor(message = 'The request could not be understood.') {
    super(400, 'BAD_REQUEST', message);
    this.name = 'BadRequestError';
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Authentication is required.') {
    super(401, 'UNAUTHORIZED', message);
    this.name = 'UnauthorizedError';
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'You do not have permission to perform this action.') {
    super(403, 'FORBIDDEN', message);
    this.name = 'ForbiddenError';
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'The requested resource was not found.') {
    super(404, 'NOT_FOUND', message);
    this.name = 'NotFoundError';
  }
}

export class ConflictError extends AppError {
  constructor(message = 'The resource already exists.') {
    super(409, 'CONFLICT', message);
    this.name = 'ConflictError';
  }
}

export class PayloadTooLargeError extends AppError {
  constructor(message = 'The uploaded file is larger than the permitted limit.') {
    super(413, 'PAYLOAD_TOO_LARGE', message);
    this.name = 'PayloadTooLargeError';
  }
}

export class RateLimitError extends AppError {
  readonly retryAfterSeconds: number;

  constructor(retryAfterSeconds: number, message = 'Too many requests. Please try again shortly.') {
    super(429, 'RATE_LIMITED', message);
    this.name = 'RateLimitError';
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

export class ConfigurationError extends AppError {
  constructor(message: string) {
    // Never exposed: a misconfiguration message can reveal infrastructure detail.
    super(500, 'SERVER_MISCONFIGURED', message, { expose: false });
    this.name = 'ConfigurationError';
  }
}
