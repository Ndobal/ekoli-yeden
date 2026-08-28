import { BadRequestError } from '../utils/errors';

/**
 * THE SHAPE OF A NEWS STORY'S BODY.
 *
 * ---------------------------------------------------------------------------
 * STRUCTURED BLOCKS, NOT HTML — AND THAT IS THE SECURITY DECISION
 * ---------------------------------------------------------------------------
 *
 * The brief asked for a rich-text editor and for the result to be sanitised on
 * the server. Both are right, and the usual way of doing them is wrong: give
 * the editor a `contenteditable`, receive HTML, and try to scrub it.
 *
 * Scrubbing HTML is a losing game. It is a denylist by nature — every parser
 * quirk, every mutation-XSS trick, every new attribute is a hole you did not
 * know you had, and the archive would be storing arbitrary markup written by
 * community volunteers and rendering it to every visitor.
 *
 * So the body is a LIST OF TYPED BLOCKS. A paragraph is `{type, text}`. A
 * heading carries a level between 2 and 4. A list carries items. Validation is
 * then an allowlist over a shape rather than an attempt to out-think an
 * attacker's parser, and anything not in the shape is refused rather than
 * cleaned.
 *
 * It also means the editor never asks a volunteer to write markup, the client
 * renders native widgets rather than a WebView, and the same story renders
 * identically on a phone, in a browser and in the SEO fallback the crawler
 * reads.
 *
 * ---------------------------------------------------------------------------
 * INLINE FORMATTING
 * ---------------------------------------------------------------------------
 *
 * Bold, italic and links are expressed as marks on ranges inside a block's
 * text, not as nested markup. A mark is three integers and a type; it cannot
 * express a script tag, an event handler or a stylesheet, because there is
 * nowhere in the shape to put one.
 */

/** Every block type the editor may produce. Anything else is refused. */
const BLOCK_TYPES = [
  'paragraph',
  'heading',
  'quote',
  'bullet_list',
  'numbered_list',
  'image',
  'video',
  'divider',
  'table',
] as const;

type BlockType = (typeof BLOCK_TYPES)[number];

/** The inline marks. Deliberately three, and none of them carries markup. */
const MARK_TYPES = ['bold', 'italic', 'link'] as const;

const MAX_BLOCKS = 400;
const MAX_TEXT = 8000;
const MAX_ITEMS = 100;
const MAX_TABLE_ROWS = 60;
const MAX_TABLE_COLUMNS = 10;

export interface NewsBlock {
  type: BlockType;
  text?: string;
  level?: number;
  items?: string[];
  marks?: { type: string; start: number; end: number; href?: string }[];
  /** For an image block: the media id, resolved to a URL when rendering. */
  mediaId?: string;
  /** For a video block: the YouTube id. */
  youtubeId?: string;
  caption?: string;
  align?: string;
  rows?: string[][];
}

/**
 * Validates a story body and returns it in canonical form.
 *
 * Throws `BadRequestError` on anything unrecognised rather than dropping it
 * silently: an editor who pastes something the schema cannot hold should be
 * told, not left to discover later that half their article vanished.
 */
export function validateNewsBody(input: unknown): NewsBlock[] {
  if (input === null || input === undefined) return [];

  // Accepted as a convenience for the submission form and for anything written
  // before the editor existed: plain text becomes paragraphs.
  if (typeof input === 'string') {
    return input
      .split(/\n{2,}/)
      .map((paragraph) => paragraph.trim())
      .filter((paragraph) => paragraph.length > 0)
      .slice(0, MAX_BLOCKS)
      .map((paragraph) => ({ type: 'paragraph' as const, text: paragraph.slice(0, MAX_TEXT) }));
  }

  if (!Array.isArray(input)) {
    throw new BadRequestError('The story is not in a form this archive can store.');
  }
  if (input.length > MAX_BLOCKS) {
    throw new BadRequestError(`A story cannot have more than ${MAX_BLOCKS} blocks.`);
  }

  return input.map((raw, index) => validateBlock(raw, index));
}

function validateBlock(raw: unknown, index: number): NewsBlock {
  if (typeof raw !== 'object' || raw === null) {
    throw new BadRequestError(`Block ${index + 1} is not readable.`);
  }

  const source = raw as Record<string, unknown>;
  const type = source['type'];

  if (typeof type !== 'string' || !(BLOCK_TYPES as readonly string[]).includes(type)) {
    throw new BadRequestError(`Block ${index + 1} is of a kind this archive does not store.`);
  }

  const block: NewsBlock = { type: type as BlockType };

  switch (type) {
    case 'paragraph':
    case 'quote':
      block.text = text(source['text'], index);
      block.marks = marks(source['marks'], block.text.length, index);
      break;

    case 'heading':
      block.text = text(source['text'], index);
      // Two to four. The page supplies the H1; a story that could set its own
      // would compete with the headline for what the page is about.
      block.level = clampInteger(source['level'], 2, 4, 2);
      break;

    case 'bullet_list':
    case 'numbered_list':
      block.items = items(source['items'], index);
      break;

    case 'image':
      block.mediaId = identifier(source['mediaId'], index, 'image');
      block.caption = optionalText(source['caption']);
      break;

    case 'video':
      block.youtubeId = youtube(source['youtubeId'], index);
      block.caption = optionalText(source['caption']);
      break;

    case 'divider':
      break;

    case 'table':
      block.rows = table(source['rows'], index);
      break;
  }

  const align = source['align'];
  if (typeof align === 'string' && ['left', 'center', 'right'].includes(align)) {
    block.align = align;
  }

  return block;
}

function text(value: unknown, index: number): string {
  if (typeof value !== 'string') {
    throw new BadRequestError(`Block ${index + 1} has no text.`);
  }
  return value.slice(0, MAX_TEXT);
}

function optionalText(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim().slice(0, 500)
    : undefined;
}

function items(value: unknown, index: number): string[] {
  if (!Array.isArray(value)) {
    throw new BadRequestError(`The list in block ${index + 1} has no items.`);
  }
  return value
    .filter((item): item is string => typeof item === 'string')
    .slice(0, MAX_ITEMS)
    .map((item) => item.slice(0, MAX_TEXT));
}

/**
 * Inline marks, bounded to the text they mark.
 *
 * A mark reaching past the end of its own text is refused rather than clamped:
 * it means the client and the server disagree about the content, and quietly
 * fixing that hides a real bug.
 */
function marks(
  value: unknown,
  length: number,
  index: number,
): { type: string; start: number; end: number; href?: string }[] | undefined {
  if (value === undefined || value === null) return undefined;
  if (!Array.isArray(value)) {
    throw new BadRequestError(`The formatting in block ${index + 1} is not readable.`);
  }

  return value.slice(0, 200).map((raw) => {
    const mark = raw as Record<string, unknown>;
    const type = mark['type'];

    if (typeof type !== 'string' || !(MARK_TYPES as readonly string[]).includes(type)) {
      throw new BadRequestError(`Block ${index + 1} uses formatting this archive does not store.`);
    }

    const start = Number(mark['start']);
    const end = Number(mark['end']);

    if (!Number.isInteger(start) || !Number.isInteger(end) || start < 0 || end > length || start >= end) {
      throw new BadRequestError(`The formatting in block ${index + 1} does not fit its text.`);
    }

    if (type === 'link') {
      return { type, start, end, href: link(mark['href'], index) };
    }
    return { type, start, end };
  });
}

/**
 * A link, restricted to http, https, mailto and a path on this site.
 *
 * `javascript:` and `data:` are the two that matter and both are refused by
 * the allowlist rather than by pattern-matching for them — a denylist here
 * would be one encoding trick away from failing.
 */
function link(value: unknown, index: number): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new BadRequestError(`A link in block ${index + 1} has no address.`);
  }

  const href = value.trim().slice(0, 2000);
  if (href.startsWith('/')) return href;

  let parsed: URL;
  try {
    parsed = new URL(href);
  } catch {
    throw new BadRequestError(`A link in block ${index + 1} is not a valid address.`);
  }

  if (!['http:', 'https:', 'mailto:'].includes(parsed.protocol)) {
    throw new BadRequestError(
      `A link in block ${index + 1} uses an address this archive will not publish.`,
    );
  }

  return parsed.toString();
}

function identifier(value: unknown, index: number, what: string): string {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,64}$/.test(value)) {
    throw new BadRequestError(`The ${what} in block ${index + 1} is not one this archive holds.`);
  }
  return value;
}

function youtube(value: unknown, index: number): string {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{6,20}$/.test(value)) {
    throw new BadRequestError(`The video in block ${index + 1} is not a YouTube video.`);
  }
  return value;
}

function table(value: unknown, index: number): string[][] {
  if (!Array.isArray(value)) {
    throw new BadRequestError(`The table in block ${index + 1} has no rows.`);
  }

  return value.slice(0, MAX_TABLE_ROWS).map((row) => {
    if (!Array.isArray(row)) {
      throw new BadRequestError(`A row of the table in block ${index + 1} is not readable.`);
    }
    return row
      .slice(0, MAX_TABLE_COLUMNS)
      .map((cell) => (typeof cell === 'string' ? cell.slice(0, 1000) : ''));
  });
}

function clampInteger(value: unknown, min: number, max: number, fallback: number): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}

/**
 * The plain text of a story, for search, for an excerpt, and for the
 * no-JavaScript summary a crawler reads.
 */
export function plainText(blocks: NewsBlock[]): string {
  return blocks
    .map((block) => {
      if (block.text) return block.text;
      if (block.items) return block.items.join(' ');
      if (block.caption) return block.caption;
      if (block.rows) return block.rows.map((row) => row.join(' ')).join(' ');
      return '';
    })
    .filter((part) => part.length > 0)
    .join('\n\n');
}

/**
 * Pulls the YouTube id out of whatever an editor pasted.
 *
 * Handles the watch URL, the short link, the embed URL and a bare id, because
 * all four are what people actually paste and refusing three of them teaches
 * the Editorial Team that the field is broken.
 */
export function youtubeIdFrom(input: string): string | null {
  const value = input.trim();
  if (/^[A-Za-z0-9_-]{6,20}$/.test(value)) return value;

  let url: URL;
  try {
    url = new URL(value);
  } catch {
    return null;
  }

  const host = url.hostname.replace(/^www\./, '');

  if (host === 'youtu.be') {
    const id = url.pathname.slice(1).split('/')[0] ?? '';
    return /^[A-Za-z0-9_-]{6,20}$/.test(id) ? id : null;
  }

  if (host === 'youtube.com' || host === 'm.youtube.com' || host === 'youtube-nocookie.com') {
    const fromQuery = url.searchParams.get('v');
    if (fromQuery && /^[A-Za-z0-9_-]{6,20}$/.test(fromQuery)) return fromQuery;

    const match = url.pathname.match(/^\/(embed|shorts|live|v)\/([A-Za-z0-9_-]{6,20})/);
    if (match) return match[2] ?? null;
  }

  return null;
}
