function toIso(value) {
  if (!value) {
    return null;
  }

  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return null;
  }
  return date.toISOString();
}

function serializeRiskSummary(risk) {
  if (!risk) {
    return {
      canCreateOrders: true,
      isBlocked: false,
      overdueActiveOrders: 0,
      overdueOrderCodes: [],
      maxOverdueDays: 0,
      blockCode: null,
      blockReason: null,
      blockSource: null,
      blockedAt: null,
      blockedUntil: null,
      oldestOverdueIssuedAt: null,
    };
  }

  return {
    canCreateOrders: Boolean(risk.canCreateOrders),
    isBlocked: Boolean(risk.isBlocked),
    overdueActiveOrders: Number(risk.overdueActiveOrders || 0),
    overdueOrderCodes: Array.isArray(risk.overdueOrderCodes)
      ? risk.overdueOrderCodes
      : [],
    maxOverdueDays: Number(risk.maxOverdueDays || 0),
    blockCode: risk.blockCode || null,
    blockReason: risk.blockReason || null,
    blockSource: risk.blockSource || null,
    blockedAt: risk.blockedAt || null,
    blockedUntil: risk.blockedUntil || null,
    oldestOverdueIssuedAt: risk.oldestOverdueIssuedAt || null,
  };
}

function serializeUser(row, risk = null) {
  return {
    id: row.id,
    login: row.login,
    email: row.email || '',
    fullName: row.full_name,
    phone: row.phone || '',
    role: row.role,
    risk: serializeRiskSummary(risk),
    emailVerifiedAt: toIso(row.email_verified_at),
    phoneVerifiedAt: toIso(row.phone_verified_at),
    createdAt: toIso(row.created_at) || new Date().toISOString(),
  };
}

function maskTargetValue(channel, value) {
  const normalized = String(value || '').trim();
  if (!normalized) {
    return '';
  }

  if (channel === 'email') {
    const [localPart, domain = 'example.com'] = normalized.split('@');
    if (!localPart) {
      return normalized;
    }
    const visible = localPart.slice(0, 2);
    return `${visible}${'*'.repeat(Math.max(localPart.length - visible.length, 1))}@${domain}`;
  }

  const digits = normalized.replace(/\D/g, '');
  if (digits.length < 4) {
    return normalized;
  }

  const visibleStart = digits.slice(0, 2);
  const visibleEnd = digits.slice(-2);
  return `+${visibleStart}${'*'.repeat(Math.max(digits.length - 4, 3))}${visibleEnd}`;
}

function serializeVerification(row) {
  return {
    id: row.id,
    purpose: row.purpose,
    channel: row.channel,
    provider: row.provider,
    targetValue: row.target_value,
    maskedTarget: maskTargetValue(row.channel, row.target_value),
    status: row.status,
    stubCode: row.code_preview || '',
    externalId: row.external_id || null,
    attemptCount: Number(row.attempt_count || 0),
    maxAttempts: Number(row.max_attempts || 0),
    expiresAt: toIso(row.expires_at),
    verifiedAt: toIso(row.verified_at),
    createdAt: toIso(row.created_at) || new Date().toISOString(),
  };
}

function serializeVerificationState(user, steps) {
  const requiresEmail = Boolean(user.email) && !user.email_verified_at;
  const requiresPhone = Boolean(user.phone) && !user.phone_verified_at;
  const nextChannel = requiresEmail ? 'email' : requiresPhone ? 'phone' : null;
  const currentStep =
    (nextChannel
      ? steps.find((item) => item.channel === nextChannel)
      : null) ||
    steps[0] ||
    null;

  return {
    required: Boolean(nextChannel),
    nextChannel,
    currentStep,
    steps,
    emailVerifiedAt: toIso(user.email_verified_at),
    phoneVerifiedAt: toIso(user.phone_verified_at),
  };
}

function serializeConfig(row) {
  return {
    promoVideoId: row.promo_video_id,
    safetyVideoId: row.safety_video_id,
    supportPhone: row.support_phone,
    brandMessage: row.brand_message,
  };
}

function serializeProduct(row) {
  return {
    id: row.id,
    title: row.title,
    subtitle: row.subtitle,
    category: row.category,
    price: Number(row.price || 0),
    stock: Number(row.stock || 0),
    unitLabel: row.unit_label,
    requiresReturn: Boolean(row.requires_return),
    featured: Boolean(row.featured),
    isVisible: row.is_visible === undefined ? true : Boolean(row.is_visible),
    tint: row.tint,
    previewImageUrl: row.preview_image_url || null,
  };
}

function serializeOrderItem(row) {
  return {
    productId: row.product_id,
    title: row.title_snapshot,
    quantity: Number(row.quantity || 0),
    unitPrice: Number(row.unit_price || 0),
    requiresReturn: Boolean(row.requires_return),
  };
}

function serializeCylinderLog(row) {
  return {
    id: row.id,
    orderId: row.order_id,
    orderItemId: row.order_item_id || null,
    qrCode: row.qr_code || null,
    serialNumber: row.cylinder_serial_number || '',
    quantity: Number(row.quantity || 1),
    status: row.status,
    issuedAt: toIso(row.issued_at),
    returnedAt: toIso(row.returned_at),
    createdAt: toIso(row.created_at) || new Date().toISOString(),
  };
}

function serializeOrder(row, items, cylinderLogs = []) {
  const issuedSerials = cylinderLogs
    .map((log) => log.serialNumber)
    .filter((value) => value && value !== 'UNASSIGNED');

  return {
    id: row.id,
    orderCode: row.order_code,
    userId: row.user_id,
    customerName: row.customer_name,
    customerPhone: row.customer_phone || '',
    deliveryType: row.delivery_type,
    location: row.location,
    paymentMethod: row.payment_method,
    paymentMask: row.payment_mask || '',
    status: row.status,
    totalAmount: Number(row.total_amount || 0),
    createdAt: toIso(row.created_at) || new Date().toISOString(),
    items,
    cylinderLogs,
    cylinderSerial: row.cylinder_serial || issuedSerials.join(', ') || null,
    issuedAt: toIso(row.issued_at),
    returnedAt: toIso(row.returned_at),
    contractId: row.contract_id || null,
    contractStatus: row.contract_status || null,
    contractDocumentUrl: row.contract_file_url || null,
    paymentId: row.payment_id || null,
    paymentStatus: row.payment_status || null,
  };
}

function parseEventPayload(value) {
  if (!value) {
    return null;
  }

  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function serializeContractEvent(row) {
  return {
    id: row.id,
    contractId: row.contract_id,
    eventType: row.event_type,
    status: row.status,
    payload: parseEventPayload(row.payload_json),
    createdAt: toIso(row.created_at) || new Date().toISOString(),
  };
}

function serializeContract(row, events = []) {
  return {
    id: row.id,
    orderId: row.order_id,
    userId: row.user_id,
    provider: row.provider,
    documentNumber: row.document_number || '',
    documentTitle: row.document_title || '',
    documentBody: row.document_body || '',
    signatureMethod: row.signature_method || 'stub-simple-sign',
    status: row.status,
    externalId: row.external_id || null,
    fileUrl: row.file_url || null,
    signHash: row.sign_hash || null,
    userIp: row.user_ip || null,
    deviceInfo: row.device_info || null,
    stubMode: Boolean(row.stub_mode),
    createdAt: toIso(row.created_at) || new Date().toISOString(),
    signedAt: toIso(row.signed_at),
    lastEventAt: toIso(row.last_event_at),
    events,
  };
}

function serializePaymentEvent(row) {
  return {
    id: row.id,
    paymentId: row.payment_id,
    eventType: row.event_type,
    status: row.status,
    amount: row.amount == null ? null : Number(row.amount),
    providerEventId: row.provider_event_id || null,
    payload: parseEventPayload(row.payload_json),
    createdAt: toIso(row.created_at) || new Date().toISOString(),
  };
}

function serializePayment(row, events = []) {
  return {
    id: row.id,
    orderId: row.order_id,
    provider: row.provider,
    method: row.method,
    status: row.status,
    amount: Number(row.amount || 0),
    currency: row.currency || 'RUB',
    paymentMask: row.payment_mask || '',
    externalId: row.external_id || null,
    providerReference: row.provider_reference || null,
    failureReason: row.failure_reason || null,
    stubMode: Boolean(row.stub_mode),
    createdAt: toIso(row.created_at) || new Date().toISOString(),
    paidAt: toIso(row.paid_at),
    lastEventAt: toIso(row.last_event_at),
    events,
  };
}

module.exports = {
  serializeUser,
  serializeRiskSummary,
  serializeVerification,
  serializeVerificationState,
  serializeConfig,
  serializeProduct,
  serializeOrderItem,
  serializeCylinderLog,
  serializeOrder,
  serializeContractEvent,
  serializeContract,
  serializePaymentEvent,
  serializePayment,
  toIso,
};
