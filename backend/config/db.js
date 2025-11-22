const mongoose = require('mongoose');

const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('MongoDB connected successfully');

        try {
            const db = mongoose.connection.db;
            const usersColl = db.collection('users');

            const existingIndexes = await usersColl.indexes();

            async function ensurePartialIndex(keyName) {
                const idx = existingIndexes.find(i => i.key && i.key[keyName] === 1);
                const partialSpec = { [keyName]: 1 };
              
                const options = { unique: true, partialFilterExpression: { [keyName]: { $type: 'string' } } };

                if (idx) {
                    const hasPartial = idx.partialFilterExpression && Object.prototype.hasOwnProperty.call(idx.partialFilterExpression, keyName);
                    if (!hasPartial) {
                        try {
                            await usersColl.dropIndex(idx.name);
                            console.log(`[MongoDB] Dropped index ${idx.name} on users.${keyName}`);
                        } catch (e) {
                            console.warn('[MongoDB] Could not drop index', idx.name, e && e.message ? e.message : e);
                        }
                        try {
                            await usersColl.createIndex(partialSpec, options);
                            console.log(`[MongoDB] Created partial unique index on users.${keyName}`);
                        } catch (e) {
                            console.error('[MongoDB] Failed to create partial index for', keyName, e && e.message ? e.message : e);
                        }
                    } else {
                        console.log(`[MongoDB] Partial index for users.${keyName} already exists (${idx.name})`);
                    }
                } else {
                    try {
                        await usersColl.createIndex(partialSpec, options);
                        console.log(`[MongoDB] Created partial unique index on users.${keyName}`);
                    } catch (e) {
                        console.error('[MongoDB] Failed to create partial index for', keyName, e && e.message ? e.message : e);
                    }
                }
            }

            await ensurePartialIndex('email');
            await ensurePartialIndex('phone');
        } catch (e) {
            console.warn('[MongoDB] Could not ensure partial indexes for users collection:', e && e.message ? e.message : e);
        }

    } catch (error) {
        console.error('MongoDB connection failed:', error.message);
        process.exit(1);
    }
}

module.exports = connectDB;