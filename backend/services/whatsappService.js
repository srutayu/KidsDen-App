require('dotenv').config();
const https = require('https');

// WhatsApp Cloud API configuration (Meta Graph API)
// Required env vars: WHATSAPP_TOKEN (access token), WHATSAPP_PHONE_NUMBER_ID (phone number id)
const whatsappToken = process.env.WHATSAPP_TOKEN;
const whatsappPhoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID; // numeric id provided by Meta

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
  // Must use WhatsApp Cloud API only
  if (!whatsappToken || !whatsappPhoneNumberId) {
    const errMsg = '[WhatsAppService] WhatsApp Cloud API not configured. Set WHATSAPP_TOKEN and WHATSAPP_PHONE_NUMBER_ID in env.';
    console.error(errMsg);
    throw new Error(errMsg);
  }

  return await sendViaWhatsAppCloud(toE164, body);
}

module.exports = { sendWhatsAppMessage };
