import { BadRequestError, PayloadTooLargeError } from './errors';
import { newId } from './id';

/**
 * R2 layout and upload validation.
 *
 * VIDEO
 *
 * This file used to say videos were deliberately absent and that YouTube hosts
 * every one of them. That held while the only videos in question were finished
 * films somebody had already published. It does not hold for the thing the
 * community actually has: a phone clip of the Mr and Miss Leboku crowning, shot
 * on Saturday, that belongs in that year's album next to the photographs.
 *
 * Requiring a YouTube account, an upload, and a pasted link before that clip
 * can be filed is how it never gets filed at all.
 *
 * So R2 now takes short video, with a ceiling well under what YouTube is for.
 * The two paths coexist and answer different needs:
 *
 *   R2       short clips that belong to an album, uploaded like a photograph
 *   YouTube  full recordings, documentaries, anything long
 *
 * The ceiling is not a guess. A Worker receives the whole upload in memory
 * before it reaches R2, so the real limit is the Worker's, not the bucket's —
 * see `MAX_BYTES_BY_TYPE` below.
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
/**
 * Video the archive accepts.
 *
 * `video/quicktime` is here because iPhones produce .mov and leaving it out
 * would refuse a large share of what the community actually records. 3GPP is
 * here for the same reason at the other end of the price range — it is what
 * cheaper Android handsets still produce, and those are the phones most likely
 * to be at a village event.
 */
const VIDEO_TYPES = ['video/mp4', 'video/quicktime', 'video/webm', 'video/3gpp'];

const DOCUMENT_TYPES = [
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain',
];

export const ALLOWED_MIME_TYPES: Record<R2Folder, string[]> = {
  [R2_FOLDERS.IMAGES]: [...IMAGE_TYPES, ...VIDEO_TYPES],
  // Avatars stay stills. A moving profile picture is not something the archive
  // needs, and it is the one folder every signed-in member can write to.
  [R2_FOLDERS.AVATARS]: IMAGE_TYPES,
  [R2_FOLDERS.HERITAGE]: [...IMAGE_TYPES, ...VIDEO_TYPES, ...DOCUMENT_TYPES],
  [R2_FOLDERS.LEBOKU]: [...IMAGE_TYPES, ...VIDEO_TYPES, ...DOCUMENT_TYPES],
  // Video belongs in the language folder more than anywhere: a recording of
  // somebody's mouth forming a word teaches what an audio file cannot.
  [R2_FOLDERS.LANGUAGE]: [...AUDIO_TYPES, ...VIDEO_TYPES, ...IMAGE_TYPES, ...DOCUMENT_TYPES],
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

/**
 * Ceilings for types that need a different one from the folder they sit in.
 *
 * A folder ceiling suits a folder holding one kind of thing. The Leboku folder
 * holds photographs and now clips of the same event, and 15 MB is generous for
 * a photograph and useless for a video.
 *
 * WHY 64 MB AND NOT MORE.
 *
 * A Cloudflare Worker reads the whole upload into memory before any of it
 * reaches R2, and it has 128 MB to work in. The multipart body, the decoded
 * bytes and the copy handed to R2 all live there at once, so the real ceiling
 * is well under the 100 MB request limit — 64 MB leaves room for the request
 * to survive rather than dying halfway with nothing stored.
 *
 * That is a few minutes of phone video, which is what this is for. Anything
 * longer is a YouTube link, and the archive still catalogues those.
 */
export const MAX_BYTES_BY_TYPE: Record<string, number> = {
  'video/mp4': 64 * 1024 * 1024,
  'video/quicktime': 64 * 1024 * 1024,
  'video/webm': 64 * 1024 * 1024,
  'video/3gpp': 64 * 1024 * 1024,
};

/** Whether a stored file is video, used to decide how to present it. */
export function isVideoType(mimeType: string): boolean {
  return mimeType.startsWith('video/');
}

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
  'video/mp4': 'mp4',
  'video/quicktime': 'mov',
  'video/webm': 'webm',
  'video/3gpp': '3gp',
  'application/pdf': 'pdf',
  'application/msword': 'doc',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
  'text/plain': 'txt',
};

export function isR2Folder(value: string): value is R2Folder {
  return (ALL_R2_FOLDERS as string[]).includes(value);
}

/** Filename extension to MIME type. The inverse of `EXTENSION_BY_MIME`. */
const MIME_BY_EXTENSION: Record<string, string> = {
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  jpe: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
  gif: 'image/gif',
  avif: 'image/avif',
  mp3: 'audio/mpeg',
  m4a: 'audio/mp4',
  aac: 'audio/aac',
  ogg: 'audio/ogg',
  oga: 'audio/ogg',
  wav: 'audio/wav',
  weba: 'audio/webm',
  // .webm is both an audio and a video container. Video is the overwhelmingly
  // more common thing to be handed one of, and the byte check below settles it
  // either way, so the guess costs nothing when it is wrong.
  webm: 'video/webm',
  mp4: 'video/mp4',
  m4v: 'video/mp4',
  mov: 'video/quicktime',
  qt: 'video/quicktime',
  '3gp': 'video/3gpp',
  '3gpp': 'video/3gpp',
  pdf: 'application/pdf',
  doc: 'application/msword',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  txt: 'text/plain',
};

const UNKNOWN_TYPE = 'application/octet-stream';

/**
 * What kind of file this actually is.
 *
 * Browsers are unreliable about this. A file picked on a phone frequently
 * arrives with no type at all, or as `application/octet-stream` — and since
 * that is in no folder's allow-list, an ordinary photograph gets refused with
 * a message about unknown binaries.
 *
 * So: use what the client declared if it is specific, otherwise fall back to
 * the filename. Neither is trusted — `assertUploadAllowed` still has to pass,
 * and `assertContentMatchesType` checks the bytes themselves. Falling back to
 * the extension widens nothing: an attacker could already have declared any
 * allowed type directly.
 */
export function resolveMimeType(declared: string | null | undefined, filename: string): string {
  const stated = (declared ?? '').split(';')[0]?.trim().toLowerCase() ?? '';
  if (stated !== '' && stated !== UNKNOWN_TYPE) return stated;

  const dot = filename.lastIndexOf('.');
  if (dot < 0 || dot === filename.length - 1) return UNKNOWN_TYPE;

  return MIME_BY_EXTENSION[filename.slice(dot + 1).toLowerCase()] ?? UNKNOWN_TYPE;
}

/**
 * What the file's leading bytes say it is.
 *
 * Returns null where the format has no reliable signature — plain text and the
 * Office formats, which are ZIP containers and would need unpacking to tell
 * apart from any other ZIP.
 */
export function sniffMimeType(bytes: ArrayBuffer): string | null {
  const view = new Uint8Array(bytes.slice(0, 16));
  if (view.length < 4) return null;

  const startsWith = (...signature: number[]): boolean =>
    signature.every((byte, index) => view[index] === byte);

  if (startsWith(0xff, 0xd8, 0xff)) return 'image/jpeg';
  if (startsWith(0x89, 0x50, 0x4e, 0x47)) return 'image/png';
  if (startsWith(0x47, 0x49, 0x46, 0x38)) return 'image/gif';
  if (startsWith(0x25, 0x50, 0x44, 0x46)) return 'application/pdf';
  if (startsWith(0x49, 0x44, 0x33) || startsWith(0xff, 0xfb) || startsWith(0xff, 0xf3)) {
    return 'audio/mpeg';
  }
  if (startsWith(0x4f, 0x67, 0x67, 0x53)) return 'audio/ogg';
  // EBML — the WebM/Matroska container, shared by audio-only and video files.
  // Which one it is takes parsing the track elements, so it is reported as the
  // video type and treated as equivalent to the audio one below.
  if (startsWith(0x1a, 0x45, 0xdf, 0xa3)) return 'video/webm';

  // RIFF containers: WAV and WebP share a header and differ at byte 8.
  if (startsWith(0x52, 0x49, 0x46, 0x46)) {
    const tag = String.fromCharCode(view[8] ?? 0, view[9] ?? 0, view[10] ?? 0, view[11] ?? 0);
    if (tag === 'WEBP') return 'image/webp';
    if (tag === 'WAVE') return 'audio/wav';
  }

  // ISO base media: 'ftyp' at byte 4, then a four-character brand naming what
  // kind of ISO file this is. Every .mp4, .m4a, .mov and .3gp shares the
  // header and differs only in the brand, so returning one type for all of
  // them — as this did — meant an .mp4 video was reported as audio.
  if (view[4] === 0x66 && view[5] === 0x74 && view[6] === 0x79 && view[7] === 0x70) {
    const brand = String.fromCharCode(view[8] ?? 0, view[9] ?? 0, view[10] ?? 0, view[11] ?? 0);

    if (brand.startsWith('M4A')) return 'audio/mp4';
    if (brand.startsWith('qt')) return 'video/quicktime';
    if (brand.startsWith('3g')) return 'video/3gpp';
    // isom, iso2, mp41, mp42, avc1, mmp4, M4V — all ordinary video.
    return 'video/mp4';
  }

  return null;
}

/**
 * Types whose contents we can verify from their leading bytes.
 *
 * `text/plain` and the Office formats are absent: a text file has no
 * signature, and a .docx is a ZIP container indistinguishable from any other
 * ZIP without unpacking it.
 */
const VERIFIABLE_TYPES = new Set<string>([
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'application/pdf',
  'audio/mpeg',
  'audio/mp4',
  'audio/x-m4a',
  'audio/ogg',
  'audio/wav',
  'audio/webm',
  'video/mp4',
  'video/quicktime',
  'video/webm',
  'video/3gpp',
]);

/**
 * Spellings that mean the same format.
 *
 * Keyed on what the bytes turned out to be; the array is what a file may
 * legitimately have claimed to be.
 *
 * The ISO and EBML containers are the reason this exists. A .m4a, an .mp4 and
 * a .mov are the same container with different brands, and a .webm holding
 * only audio is byte-for-byte a .webm holding video until you parse its
 * tracks. Being strict here would refuse ordinary files from ordinary phones
 * while stopping nothing — the folder allow-list is what decides whether video
 * is welcome, and it is checked separately.
 */
const EQUIVALENT_TYPES: Record<string, string[]> = {
  'audio/mp4': ['audio/mp4', 'audio/x-m4a', 'video/mp4'],
  'audio/mpeg': ['audio/mpeg', 'audio/mp3'],
  'audio/webm': ['audio/webm', 'video/webm'],
  'video/mp4': ['video/mp4', 'video/quicktime', 'video/3gpp', 'audio/mp4', 'audio/x-m4a'],
  'video/quicktime': ['video/quicktime', 'video/mp4'],
  'video/3gpp': ['video/3gpp', 'video/mp4'],
  'video/webm': ['video/webm', 'audio/webm'],
};

/**
 * Refuses a file whose contents do not match what it claims to be.
 *
 * Nothing used to look inside an upload: an executable renamed `.jpg` and
 * declared as `image/jpeg` would have been stored, and later served with an
 * image content type. `nosniff` and the inline disposition limit what a
 * browser would do with it, but storing it at all is worse than not.
 *
 * THE TEST IS ON THE DECLARED TYPE, NOT ON WHETHER WE RECOGNISE THE CONTENT.
 *
 * Asking "can we identify these bytes?" and waving through anything
 * unidentifiable is exactly backwards — an executable is unidentifiable to
 * this function, so that version accepted the one file it most needed to
 * refuse. It did, on the first run of the test below.
 *
 * So: a file claiming to be something we CAN verify must actually be that
 * thing. A file claiming a format with no signature — a text file, a .docx —
 * goes through on the claim, because refusing all of those would cost more
 * than the risk.
 */
export function assertContentMatchesType(bytes: ArrayBuffer, declaredType: string): void {
  if (!VERIFIABLE_TYPES.has(declaredType)) return;

  const actual = sniffMimeType(bytes);
  if (actual === declaredType) return;
  if (actual !== null && EQUIVALENT_TYPES[actual]?.includes(declaredType)) return;

  throw new BadRequestError(
    actual === null
      ? `That file is named as ${declaredType}, but its contents are not. Please upload the `
        + 'original file rather than a renamed one.'
      : `That file says it is ${declaredType}, but its contents are ${actual}. Please upload the `
        + 'original file rather than a renamed one.',
  );
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
  // A type ceiling replaces the folder ceiling where it exists, and it also
  // overrides the global one — the global figure is sized for photographs, and
  // applying it to video would refuse every clip regardless of the above.
  const typeCeiling = MAX_BYTES_BY_TYPE[check.mimeType];
  const limit = typeCeiling ?? Math.min(MAX_BYTES_BY_FOLDER[check.folder], globalMaxBytes);

  if (check.sizeBytes > limit) {
    const megabytes = Math.floor(limit / (1024 * 1024));
    throw new PayloadTooLargeError(
      typeCeiling === undefined
        ? `Files in the ${check.folder} folder must be ${megabytes} MB or smaller.`
        : `Videos must be ${megabytes} MB or smaller — about a few minutes from a phone. For `
          + 'anything longer, publish it on YouTube and add the link instead.',
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
