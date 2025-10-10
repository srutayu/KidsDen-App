const { Kafka } = require('kafkajs');
const { saveMessageToDB } = require('../controllers/chatController');

let kafka = null;
if (process.env.KAFKA_DISABLED !== 'true') {
    kafka = new Kafka({
        brokers: [process.env.KAFKA_BROKERS || 'localhost:9092'],
    });
}

let producer = null;

exports.createProducer = async () => {
    if (process.env.KAFKA_DISABLED === 'true') {
        console.log('Kafka is disabled - messages will be saved directly to DB');
        return null;
    }
    
    if (producer) return producer; // Return existing producer if already created
    const _producer = kafka.producer();
    await _producer.connect();
    producer = _producer;
    console.log('Kafka Producer connected');
    return producer;
}

exports.produceMessage = async (data, senderId) => {
  if (process.env.KAFKA_DISABLED === 'true') {
    // Save directly to database when Kafka is disabled
    console.log('Kafka disabled - saving message directly to DB');
    await saveMessageToDB(data, senderId);
    return;
  }
  
  const producer = await this.createProducer();
//   console.log('Producing message to Kafka:', data.message);
  console.log('Data', data);
  await producer.send({
    topic: 'chatMessages',
    messages: [ 
      {
        key: `chatMessage-${Date.now()}`,
        value: JSON.stringify({ classId: data.classId, message: data.message, sender: senderId, senderRole: data.senderRole})
      }
    ]
  });
  return true;
};


exports.startConsumer = async () => {
    const maxRetries = 10;
    const retryDelay = 5000; // 5 seconds
    
    const tryConnect = async (attempt = 1) => {
        try {
            console.log(`Attempting to connect to Kafka consumer (attempt ${attempt}/${maxRetries})`);
            const consumer = kafka.consumer({ groupId: 'chat-group' });
            await consumer.connect();
            await consumer.subscribe({ topic: 'chatMessages', fromBeginning: true });
            
            console.log('Kafka consumer connected and subscribed successfully');

            await consumer.run({autoCommit: true,
                eachMessage: async ({ message , pause}) => {
                    if(!message.value) return;
                    try {
                        const data = JSON.parse(message.value.toString());
                        // console.log('Message consumed from Kafka:', data.sender, data.message);

                        await saveMessageToDB({ classId: data.classId, sender: data.sender.toString(), content: data.message });
                    }catch(err){
                        console.error('Error processing message:', err);
                        pause();
                        setTimeout(() => {
                            console.log('Resuming consumer after error pause');
                            consumer.resume([{ topic: 'chatMessages' }]);
                        }, 60 * 1000)
                    }

                }
            });
        } catch (error) {
            console.error(`Kafka consumer connection attempt ${attempt} failed:`, error.message);
            if (attempt < maxRetries) {
                console.log(`Retrying Kafka connection in ${retryDelay/1000} seconds...`);
                setTimeout(() => tryConnect(attempt + 1), retryDelay);
            } else {
                console.error('Max Kafka connection retries reached. Consumer will not be available.');
            }
        }
    };
    
    // Start connection attempt in background
    tryConnect();
}