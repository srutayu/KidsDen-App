// const express = require('express');
// const router = express.Router();
// const { verifyWebhook, receiveWebhook } = require('../controllers/whatsappController');

// // Verification endpoint (GET) and webhook receiver (POST)
// router.get('/webhook', verifyWebhook);
// router.post('/webhook', receiveWebhook);

// module.exports = router;

// routes/whatsappRoutes.js
const express = require('express');
const router = express.Router();
const { sendMessage } = require('../controllers/whatsappController');

// Route to send WhatsApp message
router.post('/send-message', sendMessage);

module.exports = router;
