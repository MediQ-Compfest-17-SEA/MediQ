import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';
import * as amqp from 'amqplib';

// Global test setup for integration tests
const prisma = new PrismaClient({
  datasources: {
    db: {
      url: process.env.TEST_DATABASE_URL || 'mysql://root:password@localhost:3306/mediq_integration_test',
    },
  },
});

const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT) || 6379,
  db: 1, // Use separate database for testing
});

let rabbitmqConnection: amqp.Connection;
let rabbitmqChannel: amqp.Channel;

beforeAll(async () => {
  console.log('🚀 Setting up integration test environment...');

  try {
    // Set test environment variables
    process.env.NODE_ENV = 'test';
    process.env.JWT_SECRET = 'test-jwt-secret';
    process.env.JWT_REFRESH_SECRET = 'test-refresh-secret';

    // Wait for services to be ready
    await waitForServices();

    // Initialize database schema
    await prisma.$executeRaw`CREATE DATABASE IF NOT EXISTS mediq_integration_test`;
    await setupTestDatabase();

    // Setup RabbitMQ test queues
    await setupRabbitMQ();

    // Clear Redis test database
    await redis.flushdb();

    console.log('✅ Integration test environment ready');
  } catch (error) {
    console.error('❌ Failed to setup integration test environment:', error);
    throw error;
  }
}, 60000);

afterAll(async () => {
  console.log('🧹 Cleaning up integration test environment...');

  try {
    // Cleanup database
    await prisma.$executeRaw`DROP DATABASE IF EXISTS mediq_integration_test`;
    await prisma.$disconnect();

    // Cleanup Redis
    await redis.flushdb();
    await redis.disconnect();

    // Cleanup RabbitMQ
    if (rabbitmqChannel) {
      await rabbitmqChannel.close();
    }
    if (rabbitmqConnection) {
      await rabbitmqConnection.close();
    }

    console.log('✅ Integration test cleanup completed');
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
  }
}, 30000);

async function waitForServices() {
  console.log('⏳ Waiting for services to be ready...');

  const maxRetries = 30;
  const retryDelay = 2000;

  // Wait for MySQL
  for (let i = 0; i < maxRetries; i++) {
    try {
      await prisma.$queryRaw`SELECT 1`;
      console.log('✅ MySQL ready');
      break;
    } catch (error) {
      if (i === maxRetries - 1) throw new Error('MySQL not ready after 60 seconds');
      await new Promise(resolve => setTimeout(resolve, retryDelay));
    }
  }

  // Wait for Redis
  for (let i = 0; i < maxRetries; i++) {
    try {
      await redis.ping();
      console.log('✅ Redis ready');
      break;
    } catch (error) {
      if (i === maxRetries - 1) throw new Error('Redis not ready after 60 seconds');
      await new Promise(resolve => setTimeout(resolve, retryDelay));
    }
  }

  // Wait for RabbitMQ
  for (let i = 0; i < maxRetries; i++) {
    try {
      rabbitmqConnection = await amqp.connect(process.env.RABBITMQ_URL || 'amqp://localhost:5672');
      rabbitmqChannel = await rabbitmqConnection.createChannel();
      console.log('✅ RabbitMQ ready');
      break;
    } catch (error) {
      if (i === maxRetries - 1) throw new Error('RabbitMQ not ready after 60 seconds');
      await new Promise(resolve => setTimeout(resolve, retryDelay));
    }
  }
}

async function setupTestDatabase() {
  console.log('📊 Setting up test database schema...');

  try {
    // Create users table
    await prisma.$executeRaw`
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(191) NOT NULL,
        nik VARCHAR(16) NOT NULL UNIQUE,
        nama VARCHAR(191) NOT NULL,
        email VARCHAR(191) UNIQUE,
        password VARCHAR(191),
        tempat_lahir VARCHAR(191),
        tanggal_lahir DATE,
        alamat TEXT,
        rt VARCHAR(3),
        rw VARCHAR(3),
        kelurahan VARCHAR(191),
        kecamatan VARCHAR(191),
        agama VARCHAR(191),
        status_perkawinan VARCHAR(191),
        pekerjaan VARCHAR(191),
        kewarganegaraan VARCHAR(191),
        masa_berlaku DATE,
        role ENUM('PASIEN', 'OPERATOR', 'ADMIN_FASKES') NOT NULL DEFAULT 'PASIEN',
        created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
        updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
        PRIMARY KEY (id)
      )
    `;

    // Create queue table
    await prisma.$executeRaw`
      CREATE TABLE IF NOT EXISTS queue_entries (
        id VARCHAR(191) NOT NULL,
        user_id VARCHAR(191) NOT NULL,
        queue_number VARCHAR(191) NOT NULL UNIQUE,
        position INT NOT NULL,
        status ENUM('waiting', 'called', 'completed', 'cancelled', 'transferred') NOT NULL DEFAULT 'waiting',
        priority INT NOT NULL DEFAULT 1,
        facility_id VARCHAR(191),
        estimated_wait_time INT,
        called_at DATETIME(3),
        completed_at DATETIME(3),
        created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
        updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
        PRIMARY KEY (id),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    `;

    // Create OCR processing table
    await prisma.$executeRaw`
      CREATE TABLE IF NOT EXISTS ocr_processing (
        id VARCHAR(191) NOT NULL,
        processing_id VARCHAR(191) NOT NULL UNIQUE,
        user_id VARCHAR(191),
        status ENUM('processing', 'completed', 'failed') NOT NULL DEFAULT 'processing',
        extracted_data JSON,
        confidence_score DECIMAL(3,2),
        error_message TEXT,
        created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
        updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
        PRIMARY KEY (id),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
      )
    `;

    console.log('✅ Test database schema created');
  } catch (error) {
    console.error('❌ Error setting up test database:', error);
    throw error;
  }
}

async function setupRabbitMQ() {
  console.log('🐰 Setting up RabbitMQ test queues...');

  try {
    // Declare test queues
    const queues = [
      'user_service_queue',
      'ocr_service_queue', 
      'patient_queue_service_queue',
      'test_queue',
      'failure_test_queue',
      'dead_letter_queue',
    ];

    for (const queueName of queues) {
      await rabbitmqChannel.assertQueue(queueName, { durable: true });
    }

    // Setup dead letter exchange
    await rabbitmqChannel.assertExchange('dlx', 'direct', { durable: true });
    await rabbitmqChannel.bindQueue('dead_letter_queue', 'dlx', 'failed');

    // Setup event exchange for pub/sub testing
    await rabbitmqChannel.assertExchange('user_events', 'fanout', { durable: true });

    console.log('✅ RabbitMQ test queues ready');
  } catch (error) {
    console.error('❌ Error setting up RabbitMQ:', error);
    throw error;
  }
}

// Utility functions for tests
export const testUtils = {
  prisma,
  redis,
  
  async createTestUser(userData: any) {
    const user = await prisma.user.create({
      data: {
        id: `user_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        ...userData,
      },
    });
    return user;
  },

  async cleanupTestData() {
    await prisma.user.deleteMany();
    await prisma.$executeRaw`DELETE FROM queue_entries`;
    await prisma.$executeRaw`DELETE FROM ocr_processing`;
    await redis.flushdb();
  },

  async waitForQueueMessage(queueName: string, timeout = 5000) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`No message received on queue ${queueName} within ${timeout}ms`));
      }, timeout);

      rabbitmqChannel.consume(queueName, (msg) => {
        if (msg) {
          clearTimeout(timer);
          const data = JSON.parse(msg.content.toString());
          rabbitmqChannel.ack(msg);
          resolve(data);
        }
      });
    });
  },

  async sendTestMessage(queueName: string, data: any) {
    await rabbitmqChannel.sendToQueue(queueName, Buffer.from(JSON.stringify(data)));
  },

  generateTestNik() {
    const now = Date.now().toString();
    return now.padStart(16, '0').slice(0, 16);
  },

  generateTestEmail() {
    const timestamp = Date.now();
    return `test_${timestamp}@integration-test.com`;
  },
};

// Make testUtils available globally
(global as any).testUtils = testUtils;
