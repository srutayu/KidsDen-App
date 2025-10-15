// Ensure environment variables are loaded if this module is required directly
try {
  const path = require('path');
  const dotenvPath = path.resolve(__dirname, '..', '.env');
  // Prefer loading the chatbackend/.env when present so local dev env is picked up
  require('dotenv').config({ path: dotenvPath });
} catch (e) {
  // ignore if dotenv isn't available in some environments
}

const { S3Client, PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
const { v4: uuidv4 } = require('uuid');
const mime = require('mime-types');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const REGION = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION;
const BUCKET = process.env.S3_BUCKET;

function ensureS3Config() {
  const missing = [];
  if (!BUCKET) missing.push('S3_BUCKET');
  if (!REGION) missing.push('AWS_REGION or AWS_DEFAULT_REGION');
  if (missing.length) {
    throw new Error(`S3 configuration error: missing ${missing.join(', ')} environment variable(s)`);
  }
}

if (!BUCKET || !REGION) {
  // Log a clear warning on startup but defer throwing until an S3 operation is requested.
  console.warn('S3 configuration incomplete. Ensure S3_BUCKET and AWS_REGION/AWS_DEFAULT_REGION are set in environment. Presign and upload calls will fail until configured.');
}

const s3Client = new S3Client({ region: REGION });

async function uploadBufferToS3(buffer, originalName, contentType) {
  const key = `${uuidv4()}_${originalName}`;

  const params = {
    Bucket: BUCKET,
    Key: key,
    Body: buffer,
    ContentType: contentType || mime.lookup(originalName) || 'application/octet-stream'
  };

  const cmd = new PutObjectCommand(params);
  await s3Client.send(cmd);

  // If caller wants presigned URLs (objects can remain private), generate one
  if (process.env.S3_PRESIGN === 'true') {
    // ensure configuration is present before generating presigned URLs
    ensureS3Config();
    const getCmd = new GetObjectCommand({ Bucket: BUCKET, Key: key });
    const expires = parseInt(process.env.S3_PRESIGN_EXPIRES || '3600');
    const presignedUrl = await getSignedUrl(s3Client, getCmd, { expiresIn: expires });
    return { url: presignedUrl, key };
  }

  // Default: assume bucket objects are publicly accessible via standard URL
  const url = `https://${BUCKET}.s3.${REGION}.amazonaws.com/${encodeURIComponent(key)}`;
  return { url, key };
}

function generateKey(originalName) {
  return `${uuidv4()}_${originalName}`;
}

async function getPresignedPutAndGetUrls(key, contentType, putExpires = 900, getExpires = 3600) {
  ensureS3Config();
  const putCmd = new PutObjectCommand({ Bucket: BUCKET, Key: key, ContentType: contentType });
  const uploadUrl = await getSignedUrl(s3Client, putCmd, { expiresIn: putExpires });

  const getCmd = new GetObjectCommand({ Bucket: BUCKET, Key: key });
  const getUrl = await getSignedUrl(s3Client, getCmd, { expiresIn: getExpires });

  return { uploadUrl, getUrl };
}

async function getPresignedGetUrl(key, expires = 3600) {
  ensureS3Config();
  const getCmd = new GetObjectCommand({ Bucket: BUCKET, Key: key });
  return await getSignedUrl(s3Client, getCmd, { expiresIn: expires });
}

module.exports = { uploadBufferToS3, generateKey, getPresignedPutAndGetUrls, getPresignedGetUrl };
