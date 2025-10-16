require('dotenv').config();
const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const fromWhatsApp = process.env.TWILIO_WHATSAPP_FROM; // e.g. 'whatsapp:+1415XXXXXXX' or '+1415XXXXXXX'

let client = null;
if (accountSid && authToken) {
  try {
    const Twilio = require('twilio');
    client = Twilio(accountSid, authToken);
  } catch (e) {
    console.warn('[WhatsAppService] twilio module not installed or failed to load:', e.message);
    client = null;
  }
} else {
  console.info('[WhatsAppService] Twilio credentials not configured. WhatsApp messages will be logged only.');
}

async function sendWhatsAppMessage(to, body) {
  if (!to) {
    console.warn('[WhatsAppService] No destination phone provided, skipping WhatsApp send.');
    return;
  }
  // Normalize 'to' and 'from' to whatsapp: format if possible
  const toNumber = to.startsWith('whatsapp:') ? to : `whatsapp:${to}`;
  const fromNumber = fromWhatsApp
    ? (fromWhatsApp.startsWith('whatsapp:') ? fromWhatsApp : `whatsapp:${fromWhatsApp}`)
    : null;

  // Basic validation: Twilio requires both From and To to be of same channel (both whatsapp:)
  if (client && fromNumber) {
    if (!toNumber.startsWith('whatsapp:') || !fromNumber.startsWith('whatsapp:')) {
      const errMsg = `[WhatsAppService] Channel mismatch: From(${fromNumber}) and To(${toNumber}) must both use the whatsapp: channel. Ensure TWILIO_WHATSAPP_FROM is a WhatsApp-enabled Twilio number (format: whatsapp:+123...) and that recipient numbers are in E.164 (e.g. +9112345...) so service can prefix with whatsapp:.`;
      console.error(errMsg);
      throw new Error(errMsg);
    }

    // Log values to help troubleshoot mismatches
    console.log('[WhatsAppService] Sending WhatsApp message. From:', fromNumber, 'To:', toNumber);

    try {
      const msg = await client.messages.create({
        from: fromNumber,
        to: toNumber,
        body
      });
      console.log('[WhatsAppService] Message sent:', msg.sid);
      return msg;
    } catch (err) {
      // Provide clearer guidance when Twilio returns a From/To error
      const message = err && err.message ? err.message : String(err);
      if (message.includes('Invalid From and To pair') || message.includes('From and To should be of the same channel')) {
        console.error('[WhatsAppService] Twilio channel error. Check that TWILIO_WHATSAPP_FROM is a WhatsApp-enabled Twilio number (prefixed with "whatsapp:") and recipient numbers are whatsapp-enabled as well.');
        console.error('[WhatsAppService] Values -> From:', fromNumber, 'To:', toNumber);
      }
      console.error('[WhatsAppService] Error sending message:', message);
      throw err;
    }
  } else {
    // No client configured; log the attempt so devs can see messages in logs
    console.log('[WhatsAppService] (noop) To:', toNumber, 'Body:', body, 'From:', fromWhatsApp || '(not configured)');
    return null;
  }
}

module.exports = { sendWhatsAppMessage };
