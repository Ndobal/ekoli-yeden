import { UserRepository } from '../repositories/user.repository';
import { AuditRepository } from '../repositories/audit.repository';
import type { Env } from '../types/env';
import type { UserRecord } from '../types/models';
import { BadRequestError } from '../utils/errors';
import { hashPassword, randomToken, sha256, timingSafeEqual } from '../utils/crypto';
import { newId, nowIso } from '../utils/id';

/**
 * PASSWORD RESET
 *
 * A single-use, time-limited token that lets somebody set their own password
 * without an administrator ever seeing it.
 *
 * Two properties are worth stating plainly, because both are easy to get wrong:
 *
 *   The token is stored only as a digest. It is, briefly, as good as the
 *   password, so a leaked database must not contain a usable copy. The raw
 *   value exists in exactly one place — the message sent to the account holder.
 *
 *   Requesting a reset never reveals whether an account exists. The response is
 *   identical either way, so the form cannot be used to work out who is a
 *   member of the community.
 */
export interface ResetTokenIssue {
  token: string;
  resetUrl: string;
  expiresAt: string;
  delivery: DeliveryOutcome;
}

export interface DeliveryOutcome {
  /** How it was sent, or `manual` when no channel is configured. */
  channel: 'email' | 'whatsapp' | 'manual';
  delivered: boolean;
  /** Masked destination, safe to show an administrator. */
  destination: string | null;
  /** Why it could not be sent, where that is the case. */
  reason?: string;
}

const DEFAULT_TTL_MINUTES = 60;

export class PasswordResetService {
  private readonly users: UserRepository;
  private readonly audit: AuditRepository;

  constructor(private readonly env: Env) {
    this.users = new UserRepository(env.DB);
    this.audit = new AuditRepository(env.DB);
  }

  private get siteUrl(): string {
    return (this.env.SITE_URL ?? 'https://ekoli.pages.dev').replace(/\/+$/, '');
  }

  private async ttlMinutes(): Promise<number> {
    const row = await this.env.DB.prepare(
      'SELECT "value" FROM "site_settings" WHERE "key" = ? LIMIT 1',
    )
      .bind('password_reset_ttl_minutes')
      .first<{ value: string | null }>();
    const parsed = Number(row?.value ?? DEFAULT_TTL_MINUTES);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_TTL_MINUTES;
  }

  /**
   * Issues a reset token for a user and attempts to deliver it.
   *
   * Returns the raw token and link. The caller decides what to expose: the
   * public endpoint discards them, while the admin endpoint returns the link so
   * an administrator can pass it on by hand when no channel is configured.
   */
  async issue(
    user: UserRecord,
    options: {
      requestedBy: string | null;
      ipHash: string | null;
      requestId: string;
      preferChannel?: 'email' | 'whatsapp';
    },
  ): Promise<ResetTokenIssue> {
    // Any outstanding tokens are retired first, so a reset request always
    // invalidates whatever was sent before it.
    await this.env.DB.prepare(
      'UPDATE "password_reset_tokens" SET "used_at" = ? WHERE "user_id" = ? AND "used_at" IS NULL',
    )
      .bind(nowIso(), user.id)
      .run();

    const token = randomToken(32);
    const ttl = await this.ttlMinutes();
    const expiresAt = new Date(Date.now() + ttl * 60_000).toISOString();
    const resetUrl = `${this.siteUrl}/reset-password?token=${encodeURIComponent(token)}`;

    const delivery = await this.deliver(user, resetUrl, ttl, options.preferChannel);

    await this.env.DB.prepare(
      `INSERT INTO "password_reset_tokens"
         ("id", "user_id", "token_hash", "delivery", "delivered_to", "expires_at",
          "used_at", "requested_by", "ip_hash", "created_at")
       VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?, ?)`,
    )
      .bind(
        newId(),
        user.id,
        await sha256(token),
        delivery.channel,
        delivery.destination,
        expiresAt,
        options.requestedBy,
        options.ipHash,
        nowIso(),
      )
      .run();

    await this.audit.record({
      actorId: options.requestedBy,
      actorEmail: user.email,
      action: 'auth.password_reset.requested',
      resourceType: 'user',
      resourceId: user.id,
      changes: {
        channel: delivery.channel,
        delivered: delivery.delivered,
        // The destination is masked; the audit log should not become a
        // directory of the community's phone numbers.
        destination: delivery.destination,
        requestedByAdministrator: options.requestedBy !== null && options.requestedBy !== user.id,
      },
      ipHash: options.ipHash,
      requestId: options.requestId,
    });

    return { token, resetUrl, expiresAt, delivery };
  }

  /**
   * Redeems a token and sets the new password.
   *
   * Every session for the account is revoked afterwards: if the reset was
   * needed because somebody else had access, leaving their session alive would
   * defeat the point.
   */
  async redeem(
    token: string,
    newPassword: string,
    context: { requestId: string; ipHash: string | null },
  ): Promise<void> {
    const record = await this.findValidToken(token);
    if (!record) {
      throw new BadRequestError(
        'That reset link is not valid. It may have expired, or already been used. Please request a new one.',
      );
    }

    const user = await this.users.findById(record.user_id);
    if (!user) throw new BadRequestError('That reset link is no longer valid.');

    const { hash, salt } = await hashPassword(newPassword);
    await this.users.update(user.id, { password_hash: hash, password_salt: salt });

    await this.env.DB.prepare(
      'UPDATE "password_reset_tokens" SET "used_at" = ? WHERE "id" = ?',
    )
      .bind(nowIso(), record.id)
      .run();

    await this.users.revokeAllSessionsForUser(user.id);

    await this.audit.record({
      actorId: user.id,
      actorEmail: user.email,
      action: 'auth.password_reset.completed',
      resourceType: 'user',
      resourceId: user.id,
      changes: { sessionsRevoked: true },
      ipHash: context.ipHash,
      requestId: context.requestId,
    });
  }

  /** Confirms a token is usable, so the form can refuse early and clearly. */
  async check(token: string): Promise<boolean> {
    return (await this.findValidToken(token)) !== null;
  }

  private async findValidToken(token: string): Promise<{ id: string; user_id: string } | null> {
    const digest = await sha256(token);
    const row = await this.env.DB.prepare(
      `SELECT "id", "user_id", "token_hash", "expires_at", "used_at"
       FROM "password_reset_tokens" WHERE "token_hash" = ? LIMIT 1`,
    )
      .bind(digest)
      .first<{
        id: string;
        user_id: string;
        token_hash: string;
        expires_at: string;
        used_at: string | null;
      }>();

    if (!row) return null;
    if (row.used_at !== null) return null;
    if (Date.parse(row.expires_at) <= Date.now()) return null;
    // Compared in constant time even though the lookup was by digest — the
    // habit costs nothing and removes a whole class of mistake.
    if (!timingSafeEqual(row.token_hash, digest)) return null;

    return { id: row.id, user_id: row.user_id };
  }

  // --- Delivery ------------------------------------------------------------

  /**
   * Sends the link over whichever channel is configured.
   *
   * When none is, the token is still created and the outcome is reported as
   * `manual`. That is the deliberate fallback: the community can run the whole
   * flow from day one, with a Super Admin passing the link on personally, and
   * turn on automatic delivery later without anything else changing.
   */
  private async deliver(
    user: UserRecord,
    resetUrl: string,
    ttlMinutes: number,
    prefer?: 'email' | 'whatsapp',
  ): Promise<DeliveryOutcome> {
    const record = user as UserRecord & {
      whatsapp_number?: string | null;
      preferred_contact?: string | null;
    };

    const channel = prefer ?? (record.preferred_contact === 'whatsapp' ? 'whatsapp' : 'email');
    const whatsappNumber = record.whatsapp_number ?? record.phone ?? null;

    if (channel === 'whatsapp' && whatsappNumber) {
      const sent = await this.sendWhatsApp(whatsappNumber, user.display_name, resetUrl, ttlMinutes);
      if (sent.delivered) return sent;
      // Fall back to email rather than failing outright.
      const viaEmail = await this.sendEmail(user, resetUrl, ttlMinutes);
      return viaEmail.delivered ? viaEmail : sent;
    }

    const viaEmail = await this.sendEmail(user, resetUrl, ttlMinutes);
    if (viaEmail.delivered) return viaEmail;

    if (whatsappNumber) {
      const sent = await this.sendWhatsApp(whatsappNumber, user.display_name, resetUrl, ttlMinutes);
      if (sent.delivered) return sent;
    }

    return {
      channel: 'manual',
      delivered: false,
      destination: mask(user.email),
      reason:
        'No email or WhatsApp service is configured, so the link was not sent automatically. ' +
        'An administrator can copy it from the Users screen and pass it on.',
    };
  }

  private async sendEmail(
    user: UserRecord,
    resetUrl: string,
    ttlMinutes: number,
  ): Promise<DeliveryOutcome> {
    const apiKey = this.env.RESEND_API_KEY;
    const from = this.env.RESET_EMAIL_FROM;

    if (!apiKey || !from) {
      return {
        channel: 'email',
        delivered: false,
        destination: mask(user.email),
        reason: 'Email sending is not configured (RESEND_API_KEY and RESET_EMAIL_FROM).',
      };
    }

    try {
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          authorization: `Bearer ${apiKey}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          from,
          to: [user.email],
          subject: 'Reset your Ekoli Yeden Digital Home password',
          text: plainTextMessage(user.display_name, resetUrl, ttlMinutes),
          html: htmlMessage(user.display_name, resetUrl, ttlMinutes),
        }),
      });

      if (!response.ok) {
        return {
          channel: 'email',
          delivered: false,
          destination: mask(user.email),
          reason: `The email service refused the message (${response.status}).`,
        };
      }
      return { channel: 'email', delivered: true, destination: mask(user.email) };
    } catch (error) {
      console.error('Password reset email failed', error);
      return {
        channel: 'email',
        delivered: false,
        destination: mask(user.email),
        reason: 'The email service could not be reached.',
      };
    }
  }

  private async sendWhatsApp(
    number: string,
    displayName: string,
    resetUrl: string,
    ttlMinutes: number,
  ): Promise<DeliveryOutcome> {
    const token = this.env.WHATSAPP_TOKEN;
    const phoneNumberId = this.env.WHATSAPP_PHONE_NUMBER_ID;

    if (!token || !phoneNumberId) {
      return {
        channel: 'whatsapp',
        delivered: false,
        destination: mask(number),
        reason: 'WhatsApp sending is not configured (WHATSAPP_TOKEN and WHATSAPP_PHONE_NUMBER_ID).',
      };
    }

    try {
      const response = await fetch(
        `https://graph.facebook.com/v21.0/${phoneNumberId}/messages`,
        {
          method: 'POST',
          headers: {
            authorization: `Bearer ${token}`,
            'content-type': 'application/json',
          },
          body: JSON.stringify({
            messaging_product: 'whatsapp',
            to: normaliseNumber(number),
            type: 'text',
            text: { preview_url: false, body: plainTextMessage(displayName, resetUrl, ttlMinutes) },
          }),
        },
      );

      if (!response.ok) {
        return {
          channel: 'whatsapp',
          delivered: false,
          destination: mask(number),
          reason: `WhatsApp refused the message (${response.status}).`,
        };
      }
      return { channel: 'whatsapp', delivered: true, destination: mask(number) };
    } catch (error) {
      console.error('Password reset WhatsApp message failed', error);
      return {
        channel: 'whatsapp',
        delivered: false,
        destination: mask(number),
        reason: 'WhatsApp could not be reached.',
      };
    }
  }
}

function plainTextMessage(name: string, resetUrl: string, ttlMinutes: number): string {
  return `Hello ${name},

Somebody asked to reset the password for your account on the Ekoli Yeden Digital Home.

Open this link to choose a new password:
${resetUrl}

The link works once and expires in ${ttlMinutes} minutes.

If you did not ask for this, you can ignore this message — your password has not changed.

— Ekoli Yeden Digital Home
Preserving Our Past. Celebrating Our Present. Building Our Future.`;
}

function htmlMessage(name: string, resetUrl: string, ttlMinutes: number): string {
  return `<!doctype html><html><body style="margin:0;padding:24px;background:#F7FAFD;font-family:Segoe UI,Helvetica,Arial,sans-serif;color:#10202F">
<div style="max-width:520px;margin:0 auto;background:#fff;border-radius:12px;overflow:hidden;border:1px solid #DCE6EF">
  <div style="background:#0A345C;padding:24px;text-align:center">
    <div style="color:#fff;font-size:18px;font-weight:700;letter-spacing:.3px">EKOLI YEDEN DIGITAL HOME</div>
    <div style="color:#A9D2F3;font-size:12px;margin-top:6px">Preserving Our Past. Celebrating Our Present. Building Our Future.</div>
  </div>
  <div style="padding:28px">
    <p style="margin:0 0 16px">Hello ${escapeHtml(name)},</p>
    <p style="margin:0 0 16px">Somebody asked to reset the password for your account.</p>
    <p style="margin:0 0 24px">
      <a href="${escapeHtml(resetUrl)}" style="display:inline-block;background:#B8912D;color:#fff;text-decoration:none;padding:12px 22px;border-radius:6px;font-weight:600">Choose a new password</a>
    </p>
    <p style="margin:0 0 16px;font-size:13px;color:#64757F">The link works once and expires in ${ttlMinutes} minutes.</p>
    <p style="margin:0;font-size:13px;color:#64757F">If you did not ask for this, ignore this message — your password has not changed.</p>
  </div>
</div>
</body></html>`;
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** WhatsApp expects an international number with no punctuation. */
function normaliseNumber(number: string): string {
  return number.replace(/[^\d]/g, '');
}

/**
 * Masks a destination for display and for the audit log.
 *
 * An administrator needs enough to confirm the link went to the right place;
 * neither they nor the log needs the full address.
 */
function mask(value: string): string {
  if (value.includes('@')) {
    const [local, domain] = value.split('@');
    const head = (local ?? '').slice(0, 2);
    return `${head}${'•'.repeat(Math.max(1, (local ?? '').length - 2))}@${domain ?? ''}`;
  }
  const digits = value.replace(/[^\d]/g, '');
  return digits.length <= 4 ? '••••' : `${'•'.repeat(digits.length - 4)}${digits.slice(-4)}`;
}
