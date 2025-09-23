const mongoose = require('mongoose');

const connectChatDB = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI, {
            useNewUrlParser: true,
            useUnifiedTopology: true
        });
        console.log('Chat MongoDB connected successfully');
    } catch (error) {
        console.error('Chat MongoDB connection failed:', error.message);
        process.exit(1);
    }
};

module.exports = connectChatDB;
