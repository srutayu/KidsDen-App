const Redis = require('ioredis');
const client = new Redis();
const pub = new Redis();
const sub = new Redis();


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
