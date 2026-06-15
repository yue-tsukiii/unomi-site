/**
 * POST /api/seminar-notify
 * Body: { pageUrl?, pageTitle?, fields: [{ label, value }] }
 *
 * Vercel Project → Settings → Environment Variables:
 *   SMTP_HOST, SMTP_PORT (default 587), SMTP_SECURE (true|false),
 *   SMTP_USER, SMTP_PASS, SMTP_FROM (optional, defaults to SMTP_USER),
 *   SEMINAR_NOTIFY_CC (optional comma-separated extra recipients),
 *   SEMINAR_ALLOWED_ORIGINS (comma-separated, e.g. https://www.unomi-jp.com)
 *
 * On success, sends a second confirmation email to the applicant address parsed
 * from the field whose label contains 会社 + メール (会社のメールアドレス).
 *
 * On Vercel (VERCEL=1), mail is sent inside waitUntil(@vercel/functions) so the
 * HTTP response returns 202 immediately; use SEMINAR_MAIL_SYNC=true to force
 * synchronous sends (e.g. debugging).
 */

const nodemailer = require("nodemailer");

let waitUntilFn = null;
try {
  waitUntilFn = require("@vercel/functions").waitUntil;
} catch (_) {
  /* optional dep path — should not happen after npm install */
}

function parseAllowedOrigins() {
  const raw = process.env.SEMINAR_ALLOWED_ORIGINS || "";
  return raw
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function isAllowedOrigin(origin) {
  if (!origin) return false;
  const list = parseAllowedOrigins();
  if (list.length === 0) {
    if (/^https:\/\/(www\.)?unomi-jp\.com$/i.test(origin)) return true;
    if (process.env.VERCEL === "1" && /\.vercel\.app$/i.test(origin))
      return true;
    // 本地 vercel dev / Live Server 等（仅开发；生产仍建议设 SEMINAR_ALLOWED_ORIGINS）
    if (/^http:\/\/(127\.0\.0\.1|localhost)(:\d+)?$/i.test(origin)) return true;
    return false;
  }
  return list.some((o) => origin === o);
}

function setCors(res, origin) {
  if (origin && isAllowedOrigin(origin)) {
    res.setHeader("Access-Control-Allow-Origin", origin);
    res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
    res.setHeader("Access-Control-Max-Age", "86400");
  }
  res.setHeader("Vary", "Origin");
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function simpleValidEmail(s) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/i.test(String(s || "").trim());
}

/** フォームの「会社のメールアドレス」欄から送信者メールを取得 */
function findApplicantEmail(rows) {
  for (const r of rows) {
    const l = String(r.label || "");
    if (l.includes("会社") && l.includes("メール")) {
      const v = String(r.value || "").trim();
      return simpleValidEmail(v) ? v : "";
    }
  }
  for (const r of rows) {
    const l = String(r.label || "");
    if (l.includes("メールアドレス")) {
      const v = String(r.value || "").trim();
      return simpleValidEmail(v) ? v : "";
    }
  }
  return "";
}

/**
 * Internal notify + applicant confirmation. Throws if internal sendMail fails.
 * @returns {{ confirmationSent: boolean }}
 */
async function deliverSeminarMail({
  transporter,
  from,
  to,
  cc,
  body,
  text,
  html,
  lines,
  htmlRows,
  rows,
}) {
  await transporter.sendMail({
    from,
    to,
    cc: cc.length ? cc.join(", ") : undefined,
    subject: `[セミナーお申し込み] ${body.pageTitle || "UNOMI"}`,
    text,
    html,
  });

  let confirmationSent = false;
  const applicant = findApplicantEmail(rows);
  if (applicant && applicant.toLowerCase() !== to.toLowerCase()) {
    const seminarTitle = body.pageTitle || "セミナー";
    const confirmSubject = `[UNOMI] セミナーお申し込みの確認（自動送信）`;

    const confirmLetter =
      "この度は、株式会社UNOMI主催セミナーへお申し込みいただき、誠にありがとうございます。\n\n" +
      "お申し込みを確認いたしました。\n\n" +
      "当日の詳細情報（受付方法・会場案内・ご参加に関するご連絡等）につきましては、後日あらためて個別にメールにてご案内させていただきますので、今しばらくお待ちくださいませ。\n\n" +
      "皆様にお会いできることを、心より楽しみにしております。\n\n" +
      "引き続き、どうぞよろしくお願いいたします。\n\n" +
      "株式会社UNOMI";

    const confirmText =
      confirmLetter +
      "\n\n---\n【お申し込み内容】\n" +
      lines.join("\n") +
      "\n\n---\n" +
      `イベント: ${seminarTitle}\n受付: ${new Date().toISOString()}\n\n※本メールは送信専用の自動通知です。`;

    const confirmHtml = `<!DOCTYPE html><html><head><meta charset="utf-8"/></head><body>
<p>この度は、株式会社UNOMI主催セミナーへお申し込みいただき、誠にありがとうございます。</p>
<p>お申し込みを確認いたしました。</p>
<p>当日の詳細情報（受付方法・会場案内・ご参加に関するご連絡等）につきましては、後日あらためて個別にメールにてご案内させていただきますので、今しばらくお待ちくださいませ。</p>
<p>皆様にお会いできることを、心より楽しみにしております。</p>
<p>引き続き、どうぞよろしくお願いいたします。</p>
<p>株式会社UNOMI</p>
<hr style="border:none;border-top:1px solid #e2e4eb;margin:24px 0;" />
<p style="font-weight:bold;margin-bottom:8px;">お申し込み内容</p>
<table cellspacing="0" cellpadding="0" style="border-collapse:collapse;">${htmlRows}</table>
<p style="margin-top:16px;font-size:12px;color:#666;">${escapeHtml(
      seminarTitle
    )}<br>${escapeHtml(
      new Date().toLocaleString("ja-JP", { timeZone: "Asia/Tokyo" })
    )}（受付）<br><span style="color:#888;">※本メールは送信専用の自動通知です。</span></p>
</body></html>`;
    try {
      await transporter.sendMail({
        from,
        to: applicant,
        subject: confirmSubject,
        text: confirmText,
        html: confirmHtml,
      });
      confirmationSent = true;
    } catch (e) {
      console.error("seminar-notify confirmation sendMail:", e);
    }
  } else if (applicant && applicant.toLowerCase() === to.toLowerCase()) {
    confirmationSent = true;
  }

  return { confirmationSent };
}

module.exports = async (req, res) => {
  const origin = req.headers.origin || "";

  if (req.method === "OPTIONS") {
    setCors(res, origin);
    return res.status(204).end();
  }

  if (req.method !== "POST") {
    res.setHeader("Allow", "POST, OPTIONS");
    return res.status(405).json({ error: "Method not allowed" });
  }

  if (!isAllowedOrigin(origin)) {
    return res.status(403).json({ error: "Forbidden" });
  }
  setCors(res, origin);

  let body = req.body;
  if (typeof body === "string") {
    try {
      body = JSON.parse(body || "{}");
    } catch {
      return res.status(400).json({ error: "Invalid JSON" });
    }
  }

  const fields = body && body.fields;
  if (!Array.isArray(fields) || fields.length === 0) {
    return res.status(400).json({ error: "Missing fields" });
  }

  const host = process.env.SMTP_HOST;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  if (!host || !user || !pass) {
    console.error("seminar-notify: missing SMTP_HOST / SMTP_USER / SMTP_PASS");
    return res.status(503).json({ error: "Mail not configured" });
  }

  const port = Number(process.env.SMTP_PORT || "587");
  const secure =
    process.env.SMTP_SECURE === "true" ||
    process.env.SMTP_SECURE === "1" ||
    port === 465;

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure,
    auth: { user, pass },
  });

  /** 申込内容の受信先（固定） */
  const to = "hby@unomi-jp.com";
  const from = process.env.SMTP_FROM || user;
  const ccRaw = process.env.SEMINAR_NOTIFY_CC || "";
  const cc = ccRaw
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
    .filter((e) => e.toLowerCase() !== to.toLowerCase());

  const rows = fields.map(({ label, value }) => {
    const l = String(label || "").replace(/\s+/g, " ").trim();
    const v = value == null ? "" : String(value);
    return { label: l, value: v };
  });

  const lines = rows.map(({ label, value }) => `${label}: ${value}`);

  const footer = [
    "",
    "---",
    `page: ${body.pageUrl || ""}`,
    `title: ${body.pageTitle || ""}`,
    `sentAt: ${new Date().toISOString()}`,
  ].join("\n");

  const text = lines.join("\n") + "\n" + footer;

  const htmlRows = rows
    .map(
      ({ label, value }) =>
        `<tr><th align="left" style="padding:8px;border:1px solid #ccc;">${escapeHtml(
          label
        )}</th><td style="padding:8px;border:1px solid #ccc;">${escapeHtml(
          value
        )}</td></tr>`
    )
    .join("");
  const html = `<!DOCTYPE html><html><head><meta charset="utf-8"/></head><body>
<p>セミナーお申し込みフォームの送信内容です。</p>
<table cellspacing="0" cellpadding="0" style="border-collapse:collapse;">${htmlRows}</table>
<pre style="margin-top:16px;font-size:12px;color:#444;">${escapeHtml(
    footer
  )}</pre>
</body></html>`;

  const mailPayload = {
    transporter,
    from,
    to,
    cc,
    body,
    text,
    html,
    lines,
    htmlRows,
    rows,
  };

  const useBackground =
    typeof waitUntilFn === "function" &&
    process.env.VERCEL === "1" &&
    process.env.SEMINAR_MAIL_SYNC !== "true";

  if (useBackground) {
    waitUntilFn(
      deliverSeminarMail(mailPayload).catch((e) => {
        console.error("seminar-notify background deliver failed:", e);
      })
    );
    return res.status(202).json({ ok: true, accepted: true });
  }

  try {
    const { confirmationSent } = await deliverSeminarMail(mailPayload);
    return res.status(200).json({ ok: true, confirmationSent });
  } catch (e) {
    console.error("seminar-notify sendMail:", e);
    const out = { error: "Send failed" };
    if (e && typeof e.code === "string") out.code = e.code;
    if (e && typeof e.responseCode === "number")
      out.responseCode = e.responseCode;
    if (e && typeof e.command === "string") out.command = e.command;
    return res.status(502).json(out);
  }
};
