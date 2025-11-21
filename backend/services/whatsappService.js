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
const fs = require('fs');

let client = null;

async function initWhatsApp() {
  if (client) return client;

  // Build puppeteer options with a sensible executablePath if available.
  const puppeteerOptions = { args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'] };

  let exePath = process.env.PUPPETEER_EXECUTABLE_PATH || process.env.CHROME_PATH || '';
  if (!exePath) {
    if (process.platform === 'win32') {
      const candidates = [
        'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
        'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe'
      ];
      exePath = candidates.find(p => fs.existsSync(p));
    } else if (process.platform === 'linux') {
      const candidates = ['/usr/bin/chromium-browser', '/usr/bin/chromium', '/usr/bin/google-chrome-stable', '/usr/bin/google-chrome'];
      exePath = candidates.find(p => fs.existsSync(p));
    } else if (process.platform === 'darwin') {
      const candidates = ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'];
      exePath = candidates.find(p => fs.existsSync(p));
    }
  }

  if (exePath) {
    puppeteerOptions.executablePath = exePath;
    console.log('[WhatsAppService] Using browser executable:', exePath);
  } else {
    console.warn('[WhatsAppService] No browser executable found automatically. Set PUPPETEER_EXECUTABLE_PATH or CHROME_PATH env var, or install Chrome/Chromium in the container.');
  }

  const { Client, RemoteAuth } = require('whatsapp-web.js');
  const { AwsS3Store } = require('wwebjs-aws-s3');
  const {
    S3Client,
    PutObjectCommand,
    HeadObjectCommand,
    GetObjectCommand,
    DeleteObjectCommand
  } = require('@aws-sdk/client-s3');

  const s3 = new S3Client({
    region: process.env.AWS_REGION,
    credentials: {
      accessKeyId: process.env.AWS_ACCESS_KEY_ID,
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    }
  });

  const putObjectCommand = PutObjectCommand;
  const headObjectCommand = HeadObjectCommand;
  const getObjectCommand = GetObjectCommand;
  const deleteObjectCommand = DeleteObjectCommand;

  const store = new AwsS3Store({
    bucketName: 'kidsden-bucket',
    remoteDataPath: 'whatsapp/session',
    s3Client: s3,
    putObjectCommand,
    headObjectCommand,
    getObjectCommand,
    deleteObjectCommand
  });

  client = new Client({
    puppeteer: puppeteerOptions,
    authStrategy: new RemoteAuth({
      clientId: 'AWS',
      dataPath: 'whatsapp-session',
      store: store,
      backupSyncIntervalMs: 600000
    })
  });


  client.on('qr', qr => {
    console.clear();
    qrcode.generate(qr, { small: true });
    console.log('📱 Scan this QR using WhatsApp → Linked Devices');
  });

  client.on('ready', () => {
    console.log('✅ WhatsApp client ready');
  });

  client.on('remote_session_saved', () => {
    console.log('Session saved on S3');
  });


  client.on('disconnected', reason => {
    console.log('⚠️ Client disconnected:', reason);
    setTimeout(() => {
      if (client) {
        client.initialize().catch(err => console.error('[WhatsAppService] Error re-initializing client after disconnect:', err));
      }
    }, 5000);
  });

  try {
    await client.initialize();
    return client;
  } catch (err) {
    console.error('[WhatsAppService] Failed to initialize WhatsApp client (puppeteer/browser error):', err && err.message ? err.message : err);
    // client.destroy() is async and may reject; await and catch so the rejection doesn't bubble out.
    try {
      if (client && typeof client.destroy === 'function') {
        await client.destroy().catch(() => {});
      }
    } catch (e) { /* ignore */ }
    client = null;
    return null;
  }
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
