import { BadRequestError, PayloadTooLargeError } from './errors';
import { newId } from './id';

/**
 * R2 layout and upload validation.
 *
 * Videos are deliberately absent: YouTube hosts every video, and R2 holds only
 * the still images, audio, documents and scans that make up the archive.
 */
export const R2_FOLDERS = {
  /** Current community photographs. */
  IMAGES: 'images',
  /** Language recordings, oral-history audio, songs. */
  AUDIO: 'audio',
  /** Scanned documents, programmes, letters, certificates. */
  DOCUMENTS: 'documents',
  /** User profile pictures. */
  AVATARS: 'avatars',
  /** Historical photographs and documents held by the archive. */
  HERITAGE: 'heritage',
  /** Ekoli language material: word cards, pronunciation guides. */
  LANGUAGE: 'language',
  /** Leboku festival stills, posters and non-video material. */
  LEBOKU: 'leboku',
} as const;

export type R2Folder = (typeof R2_FOLDERS)[keyof typeof R2_FOLDERS];

export const ALL_R2_FOLDERS: R2Folder[] = Object.values(R2_FOLDERS);

/**
 * Accepted MIME types per folder.
 *
 * The list is an allow-list, not a deny-list: anything not named here is
 * refused, including SVG (which can carry script) and every executable type.
 */
const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/avif'];
const AUDIO_TYPES = ['audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/ogg', 'audio/wav', 'audio/webm', 'audio/x-m4a'];
const DOCUMENT_TYPES = [
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain',
];

export const ALLOWED_MIME_TYPES: Record<R2Folder, string[]> = {
  [R2_FOLDERS.IMAGES]: IMAGE_TYPES,
  [R2_FOLDERS.AVATARS]: IMAGE_TYPES,
  [R2_FOLDERS.HERITAGE]: [...IMAGE_TYPES, ...DOCUMENT_TYPES],
  [R2_FOLDERS.LEBOKU]: [...IMAGE_TYPES, ...DOCUMENT_TYPES],
  [R2_FOLDERS.LANGUAGE]: [...AUDIO_TYPES, ...IMAGE_TYPES, ...DOCUMENT_TYPES],
  [R2_FOLDERS.AUDIO]: AUDIO_TYPES,
  [R2_FOLDERS.DOCUMENTS]: DOCUMENT_TYPES,
};

/** Per-folder ceilings, applied on top of the global `MAX_UPLOAD_BYTES`. */
export const MAX_BYTES_BY_FOLDER: Record<R2Folder, number> = {
  [R2_FOLDERS.IMAGES]: 12 * 1024 * 1024,
  [R2_FOLDERS.AVATARS]: 3 * 1024 * 1024,
  [R2_FOLDERS.HERITAGE]: 25 * 1024 * 1024,
  [R2_FOLDERS.LEBOKU]: 15 * 1024 * 1024,
  [R2_FOLDERS.LANGUAGE]: 25 * 1024 * 1024,
  [R2_FOLDERS.AUDIO]: 25 * 1024 * 1024,
  [R2_FOLDERS.DOCUMENTS]: 25 * 1024 * 1024,
};

const EXTENSION_BY_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
  'image/avif': 'avif',
  'audio/mpeg': 'mp3',
  'audio/mp4': 'm4a',
  'audio/x-m4a': 'm4a',
  'audio/aac': 'aac',
  'audio/ogg': 'ogg',
  'audio/wav': 'wav',
  'audio/webm': 'weba',
  'application/pdf': 'pdf',
  'application/msword': 'doc',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
  'text/plain': 'txt',
};

export function isR2Folder(value: string): value is R2Folder {
  return (ALL_R2_FOLDERS as string[]).includes(value);
}

/** Strips directory components and anything that could escape the folder. */
export function sanitizeFilename(filename: string): string {
  const base = filename.split(/[\\/]/).pop() ?? 'file';
  const cleaned = base
    .replace(/[^A-Za-z0-9._-]+/g, '-')
    .replace(/^[.-]+/, '')
    .slice(0, 120);
  return cleaned === '' ? 'file' : cleaned;
}

/**
 * Builds the R2 object key: `<folder>/<yyyy>/<mm>/<random>.<ext>`.
 *
 * The date prefix keeps the bucket browsable by a Media Team volunteer and
 * keeps listings shallow as the archive grows.
 */
export function buildStorageKey(folder: R2Folder, mimeType: string, originalFilename: string): string {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, '0');
  const extension =
    EXTENSION_BY_MIME[mimeType] ?? sanitizeFilename(originalFilename).split('.').pop() ?? 'bin';
  return `${folder}/${year}/${month}/${newId()}.${extension}`;
}

export interface UploadCheck {
  folder: R2Folder;
  mimeType: string;
  sizeBytes: number;
  filename: string;
}

/** Throws unless the upload satisfies folder, type and size rules. */
export function assertUploadAllowed(check: UploadCheck, globalMaxBytes: number): void {
  if (!isR2Folder(check.folder)) {
    throw new BadRequestError(`Unknown media folder. Expected one of: ${ALL_R2_FOLDERS.join(', ')}.`);
  }
  const allowed = ALLOWED_MIME_TYPES[check.folder];
  if (!allowed.includes(check.mimeType)) {
    throw new BadRequestError(
      `Files of type "${check.mimeType}" are not accepted in the ${check.folder} folder.`,
    );
  }
  if (check.sizeBytes <= 0) {
    throw new BadRequestError('The uploaded file is empty.');
  }
  const limit = Math.min(MAX_BYTES_BY_FOLDER[check.folder], globalMaxBytes);
  if (check.sizeBytes > limit) {
    throw new PayloadTooLargeError(
      `Files in the ${check.folder} folder must be ${Math.floor(limit / (1024 * 1024))} MB or smaller.`,
    );
  }
}

/** Public URL for an R2 object, served through the Worker's media route. */
export function publicMediaUrl(baseUrl: string, storageKey: string): string {
  return `${baseUrl.replace(/\/+$/, '')}/${storageKey}`;
}

/** YouTube thumbnail URL derived from a video id — no API call required. */
export function youtubeThumbnailUrl(videoId: string, quality: 'default' | 'hq' | 'maxres' = 'hq'): string {
  const file = quality === 'maxres' ? 'maxresdefault' : quality === 'hq' ? 'hqdefault' : 'default';
  return `https://i.ytimg.com/vi/${videoId}/${file}.jpg`;
}

export function youtubeWatchUrl(videoId: string): string {
  return `https://www.youtube.com/watch?v=${videoId}`;
}

export function youtubeEmbedUrl(videoId: string): string {
  // nocookie host: visitors browsing the archive are not tracked by default.
  return `https://www.youtube-nocookie.com/embed/${videoId}`;
}
