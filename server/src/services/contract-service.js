const crypto = require('crypto');

const { query, withTransaction } = require('../db/pool');
const { httpError } = require('../lib/http-error');
const {
  makeStubExternalId,
  sha256,
  escapeHtml,
  signAccessToken,
  verifyAccessToken,
} = require('../lib/security');
const {
  serializeContract,
  serializeContractEvent,
} = require('../lib/serializers');

const CONTRACT_ACCESS_TTL_MS = 15 * 60 * 1000;
const CONTRACT_DOCUMENT_SCOPE = 'contract_document';

function buildContractFileUrl(contractId) {
  return `/api/contracts/${contractId}/document`;
}

function buildContractPdfFilename(contract) {
  return `${String(contract.documentNumber || contract.id || 'contract')
    .replace(/[^A-Z0-9-]+/gi, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase()}.pdf`;
}

function buildDocumentNumber(orderCode) {
  return `IND-${String(orderCode || '').replace(/[^A-Z0-9-]/gi, '').toUpperCase()}`;
}

function buildContractTitle(orderCode) {
  return `Договор поставки и аренды ${orderCode}`;
}

function buildContractBody(order, items) {
  const lines = items
    .map(
      (item, index) =>
        `${index + 1}. ${item.title} — ${item.quantity} x ${item.unitPrice} ₽${
          item.requiresReturn ? ' (возвратная тара)' : ''
        }`,
    )
    .join('\n');

  return [
    `Заказ: ${order.orderCode}`,
    `Клиент: ${order.customerName}`,
    `Телефон: ${order.customerPhone || 'не указан'}`,
    `Получение: ${order.deliveryType === 'delivery' ? 'доставка' : 'самовывоз'}`,
    `Точка/адрес: ${order.location}`,
    `Оплата: ${order.paymentMethod}`,
    `Сумма: ${order.totalAmount} ₽`,
    '',
    'Состав заказа:',
    lines,
    '',
    'Stub-договор создан автоматически для тестового потока. В production на этом месте будет PDF и интеграция с сервисом электронной подписи.',
  ].join('\n');
}

function transliteratePdfText(value) {
  const map = {
    А: 'A',
    Б: 'B',
    В: 'V',
    Г: 'G',
    Д: 'D',
    Е: 'E',
    Ё: 'E',
    Ж: 'Zh',
    З: 'Z',
    И: 'I',
    Й: 'Y',
    К: 'K',
    Л: 'L',
    М: 'M',
    Н: 'N',
    О: 'O',
    П: 'P',
    Р: 'R',
    С: 'S',
    Т: 'T',
    У: 'U',
    Ф: 'F',
    Х: 'Kh',
    Ц: 'Ts',
    Ч: 'Ch',
    Ш: 'Sh',
    Щ: 'Sch',
    Ъ: '',
    Ы: 'Y',
    Ь: '',
    Э: 'E',
    Ю: 'Yu',
    Я: 'Ya',
    а: 'a',
    б: 'b',
    в: 'v',
    г: 'g',
    д: 'd',
    е: 'e',
    ё: 'e',
    ж: 'zh',
    з: 'z',
    и: 'i',
    й: 'y',
    к: 'k',
    л: 'l',
    м: 'm',
    н: 'n',
    о: 'o',
    п: 'p',
    р: 'r',
    с: 's',
    т: 't',
    у: 'u',
    ф: 'f',
    х: 'kh',
    ц: 'ts',
    ч: 'ch',
    ш: 'sh',
    щ: 'sch',
    ъ: '',
    ы: 'y',
    ь: '',
    э: 'e',
    ю: 'yu',
    я: 'ya',
    '№': 'No.',
    '₽': 'RUB',
    '•': '-',
    '—': '-',
    '–': '-',
    '«': '"',
    '»': '"',
  };

  return String(value || '')
    .split('')
    .map((char) => map[char] ?? char)
    .join('');
}

function wrapPdfLines(value, maxLength = 84) {
  const sourceLines = transliteratePdfText(value).split(/\r?\n/);
  const lines = [];

  for (const sourceLine of sourceLines) {
    const trimmed = sourceLine.trim();
    if (!trimmed) {
      lines.push('');
      continue;
    }

    let current = '';
    for (const word of trimmed.split(/\s+/)) {
      if (!current) {
        current = word;
        continue;
      }
      if (`${current} ${word}`.length <= maxLength) {
        current = `${current} ${word}`;
        continue;
      }
      lines.push(current);
      current = word;
    }

    if (current) {
      lines.push(current);
    }
  }

  return lines;
}

function escapePdfLiteral(value) {
  return String(value || '')
    .replace(/\\/g, '\\\\')
    .replace(/\(/g, '\\(')
    .replace(/\)/g, '\\)');
}

async function recordContractEvent(
  connection,
  { contractId, eventType, status, payload },
) {
  await connection.execute(
    `
      INSERT INTO contract_events (
        id,
        contract_id,
        event_type,
        status,
        payload_json,
        created_at
      )
      VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP(3))
    `,
    [
      crypto.randomUUID(),
      contractId,
      eventType,
      status,
      payload == null ? null : JSON.stringify(payload),
    ],
  );
}

async function createPendingContract(connection, { order, items, currentUser }) {
  const contractId = crypto.randomUUID();
  const now = new Date();
  const documentNumber = buildDocumentNumber(order.orderCode);
  const documentTitle = buildContractTitle(order.orderCode);
  const documentBody = buildContractBody(order, items);
  const signHash = sha256(documentBody);
  const externalId = makeStubExternalId('contract');
  const fileUrl = buildContractFileUrl(contractId);

  await connection.execute(
    `
      INSERT INTO contracts (
        id,
        order_id,
        user_id,
        provider,
        document_number,
        document_title,
        document_body,
        signature_method,
        status,
        external_id,
        file_url,
        sign_hash,
        user_ip,
        device_info,
        stub_mode,
        created_at,
        signed_at,
        last_event_at,
        updated_at
      )
      VALUES (?, ?, ?, 'stub-sign', ?, ?, ?, 'stub-simple-sign', 'pending_signature', ?, ?, ?, NULL, 'stub checkout flow', 1, ?, NULL, ?, ?)
    `,
    [
      contractId,
      order.id,
      currentUser.id,
      documentNumber,
      documentTitle,
      documentBody,
      externalId,
      fileUrl,
      signHash,
      now,
      now,
      now,
    ],
  );

  await recordContractEvent(connection, {
    contractId,
    eventType: 'generated',
    status: 'pending_signature',
    payload: {
      orderId: order.id,
      orderCode: order.orderCode,
      documentNumber,
      fileUrl,
      stubMode: true,
    },
  });

  await recordContractEvent(connection, {
    contractId,
    eventType: 'signature_requested',
    status: 'pending_signature',
    payload: {
      channel: currentUser.email ? 'email' : 'app',
      recipient: currentUser.email || currentUser.login,
    },
  });

  return { id: contractId, fileUrl };
}

async function findLatestContractByOrder(
  orderId,
  connection,
  { forUpdate = false } = {},
) {
  const suffix = forUpdate ? '\n      FOR UPDATE' : '';
  const rows = await query(
    `
      SELECT
        c.id,
        c.order_id,
        c.user_id,
        c.provider,
        c.document_number,
        c.document_title,
        c.document_body,
        c.signature_method,
        c.status,
        c.external_id,
        c.file_url,
        c.sign_hash,
        c.user_ip,
        c.device_info,
        c.stub_mode,
        c.created_at,
        c.signed_at,
        c.last_event_at,
        c.updated_at,
        o.order_code,
        o.customer_name,
        o.customer_phone,
        o.delivery_type,
        o.location,
        o.payment_method,
        o.total_amount
      FROM contracts c
      INNER JOIN orders o ON o.id = c.order_id
      WHERE c.order_id = ?
      ORDER BY c.created_at DESC
      LIMIT 1${suffix}
    `,
    [orderId],
    connection,
  );

  return rows[0] || null;
}

async function loadContractRowById(
  contractId,
  connection,
  { forUpdate = false } = {},
) {
  const suffix = forUpdate ? '\n      FOR UPDATE' : '';
  const rows = await query(
    `
      SELECT
        c.id,
        c.order_id,
        c.user_id,
        c.provider,
        c.document_number,
        c.document_title,
        c.document_body,
        c.signature_method,
        c.status,
        c.external_id,
        c.file_url,
        c.sign_hash,
        c.user_ip,
        c.device_info,
        c.stub_mode,
        c.created_at,
        c.signed_at,
        c.last_event_at,
        c.updated_at
      FROM contracts c
      WHERE c.id = ?
      LIMIT 1${suffix}
    `,
    [contractId],
    connection,
  );

  return rows[0] || null;
}

async function loadContractEvents(contractId, connection) {
  const rows = await query(
    `
      SELECT
        id,
        contract_id,
        event_type,
        status,
        payload_json,
        created_at
      FROM contract_events
      WHERE contract_id = ?
      ORDER BY
        created_at ASC,
        CASE event_type
          WHEN 'generated' THEN 0
          WHEN 'signature_requested' THEN 1
          WHEN 'signed' THEN 2
          WHEN 'rejected' THEN 3
          WHEN 'access_issued' THEN 4
          WHEN 'document_viewed' THEN 5
          WHEN 'document_downloaded' THEN 6
          WHEN 'pdf_viewed' THEN 7
          WHEN 'pdf_downloaded' THEN 8
          ELSE 50
        END ASC,
        id ASC
    `,
    [contractId],
    connection,
  );

  return rows.map(serializeContractEvent);
}

async function markContractSigned(connection, contract, metadata = {}) {
  const userIp = String(metadata.userIp || '').trim() || null;
  const deviceInfo =
    String(metadata.deviceInfo || '').trim() || 'flutter-stub-client';

  await connection.execute(
    `
      UPDATE contracts
      SET
        status = 'signed',
        user_ip = ?,
        device_info = ?,
        signed_at = CURRENT_TIMESTAMP(3),
        last_event_at = CURRENT_TIMESTAMP(3),
        updated_at = CURRENT_TIMESTAMP(3)
      WHERE id = ?
    `,
    [userIp, deviceInfo, contract.id],
  );

  await recordContractEvent(connection, {
    contractId: contract.id,
    eventType: 'signed',
    status: 'signed',
    payload: {
      userIp,
      deviceInfo,
      signatureMethod: 'stub-simple-sign',
    },
  });
}

async function markContractRejected(connection, contract, metadata = {}) {
  const reason = String(metadata.reason || '').trim() || 'stub rejection';

  await connection.execute(
    `
      UPDATE contracts
      SET
        status = 'rejected',
        device_info = ?,
        last_event_at = CURRENT_TIMESTAMP(3),
        updated_at = CURRENT_TIMESTAMP(3)
      WHERE id = ?
    `,
    [String(metadata.deviceInfo || '').trim() || 'stub-system', contract.id],
  );

  await recordContractEvent(connection, {
    contractId: contract.id,
    eventType: 'rejected',
    status: 'rejected',
    payload: { reason },
  });
}

async function assertOrderAccess(orderId, currentUser, connection) {
  const rows = await query(
    `
      SELECT
        id,
        user_id
      FROM orders
      WHERE id = ?
      LIMIT 1
    `,
    [orderId],
    connection,
  );

  const order = rows[0];
  if (!order) {
    throw httpError(404, 'Заказ не найден.');
  }
  if (
    currentUser.role !== 'admin' &&
    currentUser.role !== 'courier' &&
    currentUser.id !== order.user_id
  ) {
    throw httpError(403, 'Недостаточно прав для просмотра договора.');
  }

  return order;
}

function buildContractAccessPayload(contract, currentUser) {
  const expiresAt = new Date(Date.now() + CONTRACT_ACCESS_TTL_MS);
  const token = signAccessToken(
    {
      scope: CONTRACT_DOCUMENT_SCOPE,
      contractId: contract.id,
      orderId: contract.order_id,
      userId: currentUser.id,
    },
    expiresAt,
  );
  const basePath = buildContractFileUrl(contract.id);

  return {
    contractId: contract.id,
    previewUrl: `${basePath}?token=${encodeURIComponent(token)}&format=html`,
    pdfUrl: `${basePath}?token=${encodeURIComponent(token)}&format=pdf`,
    downloadUrl: `${basePath}?token=${encodeURIComponent(token)}&format=pdf&download=1`,
    expiresAt: expiresAt.toISOString(),
  };
}

function getRequestIp(metadata = {}) {
  const forwarded = String(metadata.forwardedFor || '')
    .split(',')
    .map((item) => item.trim())
    .find(Boolean);

  return forwarded || String(metadata.remoteAddress || '').trim() || null;
}

async function issueContractAccessLink(contractId, currentUser) {
  return withTransaction(async (connection) => {
    const contract = await loadContractRowById(contractId, connection);
    if (!contract) {
      throw httpError(404, 'Договор не найден.');
    }

    await assertOrderAccess(contract.order_id, currentUser, connection);
    const access = buildContractAccessPayload(contract, currentUser);

    await recordContractEvent(connection, {
      contractId: contract.id,
      eventType: 'access_issued',
      status: contract.status,
      payload: {
        issuedForUserId: currentUser.id,
        issuedForRole: currentUser.role,
        expiresAt: access.expiresAt,
      },
    });

    return access;
  });
}

async function resolveContractDocument(contractId, options = {}) {
  const {
    currentUser = null,
    token = '',
    format = 'html',
    download = false,
    userAgent = '',
    forwardedFor = '',
    remoteAddress = '',
  } = options;

  return withTransaction(async (connection) => {
    const contract = await loadContractRowById(contractId, connection);
    if (!contract) {
      throw httpError(404, 'Договор не найден.');
    }

    let accessMode = 'signed_link';
    let accessUserId = null;

    if (currentUser) {
      await assertOrderAccess(contract.order_id, currentUser, connection);
      accessMode = 'authenticated';
      accessUserId = currentUser.id;
    } else {
      const payload = verifyAccessToken(token, CONTRACT_DOCUMENT_SCOPE);
      if (payload.contractId !== contract.id) {
        throw httpError(403, 'Ссылка доступа выдана не для этого документа.');
      }
      accessUserId = payload.userId || null;
    }

    await recordContractEvent(connection, {
      contractId: contract.id,
      eventType:
        format === 'pdf'
          ? download
            ? 'pdf_downloaded'
            : 'pdf_viewed'
          : download
          ? 'document_downloaded'
          : 'document_viewed',
      status: contract.status,
      payload: {
        accessMode,
        accessUserId,
        format,
        download,
        userAgent: String(userAgent || '').trim() || null,
        userIp: getRequestIp({ forwardedFor, remoteAddress }),
      },
    });

    const events = await loadContractEvents(contract.id, connection);
    return serializeContract(contract, events);
  });
}

async function getOrderContract(orderId, currentUser) {
  await assertOrderAccess(orderId, currentUser);
  const contract = await findLatestContractByOrder(orderId);
  if (!contract) {
    throw httpError(404, 'Договор для заказа не найден.');
  }
  const events = await loadContractEvents(contract.id);
  return serializeContract(contract, events);
}

async function getContractById(contractId, currentUser) {
  const contract = await loadContractRowById(contractId);
  if (!contract) {
    throw httpError(404, 'Договор не найден.');
  }

  await assertOrderAccess(contract.order_id, currentUser);
  const events = await loadContractEvents(contract.id);
  return serializeContract(contract, events);
}

function renderContractDocumentHtml(contract) {
  const escapedBody = escapeHtml(contract.documentBody || '').replace(
    /\n/g,
    '<br>',
  );
  const signedAt = contract.signedAt
    ? new Date(contract.signedAt).toLocaleString('ru-RU')
    : 'Ожидает подписи';
  const signHash = contract.signHash || '—';

  return `<!doctype html>
<html lang="ru">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${escapeHtml(contract.documentTitle || 'Договор')}</title>
    <style>
      :root { color-scheme: dark; }
      body { font-family: Arial, sans-serif; background:#120d18; color:#f8eef5; margin:0; padding:32px; }
      .card { max-width:960px; margin:0 auto; background:linear-gradient(180deg, rgba(46,26,40,0.98), rgba(31,20,34,0.98)); border:1px solid rgba(255,255,255,0.08); border-radius:28px; padding:30px; box-shadow:0 24px 64px rgba(0,0,0,0.28); }
      .row { display:flex; flex-wrap:wrap; gap:12px; margin:18px 0 20px; }
      .pill { display:inline-block; padding:8px 12px; border-radius:999px; background:#ffffff12; border:1px solid rgba(255,255,255,0.08); }
      .badge { display:inline-block; padding:8px 12px; border-radius:999px; background:#ff8e7a22; color:#ffc16d; font-weight:700; }
      .muted { color:#c8b6c7; }
      .meta { background:#ffffff08; border-radius:20px; padding:16px; border:1px solid rgba(255,255,255,0.06); }
      h1 { margin:14px 0 8px; font-size:32px; }
      h2 { margin:0 0 8px; font-size:18px; }
      pre { white-space:pre-wrap; font-family:inherit; line-height:1.7; margin:0; }
      hr { border-color:rgba(255,255,255,0.08); margin:20px 0; }
      @media print {
        body { background:#fff; color:#111; padding:0; }
        .card { box-shadow:none; border:none; background:#fff; }
        .meta { border:1px solid #ddd; background:#fafafa; }
        .muted { color:#555; }
      }
    </style>
  </head>
  <body>
    <div class="card">
      <div class="badge">STUB CONTRACT</div>
      <h1>${escapeHtml(contract.documentTitle || 'Договор')}</h1>
      <p class="muted">Номер: ${escapeHtml(contract.documentNumber || '—')}</p>
      <div class="row">
        <span class="pill">Статус: ${escapeHtml(contract.status || 'pending_signature')}</span>
        <span class="pill">Подпись: ${escapeHtml(contract.signatureMethod || 'stub-simple-sign')}</span>
        <span class="pill">Подписан: ${escapeHtml(signedAt)}</span>
      </div>
      <div class="meta">
        <h2>Контрольный след документа</h2>
        <p class="muted">sign_hash: ${escapeHtml(signHash)}</p>
        <p class="muted">file_url: ${escapeHtml(contract.fileUrl || '—')}</p>
      </div>
      <hr>
      <pre>${escapedBody}</pre>
    </div>
  </body>
</html>`;
}

function renderContractDocumentPdf(contract) {
  const lines = [
    ...wrapPdfLines(contract.documentTitle || 'Contract'),
    '',
    `Document: ${transliteratePdfText(contract.documentNumber || 'n/a')}`,
    `Status: ${transliteratePdfText(contract.status || 'pending_signature')}`,
    `Signature: ${transliteratePdfText(contract.signatureMethod || 'stub-simple-sign')}`,
    `Signed at: ${contract.signedAt ? new Date(contract.signedAt).toISOString() : 'pending'}`,
    `Hash: ${transliteratePdfText(contract.signHash || '-')}`,
    '',
    ...wrapPdfLines(contract.documentBody || ''),
  ].slice(0, 44);

  const contentLines = ['BT', '/F1 11 Tf', '50 790 Td', '15 TL'];
  for (let index = 0; index < lines.length; index += 1) {
    contentLines.push(`(${escapePdfLiteral(lines[index])}) Tj`);
    if (index < lines.length - 1) {
      contentLines.push('T*');
    }
  }
  contentLines.push('ET');

  const stream = contentLines.join('\n');
  const objects = [
    '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj',
    '2 0 obj << /Type /Pages /Count 1 /Kids [3 0 R] >> endobj',
    '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj',
    '4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj',
    `5 0 obj << /Length ${Buffer.byteLength(stream, 'utf8')} >> stream\n${stream}\nendstream\nendobj`,
  ];

  let pdf = '%PDF-1.4\n';
  const offsets = [0];
  for (const object of objects) {
    offsets.push(Buffer.byteLength(pdf, 'utf8'));
    pdf += `${object}\n`;
  }

  const xrefOffset = Buffer.byteLength(pdf, 'utf8');
  pdf += `xref\n0 ${objects.length + 1}\n`;
  pdf += '0000000000 65535 f \n';
  for (let index = 1; index < offsets.length; index += 1) {
    pdf += `${String(offsets[index]).padStart(10, '0')} 00000 n \n`;
  }
  pdf += `trailer << /Size ${objects.length + 1} /Root 1 0 R >>\n`;
  pdf += `startxref\n${xrefOffset}\n%%EOF`;

  return Buffer.from(pdf, 'utf8');
}

module.exports = {
  createPendingContract,
  findLatestContractByOrder,
  markContractSigned,
  markContractRejected,
  recordContractEvent,
  getOrderContract,
  getContractById,
  issueContractAccessLink,
  resolveContractDocument,
  renderContractDocumentHtml,
  renderContractDocumentPdf,
  buildContractFileUrl,
  buildContractPdfFilename,
};
