import { ValidationError } from '../utils/errors';

/** Validate the stored type before a settings batch writes anything. */
export function encodeSettingValue(key: string, type: string, value: unknown): string | null {
  if (value === null) return null;
  const invalid = (message: string): never => {
    throw new ValidationError({ [key]: [message] });
  };
  switch (type) {
    case 'boolean':
      if (value === true || value === 'true' || value === 1 || value === '1') return 'true';
      if (value === false || value === 'false' || value === 0 || value === '0') return 'false';
      return invalid('Choose true or false.');
    case 'number': {
      if ((typeof value !== 'string' && typeof value !== 'number') || String(value).trim() === '') {
        return invalid('Enter a valid number.');
      }
      const parsed = Number(value);
      if (!Number.isFinite(parsed)) return invalid('Enter a valid number.');
      return String(parsed);
    }
    case 'json':
      try {
        const parsed = typeof value === 'string' ? JSON.parse(value) : value;
        const encoded = JSON.stringify(parsed);
        if (encoded === undefined) return invalid('Enter valid JSON.');
        return encoded;
      } catch {
        return invalid('Enter valid JSON.');
      }
    default:
      if (typeof value !== 'string') return invalid('Enter text.');
      return value;
  }
}
