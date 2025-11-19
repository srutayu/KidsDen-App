const mongoose = require('mongoose');

const chatVersionSchema = new mongoose.Schema({
  classId: { type: String, required: true, unique: true },
  version: { type: Number, default: 0 },
  lastMessageTimestamp: { type: Date, default: null }
});

module.exports = mongoose.model('chatVersion', chatVersionSchema);
