// require('dotenv').config();
// const https = require('https');

// // WhatsApp Cloud API configuration (Meta Graph API)
// // Required env vars: WHATSAPP_TOKEN (access token), WHATSAPP_PHONE_NUMBER_ID (phone number id)
// const whatsappToken = process.env.WHATSAPP_TOKEN;
// const whatsappPhoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID; // numeric id provided by Meta

// function sendViaWhatsAppCloud(toE164, message) {
//   return new Promise((resolve, reject) => {
//     if (!whatsappToken || !whatsappPhoneNumberId) {
//       return reject(new Error('WhatsApp Cloud API not configured (WHATSAPP_TOKEN or WHATSAPP_PHONE_NUMBER_ID missing)'));
//     }

//     const postData = JSON.stringify({
//       messaging_product: 'whatsapp',
//       to: toE164.replace(/^\+/, ''), // WhatsApp Cloud expects phone number without + in 'to'
//       type: 'text',
//       text: { preview_url: false, body: message }
//     });

//     const options = {
//       hostname: 'graph.facebook.com',
//       path: `/v22.0/${whatsappPhoneNumberId}/messages`,
//       method: 'POST',
//       headers: {
//         'Content-Type': 'application/json',
//         'Content-Length': Buffer.byteLength(postData),
//         Authorization: `Bearer ${whatsappToken}`
//       }
//     };

//     const req = https.request(options, (res) => {
//       let data = '';
//       res.on('data', (chunk) => (data += chunk));
//       res.on('end', () => {
//         if (res.statusCode >= 200 && res.statusCode < 300) {
//           try {
//             const parsed = JSON.parse(data);
//             console.log('[WhatsAppService] WhatsApp Cloud message sent:', parsed);
//             resolve(parsed);
//           } catch (e) {
//             resolve({ raw: data });
//           }
//         } else {
//           console.error('[WhatsAppService] WhatsApp Cloud API error', res.statusCode, data);
//           reject(new Error(`WhatsApp Cloud API error: ${res.statusCode} ${data}`));
//         }
//       });
//     });

//     req.on('error', (e) => {
//       console.error('[WhatsAppService] Request error sending to WhatsApp Cloud API', e);
//       reject(e);
//     });

//     req.write(postData);
//     req.end();
//   });
// }

// async function sendWhatsAppMessage(to, body) {
//   if (!to) {
//     console.warn('[WhatsAppService] No destination phone provided, skipping WhatsApp send.');
//     return;
//   }

//   // to should be in E.164 format: +911234567890
//   const toE164 = to.startsWith('+') ? to : `+${to.replace(/^whatsapp:/, '')}`;
//   // Must use WhatsApp Cloud API only
//   if (!whatsappToken || !whatsappPhoneNumberId) {
//     const errMsg = '[WhatsAppService] WhatsApp Cloud API not configured. Set WHATSAPP_TOKEN and WHATSAPP_PHONE_NUMBER_ID in env.';
//     console.error(errMsg);
//     throw new Error(errMsg);
//   }

//   return await sendViaWhatsAppCloud(toE164, body);
// }

// module.exports = { sendWhatsAppMessage };


// services/whatsappService.js
const { Client, LocalAuth, MessageMedia } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');

let client;

async function initWhatsApp() {
  if (client) return client;

  client = new Client({
    puppeteer: {
    executablePath: '/usr/bin/chromium-browser',
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  },
    authStrategy: new LocalAuth({ dataPath: './.wwebjs_auth' }),
  });

  client.on('qr', qr => {
    console.clear();
    qrcode.generate(qr, { small: true });
    console.log('📱 Scan this QR using WhatsApp → Linked Devices');
  });

  client.on('ready', () => {
    console.log('✅ WhatsApp client ready');
  });

  client.on('disconnected', reason => {
    console.log('⚠️ Client disconnected:', reason);
    client.initialize();
  });

  await client.initialize();
  return client;
}

async function sendTextMessage(toE164, message) {
  if (!client) await initWhatsApp();

  const chatId = `${toE164.replace(/^\+/, '')}@c.us`;
  try {
    await client.sendMessage(chatId, message);
    console.log(`✅ Message sent to ${toE164}`);
    return { success: true };
  } catch (err) {
    console.error(`❌ Failed to send message to ${toE164}:`, err);
    return { success: false, error: err.message };
  }
}

async function sendMediaMessage(toE164, fileUrl, caption = '') {
  if (!client) await initWhatsApp();

  const chatId = `${toE164.replace(/^\+/, '')}@c.us`;
  try {
    const media = await MessageMedia.fromUrl(fileUrl);
    await client.sendMessage(chatId, media, { caption });
    console.log(`✅ Media sent to ${toE164}`);
    return { success: true };
  } catch (err) {
    console.error(`❌ Failed to send media to ${toE164}:`, err);
    return { success: false, error: err.message };
  }
}

module.exports = {
  initWhatsApp,
  sendTextMessage,
  sendMediaMessage,
};
