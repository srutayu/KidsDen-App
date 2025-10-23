require('dotenv').config();
const https = require('https');
const querystring = require('querystring');
const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const fromWhatsApp = process.env.TWILIO_WHATSAPP_FROM; // e.g. 'whatsapp:+1415XXXXXXX' or '+1415XXXXXXX'

// WhatsApp Cloud API configuration (Meta Graph API)
// Required env vars: WHATSAPP_TOKEN (access token), WHATSAPP_PHONE_NUMBER_ID (phone number id)
const whatsappToken = process.env.WHATSAPP_TOKEN;
const whatsappPhoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID; // numeric id provided by Meta

let twilioClient = null;
if (accountSid && authToken) {
  try {
    const Twilio = require('twilio');
    twilioClient = Twilio(accountSid, authToken);
  } catch (e) {
    console.warn('[WhatsAppService] twilio module not installed or failed to load:', e.message);
    twilioClient = null;
  }
} else {
  console.info('[WhatsAppService] Twilio credentials not configured. Twilio fallback disabled.');
}

function sendViaWhatsAppCloud(toE164, message) {
  return new Promise((resolve, reject) => {
    if (!whatsappToken || !whatsappPhoneNumberId) {
      return reject(new Error('WhatsApp Cloud API not configured (WHATSAPP_TOKEN or WHATSAPP_PHONE_NUMBER_ID missing)'));
    }

    const postData = JSON.stringify({
      messaging_product: 'whatsapp',
      to: toE164.replace(/^\+/, ''), // WhatsApp Cloud expects phone number without + in 'to'
      type: 'text',
      text: { preview_url: false, body: message }
    });

    const options = {
      hostname: 'graph.facebook.com',
      path: `/v22.0/${whatsappPhoneNumberId}/messages`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
        Authorization: `Bearer ${whatsappToken}`
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            const parsed = JSON.parse(data);
            console.log('[WhatsAppService] WhatsApp Cloud message sent:', parsed);
            resolve(parsed);
          } catch (e) {
            resolve({ raw: data });
          }
        } else {
          console.error('[WhatsAppService] WhatsApp Cloud API error', res.statusCode, data);
          reject(new Error(`WhatsApp Cloud API error: ${res.statusCode} ${data}`));
        }
      });
    });

    req.on('error', (e) => {
      console.error('[WhatsAppService] Request error sending to WhatsApp Cloud API', e);
      reject(e);
    });

    req.write(postData);
    req.end();
  });
}

async function sendWhatsAppMessage(to, body) {
  if (!to) {
    console.warn('[WhatsAppService] No destination phone provided, skipping WhatsApp send.');
    return;
  }

  // to should be in E.164 format: +911234567890
  const toE164 = to.startsWith('+') ? to : `+${to.replace(/^whatsapp:/, '')}`;

  // Try WhatsApp Cloud API first if configured
  if (whatsappToken && whatsappPhoneNumberId) {
    try {
      return await sendViaWhatsAppCloud(toE164, body);
    } catch (err) {
      console.error('[WhatsAppService] WhatsApp Cloud API send failed:', err.message);
      // Fallthrough to Twilio fallback if available
    }
  }

  // Twilio fallback (if Twilio configured)
  const toNumber = to.startsWith('whatsapp:') ? to : `whatsapp:${toE164}`;
  const fromNumber = fromWhatsApp
    ? (fromWhatsApp.startsWith('whatsapp:') ? fromWhatsApp : `whatsapp:${fromWhatsApp}`)
    : null;

  if (twilioClient && fromNumber) {
    if (!toNumber.startsWith('whatsapp:') || !fromNumber.startsWith('whatsapp:')) {
      const errMsg = `[WhatsAppService] Channel mismatch: From(${fromNumber}) and To(${toNumber}) must both use the whatsapp: channel. Ensure TWILIO_WHATSAPP_FROM is a WhatsApp-enabled Twilio number (format: whatsapp:+123...) and that recipient numbers are in E.164.`;
      console.error(errMsg);
      throw new Error(errMsg);
    }

    console.log('[WhatsAppService] Sending via Twilio. From:', fromNumber, 'To:', toNumber);
    try {
      const msg = await twilioClient.messages.create({ from: fromNumber, to: toNumber, body });
      console.log('[WhatsAppService] Twilio message sent:', msg.sid);
      return msg;
    } catch (err) {
      console.error('[WhatsAppService] Twilio send failed:', err && err.message ? err.message : err);
      throw err;
    }
  }

  // No provider configured: log only
  console.log('[WhatsAppService] (noop) To:', toE164, 'Body:', body, 'Providers:', {
    whatsappCloud: !!(whatsappToken && whatsappPhoneNumberId),
    twilio: !!twilioClient
  });
  return null;
}

module.exports = { sendWhatsAppMessage };
