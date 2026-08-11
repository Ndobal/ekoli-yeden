import { youtubeEmbedUrl, youtubeThumbnailUrl, youtubeWatchUrl } from '../utils/files';

/**
 * YouTube is the video platform for the archive.
 *
 * D1 stores only the metadata record; the file itself always lives on YouTube.
 * That keeps R2 costs proportional to photographs and audio, and it means every
 * video the community has already published can be catalogued here without
 * being re-uploaded.
 */

/**
 * Video categories the archive organises YouTube content into.
 *
 * These are structural buckets for the CMS, not claims about what Ekoli-Yeden
 * material exists — every one of them starts empty.
 */
export const VIDEO_CATEGORIES = [
  'leboku',
  'history',
  'interviews',
  'culture',
  'community',
  'events',
  'documentaries',
  'music',
  'oral_history',
] as const;

export type VideoCategory = (typeof VIDEO_CATEGORIES)[number];

export interface DecoratedVideo extends Record<string, unknown> {
  watch_url: string;
  embed_url: string;
  thumbnail_url: string;
}

/**
 * Adds the derived YouTube URLs to a stored record.
 *
 * The thumbnail is derived from the video id rather than fetched, so the
 * archive renders without an API key and without a request to Google on every
 * page view. `thumbnail_url` in D1 overrides it when the Media Team has chosen
 * a specific still.
 */
export function decorateVideo(record: Record<string, unknown>): DecoratedVideo {
  const videoId = String(record['youtube_video_id'] ?? '');
  const storedThumbnail = record['thumbnail_url'];

  return {
    ...record,
    watch_url: youtubeWatchUrl(videoId),
    embed_url: youtubeEmbedUrl(videoId),
    thumbnail_url:
      typeof storedThumbnail === 'string' && storedThumbnail !== ''
        ? storedThumbnail
        : youtubeThumbnailUrl(videoId, 'hq'),
  };
}

export function decorateVideos(records: Record<string, unknown>[]): DecoratedVideo[] {
  return records.map(decorateVideo);
}

/**
 * Optional metadata lookup against the YouTube Data API.
 *
 * Used only by an administrator adding a video, to pre-fill title, description
 * and duration. It is never called on a public page view, and the key is a
 * Cloudflare secret that the Flutter client never sees. Returns `null` when no
 * key is configured, which is the normal state until the Media Team supplies one.
 */
export async function fetchYouTubeMetadata(
  videoId: string,
  apiKey: string | undefined,
): Promise<{ title: string; description: string; publishedAt: string; thumbnail: string } | null> {
  if (!apiKey) return null;

  const url = new URL('https://www.googleapis.com/youtube/v3/videos');
  url.searchParams.set('part', 'snippet');
  url.searchParams.set('id', videoId);
  url.searchParams.set('key', apiKey);

  const response = await fetch(url.toString());
  if (!response.ok) return null;

  const payload = (await response.json()) as {
    items?: { snippet?: { title?: string; description?: string; publishedAt?: string } }[];
  };
  const snippet = payload.items?.[0]?.snippet;
  if (!snippet) return null;

  return {
    title: snippet.title ?? '',
    description: snippet.description ?? '',
    publishedAt: snippet.publishedAt ?? '',
    thumbnail: youtubeThumbnailUrl(videoId, 'maxres'),
  };
}
