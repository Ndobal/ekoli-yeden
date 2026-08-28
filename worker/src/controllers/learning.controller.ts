import type { Handler, RequestContext } from '../types/api';
import { NotFoundError, ValidationError } from '../utils/errors';
import { json, publicCacheHeaders, NO_STORE_HEADERS } from '../utils/responses';
import { readJsonBody, Validator } from '../utils/validation';
import { newId, nowIso } from '../utils/id';
import { UnauthorizedError } from '../utils/errors';
import { AuditRepository, AUDIT_ACTIONS } from '../repositories/audit.repository';
import { publicMediaUrl } from '../utils/files';

/** Local, matching the other controllers. */
function requireActor(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  return context.user;
}

/**
 * LEARN ABOUT EKORI — §17 of the proposal.
 *
 * ---------------------------------------------------------------------------
 * WHAT THIS FILE DOES NOT DO
 * ---------------------------------------------------------------------------
 *
 * It never records who answered anything.
 *
 * There is no attempt table, no score, no session, and no endpoint that
 * accepts a child's answer. `showQuiz` returns the questions with their
 * options, the browser marks them, and the result is shown to the child and
 * then forgotten when they close the tab.
 *
 * That means the correct answers are in the response body, and a determined
 * ten-year-old can read them in the developer tools. That is a fair trade. The
 * alternative is a server round trip for every answer, which would create
 * exactly the record of a named child's mistakes that this section is built to
 * avoid — and these are quizzes about greetings and proverbs, not an exam.
 *
 * If the schools ever want class results, that is a different feature, with a
 * different consent conversation, and it should be built deliberately rather
 * than arrived at by adding a column here.
 */

// ---------------------------------------------------------------------------
// Public
// ---------------------------------------------------------------------------

interface QuizRow extends Record<string, unknown> {
  id: string;
}

/**
 * `GET /api/learn/quizzes/:identifier`
 *
 * One published quiz with its questions and their options, ready to be marked
 * in the browser.
 */
export const showQuiz: Handler = async (context: RequestContext) => {
  const identifier = context.params['identifier'] ?? '';

  const quiz = await context.env.DB.prepare(
    `SELECT q."id", q."slug", q."title", q."description", q."subject", q."level",
            q."intro", q."closing", m."storage_key" AS cover_key
     FROM "quizzes" q
     LEFT JOIN "media_assets" m ON m."id" = q."cover_media_id"
     WHERE (q."slug" = ? OR q."id" = ?) AND q."status" = 'published'
     LIMIT 1`,
  )
    .bind(identifier, identifier)
    .first<QuizRow>();

  if (!quiz) throw new NotFoundError('That quiz could not be found.');

  const [questions, options] = await context.env.DB.batch<Record<string, unknown>>([
    context.env.DB.prepare(
      `SELECT qq."id", qq."prompt", qq."explanation", qq."ekoli_text",
              qq."display_order", a."storage_key" AS audio_key
       FROM "quiz_questions" qq
       LEFT JOIN "media_assets" a ON a."id" = qq."audio_media_id"
       WHERE qq."quiz_id" = ?
       ORDER BY qq."display_order", qq."id"`,
    ).bind(quiz.id),
    context.env.DB.prepare(
      `SELECT o."id", o."question_id", o."label", o."is_correct", o."display_order"
       FROM "quiz_options" o
       INNER JOIN "quiz_questions" qq ON qq."id" = o."question_id"
       WHERE qq."quiz_id" = ?
       ORDER BY o."display_order", o."id"`,
    ).bind(quiz.id),
  ]);

  const byQuestion = new Map<string, Record<string, unknown>[]>();
  for (const option of options?.results ?? []) {
    const key = String(option['question_id']);
    const list = byQuestion.get(key) ?? [];
    list.push({
      id: option['id'],
      label: option['label'],
      is_correct: Number(option['is_correct']) === 1,
    });
    byQuestion.set(key, list);
  }

  const shaped = (questions?.results ?? []).map((question) => ({
    id: question['id'],
    prompt: question['prompt'],
    explanation: question['explanation'],
    ekoli_text: question['ekoli_text'],
    audio_url: question['audio_key']
      ? publicMediaUrl(context.env.PUBLIC_MEDIA_BASE_URL, String(question['audio_key']))
      : null,
    options: byQuestion.get(String(question['id'])) ?? [],
  }));

  return json(
    {
      id: quiz['id'],
      slug: quiz['slug'],
      title: quiz['title'],
      description: quiz['description'],
      subject: quiz['subject'],
      level: quiz['level'],
      intro: quiz['intro'],
      closing: quiz['closing'],
      cover_url: quiz['cover_key'] ? publicMediaUrl(context.env.PUBLIC_MEDIA_BASE_URL, String(quiz['cover_key'])) : null,
      questions: shaped,
    },
    { headers: publicCacheHeaders(300) },
  );
};

// ---------------------------------------------------------------------------
// Editorial — the questions and their options
// ---------------------------------------------------------------------------

/**
 * `PUT /api/editorial/quizzes/:id/questions`
 *
 * The whole question set at once, replacing what was there.
 *
 * A quiz is edited as a document rather than a row at a time: reordering
 * questions, fixing a wrong answer and rewording a prompt are one act of
 * editing, and doing them through six separate endpoints invites a half-saved
 * quiz where two options are both marked correct.
 */
export const replaceQuestions: Handler = async (context: RequestContext) => {
  const actor = requireActor(context);
  const quizId = context.params['id'] ?? '';

  const quiz = await context.env.DB.prepare(`SELECT "id" FROM "quizzes" WHERE "id" = ? LIMIT 1`)
    .bind(quizId)
    .first<{ id: string }>();
  if (!quiz) throw new NotFoundError('That quiz could not be found.');

  const body = await readJsonBody(context.request);
  const incoming = body['questions'];
  if (!Array.isArray(incoming)) {
    throw new ValidationError({ questions: ['Send a list of questions.'] });
  }
  if (incoming.length > 50) {
    throw new ValidationError({ questions: ['A quiz may have at most 50 questions.'] });
  }

  const now = nowIso();
  const statements: D1PreparedStatement[] = [
    context.env.DB.prepare(
      `DELETE FROM "quiz_questions" WHERE "quiz_id" = ?`,
    ).bind(quizId),
  ];

  incoming.forEach((raw, index) => {
    const question = raw as Record<string, unknown>;
    const validated = new Validator(question)
      .string('prompt', { required: true, max: 500, label: 'Question' })
      .string('explanation', { max: 1000, label: 'Explanation' })
      .string('ekoli_text', { max: 300, label: 'Ekoli word or phrase' })
      .validated();

    const options = question['options'];
    if (!Array.isArray(options) || options.length < 2) {
      throw new ValidationError({
        questions: [`Question ${index + 1} needs at least two answers to choose between.`],
      });
    }
    if (options.length > 6) {
      throw new ValidationError({
        questions: [`Question ${index + 1} has more than six answers.`],
      });
    }

    const correct = options.filter(
      (option) => (option as Record<string, unknown>)['is_correct'] === true,
    );
    if (correct.length !== 1) {
      throw new ValidationError({
        questions: [
          `Question ${index + 1} must have exactly one correct answer — it has ${correct.length}.`,
        ],
      });
    }

    const questionId = newId();
    statements.push(
      context.env.DB.prepare(
        `INSERT INTO "quiz_questions"
           ("id", "quiz_id", "prompt", "explanation", "ekoli_text", "audio_media_id",
            "display_order", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      ).bind(
        questionId,
        quizId,
        validated['prompt'],
        validated['explanation'] ?? null,
        validated['ekoli_text'] ?? null,
        typeof question['audio_media_id'] === 'string' ? question['audio_media_id'] : null,
        index,
        now,
        now,
      ),
    );

    options.forEach((rawOption, optionIndex) => {
      const option = rawOption as Record<string, unknown>;
      const label = typeof option['label'] === 'string' ? option['label'].trim() : '';
      if (!label) {
        throw new ValidationError({
          questions: [`An answer on question ${index + 1} has no text.`],
        });
      }
      statements.push(
        context.env.DB.prepare(
          `INSERT INTO "quiz_options"
             ("id", "question_id", "label", "is_correct", "display_order", "created_at", "updated_at")
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
        ).bind(
          newId(),
          questionId,
          label.slice(0, 300),
          option['is_correct'] === true ? 1 : 0,
          optionIndex,
          now,
          now,
        ),
      );
    });
  });

  await context.env.DB.batch(statements);

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: context.user?.email ?? null,
    action: AUDIT_ACTIONS.CONTENT_UPDATED,
    resourceType: 'quizzes',
    resourceId: quizId,
    changes: { questions: incoming.length },
    userAgent: context.request.headers.get('user-agent'),
  });

  return json({ quiz_id: quizId, questions: incoming.length }, { headers: NO_STORE_HEADERS });
};

/**
 * `GET /api/editorial/quizzes/:id/questions`
 *
 * The question set as the composer needs it — drafts included.
 */
export const editorialQuestions: Handler = async (context: RequestContext) => {
  requireActor(context);
  const quizId = context.params['id'] ?? '';

  const [questions, options] = await context.env.DB.batch<Record<string, unknown>>([
    context.env.DB.prepare(
      `SELECT "id", "prompt", "explanation", "ekoli_text", "audio_media_id", "display_order"
       FROM "quiz_questions" WHERE "quiz_id" = ? ORDER BY "display_order", "id"`,
    ).bind(quizId),
    context.env.DB.prepare(
      `SELECT o."id", o."question_id", o."label", o."is_correct", o."display_order"
       FROM "quiz_options" o
       INNER JOIN "quiz_questions" qq ON qq."id" = o."question_id"
       WHERE qq."quiz_id" = ? ORDER BY o."display_order", o."id"`,
    ).bind(quizId),
  ]);

  const byQuestion = new Map<string, Record<string, unknown>[]>();
  for (const option of options?.results ?? []) {
    const key = String(option['question_id']);
    const list = byQuestion.get(key) ?? [];
    list.push({
      id: option['id'],
      label: option['label'],
      is_correct: Number(option['is_correct']) === 1,
    });
    byQuestion.set(key, list);
  }

  return json(
    {
      items: (questions?.results ?? []).map((question) => ({
        ...question,
        options: byQuestion.get(String(question['id'])) ?? [],
      })),
    },
    { headers: NO_STORE_HEADERS },
  );
};
