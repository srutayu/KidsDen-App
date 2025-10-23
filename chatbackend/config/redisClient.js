const Redis = require('ioredis');

// Allow disabling Redis in local dev by setting REDIS_DISABLED=true in .env
if (process.env.REDIS_DISABLED === 'true') {
    console.warn('REDIS_DISABLED is true — providing no-op Redis pub/sub clients for local dev');
    const EventEmitter = require('events');
    const emitter = new EventEmitter();

    const client = {
        on: (ev, cb) => {},
        get: async () => null,
        set: async () => true
    };

    const pub = {
        publish: async (channel, message) => {
            // emit locally so subscriber stub can receive it
            emitter.emit('message', channel, message);
            return 1;
        },
        on: () => {}
    };

    const sub = {
        subscribe: async (channel) => {
            // noop
            return 'OK';
        },
        on: (ev, cb) => {
            if (ev === 'message') {
                emitter.on('message', (...args) => cb(...args));
            }
        }
    };

    module.exports = { pub, sub, client };
    return;
}

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

// Attach error handlers to all Redis clients to avoid unhandled exception crashes
client.on('error', (err) => console.error('[redis][client] Error', err));
pub.on('error', (err) => console.error('[redis][pub] Error', err));
sub.on('error', (err) => console.error('[redis][sub] Error', err));

client.on('connect', () => {
    console.log('[redis][client] connected to', process.env.REDIS_HOST || 'localhost');
});

pub.on('connect', () => {
    console.log('[redis][pub] connected to', process.env.REDIS_HOST || 'localhost');
});

sub.on('connect', () => {
    console.log('[redis][sub] connected to', process.env.REDIS_HOST || 'localhost');
});


module.exports = {pub, sub, client};
