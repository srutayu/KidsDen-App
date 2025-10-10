const Redis = require('ioredis');
const client = new Redis({
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379
});
const pub = new Redis({
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379
});
const sub = new Redis({
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379
});


client.on('error', (err) => console.error('Redis Client Error', err));

client.on('connect', () => {
    console.log('Redis client connected');
});


pub.on('connect', () => {
    console.log('Publisher connected');
});


sub.on('connect', () => {
    console.log('Subscriber connected');
});


module.exports = {pub, sub, client};
