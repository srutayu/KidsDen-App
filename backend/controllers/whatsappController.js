require('dotenv').config();

// GET /api/whatsapp/webhook?hub.mode=subscribe&hub.challenge=XXX&hub.verify_token=YYY
exports.verifyWebhook = (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  const VERIFY_TOKEN = process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN;

  if (mode && token) {
    if (mode === 'subscribe' && token === VERIFY_TOKEN) {
      console.log('[WhatsAppWebhook] Verified webhook, returning challenge');
      return res.status(200).send(challenge);
    } else {
      console.warn('[WhatsAppWebhook] Verification failed. Provided token does not match.');
      return res.status(403).send('Forbidden');
    }
  }
  res.status(400).send('Bad Request');
};

// POST /api/whatsapp/webhook
// This will receive notifications from Meta about messages and status updates
exports.receiveWebhook = (req, res) => {
  try {
    const body = req.body;
    console.log('[WhatsAppWebhook] Incoming webhook:', JSON.stringify(body));

    // Example: iterate entries and log statuses
    if (body && body.entry) {
      for (const entry of body.entry) {
        if (entry.changes) {
          for (const change of entry.changes) {
            const value = change.value;
            // Log message statuses if present
            if (value && value.messages) {
              for (const msg of value.messages) {
                console.log(`[WhatsAppWebhook] Message event for ${msg.from}:`, msg);
              }
            }
            if (value && value.statuses) {
              for (const st of value.statuses) {
                console.log(`[WhatsAppWebhook] Message status for ${st.id}: status=${st.status}`, st);
                // Optionally: persist status updates to DB to track deliveries
              }
            }
          }
        }
      }
    }

    // Respond 200 OK quickly to acknowledge receipt
    res.status(200).send('EVENT_RECEIVED');
  } catch (err) {
    console.error('[WhatsAppWebhook] Error processing webhook:', err);
    res.status(500).send('Server Error');
  }
};
