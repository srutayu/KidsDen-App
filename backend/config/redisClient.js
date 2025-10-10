const redis = require('redis');
const client = redis.createClient({
    url: `redis://${process.env.REDIS_HOST || 'localhost'}:${process.env.REDIS_PORT || 6379}`
});

client.on('error', (err) => console.error('Redis Client Error', err));

(async () => {
    try{
        await client.connect();
        console.log('Redis client connected');
    }catch(err){
        console.error('Redis connection error:', err);
    }
})();

module.exports = client;