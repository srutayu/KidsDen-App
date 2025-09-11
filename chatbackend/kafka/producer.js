const { Kafka } = require('kafkajs');
const { saveMessageToDB } = require('../controllers/chatController');

const kafka = new Kafka({
    brokers: ['localhost:9092'],
});

let producer = null;

exports.createProducer = async () => {
    if (producer) return producer; // Return existing producer if already created
    const _producer = kafka.producer();
    await _producer.connect();
    producer = _producer;
    console.log('Kafka Producer connected');
    return producer;
}

exports.produceMessage = async (data, senderId) => {
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
    const consumer =  kafka.consumer({ groupId: 'chat-group' });
    await consumer.connect();
    await consumer.subscribe({ topic: 'chatMessages', fromBeginning: true });

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
}