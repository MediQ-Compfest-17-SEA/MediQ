import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import Redis from 'ioredis';

describe('Queue Management Integration Tests', () => {
  let app: INestApplication;
  let redis: Redis;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [], // Import actual modules for integration testing
    }).compile();

    app = moduleFixture.createNestApplication();
    redis = new Redis({
      host: process.env.REDIS_HOST || 'localhost',
      port: parseInt(process.env.REDIS_PORT) || 6379,
      db: 1, // Use separate database for testing
    });
    
    await app.init();
  });

  beforeEach(async () => {
    // Clear Redis before each test
    await redis.flushdb();
  });

  afterAll(async () => {
    await redis.disconnect();
    await app.close();
  });

  describe('Queue Service ↔ Redis Integration', () => {
    it('should manage complete queue lifecycle with Redis persistence', async () => {
      const userId = 'user123';

      // Add user to queue
      const addResponse = await request(app.getHttpServer())
        .post('/queue/add')
        .send({ user_id: userId })
        .expect(201);

      expect(addResponse.body).toHaveProperty('queue_number');
      expect(addResponse.body).toHaveProperty('position');
      expect(addResponse.body).toHaveProperty('estimated_wait_time');

      const queueNumber = addResponse.body.queue_number;

      // Verify queue entry in Redis
      const redisData = await redis.get(`queue:${queueNumber}`);
      expect(redisData).toBeDefined();
      const queueData = JSON.parse(redisData);
      expect(queueData.user_id).toBe(userId);
      expect(queueData.status).toBe('waiting');

      // Get queue status
      const statusResponse = await request(app.getHttpServer())
        .get(`/queue/status/${userId}`)
        .expect(200);

      expect(statusResponse.body).toHaveProperty('queue_number', queueNumber);
      expect(statusResponse.body).toHaveProperty('status', 'waiting');

      // Call next patient
      const callResponse = await request(app.getHttpServer())
        .patch('/queue/call-next')
        .expect(200);

      expect(callResponse.body).toHaveProperty('called_user_id', userId);
      expect(callResponse.body).toHaveProperty('queue_number', queueNumber);

      // Verify status update in Redis
      const updatedRedisData = await redis.get(`queue:${queueNumber}`);
      const updatedQueueData = JSON.parse(updatedRedisData);
      expect(updatedQueueData.status).toBe('called');

      // Complete service
      const completeResponse = await request(app.getHttpServer())
        .patch(`/queue/${queueNumber}/complete`)
        .expect(200);

      expect(completeResponse.body).toHaveProperty('status', 'completed');

      // Verify completion in Redis
      const completedRedisData = await redis.get(`queue:${queueNumber}`);
      const completedQueueData = JSON.parse(completedRedisData);
      expect(completedQueueData.status).toBe('completed');
    });

    it('should handle multiple users in queue with correct ordering', async () => {
      const users = ['user1', 'user2', 'user3', 'user4'];
      const queueNumbers = [];

      // Add multiple users to queue
      for (const userId of users) {
        const response = await request(app.getHttpServer())
          .post('/queue/add')
          .send({ user_id: userId })
          .expect(201);

        queueNumbers.push(response.body.queue_number);
        expect(response.body.position).toBe(users.indexOf(userId) + 1);
      }

      // Get current queue
      const queueResponse = await request(app.getHttpServer())
        .get('/queue/current')
        .expect(200);

      expect(queueResponse.body).toHaveProperty('total_waiting', 4);
      expect(queueResponse.body).toHaveProperty('queue');
      expect(queueResponse.body.queue).toHaveLength(4);

      // Verify order in Redis
      for (let i = 0; i < queueNumbers.length; i++) {
        const redisData = await redis.get(`queue:${queueNumbers[i]}`);
        const queueData = JSON.parse(redisData);
        expect(queueData.position).toBe(i + 1);
      }

      // Call patients in order
      for (let i = 0; i < users.length; i++) {
        const callResponse = await request(app.getHttpServer())
          .patch('/queue/call-next')
          .expect(200);

        expect(callResponse.body.called_user_id).toBe(users[i]);
        expect(callResponse.body.queue_number).toBe(queueNumbers[i]);
      }

      // No more patients to call
      const emptyCallResponse = await request(app.getHttpServer())
        .patch('/queue/call-next')
        .expect(404);

      expect(emptyCallResponse.body).toHaveProperty('error');
      expect(emptyCallResponse.body.error).toContain('No patients waiting');
    });

    it('should handle Redis connection failures gracefully', async () => {
      // Disconnect Redis to simulate failure
      await redis.disconnect();

      const userId = 'redis-failure-user';

      const response = await request(app.getHttpServer())
        .post('/queue/add')
        .send({ user_id: userId })
        .expect(503);

      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toContain('Queue service temporarily unavailable');

      // Reconnect Redis
      redis = new Redis({
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT) || 6379,
        db: 1,
      });
    });

    it('should support queue position updates and recalculation', async () => {
      const users = ['priority-user1', 'priority-user2', 'priority-user3'];
      const queueNumbers = [];

      // Add users to queue
      for (const userId of users) {
        const response = await request(app.getHttpServer())
          .post('/queue/add')
          .send({ user_id: userId })
          .expect(201);

        queueNumbers.push(response.body.queue_number);
      }

      // Set priority for second user
      const priorityResponse = await request(app.getHttpServer())
        .patch(`/queue/${queueNumbers[1]}/priority`)
        .send({ priority: 'high' })
        .expect(200);

      expect(priorityResponse.body).toHaveProperty('position', 1);

      // Verify position recalculation in Redis
      const priorityRedisData = await redis.get(`queue:${queueNumbers[1]}`);
      const priorityQueueData = JSON.parse(priorityRedisData);
      expect(priorityQueueData.position).toBe(1);
      expect(priorityQueueData.priority).toBe('high');

      // Check other users' positions were updated
      const user1RedisData = await redis.get(`queue:${queueNumbers[0]}`);
      const user1QueueData = JSON.parse(user1RedisData);
      expect(user1QueueData.position).toBe(2);

      const user3RedisData = await redis.get(`queue:${queueNumbers[2]}`);
      const user3QueueData = JSON.parse(user3RedisData);
      expect(user3QueueData.position).toBe(3);
    });
  });

  describe('Queue Statistics and Analytics', () => {
    it('should track and calculate queue statistics', async () => {
      const users = ['stat-user1', 'stat-user2', 'stat-user3'];
      const startTime = Date.now();

      // Add users to queue
      for (const userId of users) {
        await request(app.getHttpServer())
          .post('/queue/add')
          .send({ user_id: userId })
          .expect(201);
      }

      // Process some patients
      await request(app.getHttpServer())
        .patch('/queue/call-next')
        .expect(200);

      // Simulate service time
      await new Promise(resolve => setTimeout(resolve, 100));

      await request(app.getHttpServer())
        .patch('/queue/call-next')
        .expect(200);

      // Get statistics
      const statsResponse = await request(app.getHttpServer())
        .get('/queue/statistics')
        .expect(200);

      expect(statsResponse.body).toHaveProperty('total_served_today');
      expect(statsResponse.body).toHaveProperty('current_waiting');
      expect(statsResponse.body).toHaveProperty('average_wait_time');
      expect(statsResponse.body).toHaveProperty('average_service_time');

      // Verify Redis statistics storage
      const todayKey = `stats:${new Date().toISOString().split('T')[0]}`;
      const statsData = await redis.get(todayKey);
      expect(statsData).toBeDefined();

      const dailyStats = JSON.parse(statsData);
      expect(dailyStats).toHaveProperty('total_served');
      expect(dailyStats).toHaveProperty('total_wait_time');
    });

    it('should handle queue cancellation and no-shows', async () => {
      const userId = 'cancel-user';

      // Add user to queue
      const addResponse = await request(app.getHttpServer())
        .post('/queue/add')
        .send({ user_id: userId })
        .expect(201);

      const queueNumber = addResponse.body.queue_number;

      // Cancel queue entry
      const cancelResponse = await request(app.getHttpServer())
        .delete(`/queue/${queueNumber}`)
        .expect(200);

      expect(cancelResponse.body).toHaveProperty('status', 'cancelled');

      // Verify removal from Redis
      const redisData = await redis.get(`queue:${queueNumber}`);
      const queueData = JSON.parse(redisData);
      expect(queueData.status).toBe('cancelled');

      // Try to get status of cancelled queue
      const statusResponse = await request(app.getHttpServer())
        .get(`/queue/status/${userId}`)
        .expect(404);

      expect(statusResponse.body).toHaveProperty('error');
      expect(statusResponse.body.error).toContain('No active queue entry');
    });

    it('should support queue transfers between facilities', async () => {
      const userId = 'transfer-user';
      const sourceFacility = 'facility1';
      const targetFacility = 'facility2';

      // Add user to source facility queue
      const addResponse = await request(app.getHttpServer())
        .post('/queue/add')
        .send({ 
          user_id: userId,
          facility_id: sourceFacility,
        })
        .expect(201);

      const queueNumber = addResponse.body.queue_number;

      // Transfer to target facility
      const transferResponse = await request(app.getHttpServer())
        .patch(`/queue/${queueNumber}/transfer`)
        .send({ target_facility_id: targetFacility })
        .expect(200);

      expect(transferResponse.body).toHaveProperty('new_queue_number');
      expect(transferResponse.body).toHaveProperty('new_facility_id', targetFacility);

      // Verify transfer in Redis
      const oldRedisData = await redis.get(`queue:${queueNumber}`);
      const oldQueueData = JSON.parse(oldRedisData);
      expect(oldQueueData.status).toBe('transferred');

      const newQueueNumber = transferResponse.body.new_queue_number;
      const newRedisData = await redis.get(`queue:${newQueueNumber}`);
      const newQueueData = JSON.parse(newRedisData);
      expect(newQueueData.facility_id).toBe(targetFacility);
      expect(newQueueData.status).toBe('waiting');
    });
  });

  describe('Real-time Queue Updates', () => {
    it('should broadcast queue updates via WebSocket', async () => {
      // This would require WebSocket testing setup
      const userId = 'websocket-user';

      const addResponse = await request(app.getHttpServer())
        .post('/queue/add')
        .send({ user_id: userId })
        .expect(201);

      const queueNumber = addResponse.body.queue_number;

      // Verify Redis pub/sub for real-time updates
      const pubsubKey = 'queue:updates';
      let receivedUpdate = null;

      redis.subscribe(pubsubKey, (err) => {
        if (err) throw err;
      });

      redis.on('message', (channel, message) => {
        if (channel === pubsubKey) {
          receivedUpdate = JSON.parse(message);
        }
      });

      // Call next patient should trigger pub/sub update
      await request(app.getHttpServer())
        .patch('/queue/call-next')
        .expect(200);

      // Wait for pub/sub message
      await new Promise(resolve => setTimeout(resolve, 100));

      expect(receivedUpdate).toBeDefined();
      expect(receivedUpdate).toHaveProperty('type', 'patient_called');
      expect(receivedUpdate).toHaveProperty('queue_number', queueNumber);
    });
  });
});
