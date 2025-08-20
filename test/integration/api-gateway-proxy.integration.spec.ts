import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { ClientProxy } from '@nestjs/microservices';

describe('API Gateway Proxy Integration Tests', () => {
  let app: INestApplication;
  let userServiceClient: ClientProxy;
  let ocrServiceClient: ClientProxy;
  let queueServiceClient: ClientProxy;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [], // Import actual modules for integration testing
    }).compile();

    app = moduleFixture.createNestApplication();
    userServiceClient = app.get('USER_SERVICE');
    ocrServiceClient = app.get('OCR_SERVICE');
    queueServiceClient = app.get('QUEUE_SERVICE');
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('Gateway Proxy Functionality', () => {
    it('should proxy user service requests correctly', async () => {
      const userData = {
        nik: '1234567890123456',
        nama: 'Gateway Test User',
        email: 'gateway@test.com',
        password: 'password123',
        tempat_lahir: 'Gateway City',
        tanggal_lahir: '1990-01-01',
        alamat: 'Gateway Address 123',
        rt: '001',
        rw: '002',
        kelurahan: 'Gateway Village',
        kecamatan: 'Gateway District',
        agama: 'Islam',
        status_perkawinan: 'Belum Kawin',
        pekerjaan: 'Gateway Tester',
        kewarganegaraan: 'WNI',
        masa_berlaku: '2025-01-01',
        role: 'PASIEN',
      };

      // Test user creation via gateway
      const createResponse = await request(app.getHttpServer())
        .post('/users')
        .send(userData)
        .expect(201);

      expect(createResponse.body).toHaveProperty('id');
      expect(createResponse.body).toHaveProperty('nik', userData.nik);

      const userId = createResponse.body.id;

      // Test user retrieval via gateway
      const getResponse = await request(app.getHttpServer())
        .get(`/users/${userId}`)
        .expect(200);

      expect(getResponse.body).toHaveProperty('id', userId);
      expect(getResponse.body).toHaveProperty('nama', userData.nama);
    });

    it('should proxy OCR service requests correctly', async () => {
      const mockProcessingId = 'proc123';

      // Mock OCR processing request
      jest.spyOn(ocrServiceClient, 'send').mockResolvedValue({
        processing_id: mockProcessingId,
        status: 'processing',
      });

      const response = await request(app.getHttpServer())
        .post('/ocr/process-ktp')
        .attach('ktp_image', Buffer.from('fake-image-data'), 'test.jpg')
        .expect(201);

      expect(response.body).toHaveProperty('processing_id', mockProcessingId);
      expect(response.body).toHaveProperty('status', 'processing');
    });

    it('should proxy queue service requests correctly', async () => {
      const userId = 'queue-test-user';
      const mockQueueNumber = 'Q001';

      // Mock queue service response
      jest.spyOn(queueServiceClient, 'send').mockResolvedValue({
        queue_number: mockQueueNumber,
        position: 1,
        estimated_wait_time: 300,
      });

      const response = await request(app.getHttpServer())
        .post('/queue/add')
        .send({ user_id: userId })
        .expect(201);

      expect(response.body).toHaveProperty('queue_number', mockQueueNumber);
      expect(response.body).toHaveProperty('position', 1);
    });
  });

  describe('Gateway Error Handling', () => {
    it('should handle service unavailability with circuit breaker', async () => {
      // Simulate repeated service failures
      const mockError = new Error('Service unavailable');
      jest.spyOn(userServiceClient, 'send').mockRejectedValue(mockError);

      // Make multiple requests to trigger circuit breaker
      for (let i = 0; i < 5; i++) {
        await request(app.getHttpServer())
          .get('/users')
          .expect(503);
      }

      // Circuit should be open now, requests should fail fast
      const start = Date.now();
      await request(app.getHttpServer())
        .get('/users')
        .expect(503);
      const duration = Date.now() - start;

      expect(duration).toBeLessThan(100); // Should fail fast when circuit is open
    });

    it('should implement retry logic with exponential backoff', async () => {
      let attemptCount = 0;
      jest.spyOn(userServiceClient, 'send').mockImplementation(() => {
        attemptCount++;
        if (attemptCount < 3) {
          throw new Error('Temporary failure');
        }
        return Promise.resolve([]);
      });

      const response = await request(app.getHttpServer())
        .get('/users')
        .expect(200);

      expect(attemptCount).toBe(3);
      expect(response.body).toEqual([]);
    });

    it('should handle timeout scenarios', async () => {
      // Mock service that takes too long to respond
      jest.spyOn(userServiceClient, 'send').mockImplementation(() => 
        new Promise(resolve => setTimeout(resolve, 10000)) // 10 second delay
      );

      const start = Date.now();
      const response = await request(app.getHttpServer())
        .get('/users');

      const duration = Date.now() - start;
      expect(duration).toBeLessThan(6000); // Should timeout at 5 seconds
      expect([408, 503]).toContain(response.status);
    });

    it('should provide meaningful error responses', async () => {
      const mockError = new Error('Database connection failed');
      jest.spyOn(userServiceClient, 'send').mockRejectedValue(mockError);

      const response = await request(app.getHttpServer())
        .get('/users')
        .expect(503);

      expect(response.body).toHaveProperty('error');
      expect(response.body).toHaveProperty('message');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('path', '/users');
    });
  });

  describe('Gateway Security', () => {
    it('should validate JWT tokens for protected routes', async () => {
      // Try to access protected route without token
      await request(app.getHttpServer())
        .get('/users/profile')
        .expect(401);

      // Try with invalid token
      await request(app.getHttpServer())
        .get('/users/profile')
        .set('Authorization', 'Bearer invalid-token')
        .expect(401);

      // Try with valid token
      const loginResponse = await request(app.getHttpServer())
        .post('/auth/login/admin')
        .send({
          email: 'admin@mediq.com',
          password: 'admin123',
        })
        .expect(201);

      const { access_token } = loginResponse.body;

      await request(app.getHttpServer())
        .get('/users/profile')
        .set('Authorization', `Bearer ${access_token}`)
        .expect(200);
    });

    it('should enforce rate limiting', async () => {
      const requests = [];
      
      // Make rapid requests to trigger rate limiting
      for (let i = 0; i < 20; i++) {
        requests.push(
          request(app.getHttpServer())
            .get('/users')
        );
      }

      const responses = await Promise.all(requests);
      const rateLimitedResponses = responses.filter(res => res.status === 429);
      
      expect(rateLimitedResponses.length).toBeGreaterThan(0);
    });

    it('should validate request payloads', async () => {
      const invalidUserData = {
        nik: '123', // Too short
        nama: '', // Empty
        email: 'invalid-email', // Invalid format
      };

      const response = await request(app.getHttpServer())
        .post('/users')
        .send(invalidUserData)
        .expect(400);

      expect(response.body).toHaveProperty('error');
      expect(response.body).toHaveProperty('details');
      expect(Array.isArray(response.body.details)).toBe(true);
    });

    it('should sanitize error messages to prevent information leakage', async () => {
      // Simulate internal service error with sensitive information
      const sensitiveError = new Error('Database connection failed: password=secret123 host=internal-db.local');
      jest.spyOn(userServiceClient, 'send').mockRejectedValue(sensitiveError);

      const response = await request(app.getHttpServer())
        .get('/users')
        .expect(503);

      // Error message should be sanitized
      expect(response.body.message).not.toContain('password=secret123');
      expect(response.body.message).not.toContain('internal-db.local');
      expect(response.body.message).toContain('Service temporarily unavailable');
    });
  });

  describe('Gateway Performance', () => {
    it('should handle concurrent requests efficiently', async () => {
      const concurrentRequests = 50;
      const requests = [];

      // Mock successful responses
      jest.spyOn(userServiceClient, 'send').mockResolvedValue([]);

      const start = Date.now();

      for (let i = 0; i < concurrentRequests; i++) {
        requests.push(
          request(app.getHttpServer())
            .get('/users')
        );
      }

      const responses = await Promise.all(requests);
      const duration = Date.now() - start;

      // All requests should succeed
      responses.forEach(response => {
        expect(response.status).toBe(200);
      });

      // Should handle concurrent requests reasonably fast
      expect(duration).toBeLessThan(5000);
    });

    it('should implement request deduplication for identical requests', async () => {
      let callCount = 0;
      jest.spyOn(userServiceClient, 'send').mockImplementation(() => {
        callCount++;
        return Promise.resolve([{ id: 1, name: 'Test User' }]);
      });

      const identicalRequests = [
        request(app.getHttpServer()).get('/users/1'),
        request(app.getHttpServer()).get('/users/1'),
        request(app.getHttpServer()).get('/users/1'),
      ];

      const responses = await Promise.all(identicalRequests);

      // All requests should succeed
      responses.forEach(response => {
        expect(response.status).toBe(200);
        expect(response.body).toEqual({ id: 1, name: 'Test User' });
      });

      // Service should only be called once due to deduplication
      expect(callCount).toBe(1);
    });

    it('should cache responses appropriately', async () => {
      let callCount = 0;
      jest.spyOn(userServiceClient, 'send').mockImplementation(() => {
        callCount++;
        return Promise.resolve([{ id: 1, name: 'Cached User' }]);
      });

      // First request
      const response1 = await request(app.getHttpServer())
        .get('/users/1')
        .expect(200);

      // Second request should use cache
      const response2 = await request(app.getHttpServer())
        .get('/users/1')
        .expect(200);

      expect(response1.body).toEqual(response2.body);
      expect(callCount).toBe(1); // Service called only once
    });
  });

  describe('Gateway Monitoring', () => {
    it('should track request metrics', async () => {
      jest.spyOn(userServiceClient, 'send').mockResolvedValue([]);

      await request(app.getHttpServer())
        .get('/users')
        .expect(200);

      // Check metrics endpoint
      const metricsResponse = await request(app.getHttpServer())
        .get('/metrics')
        .expect(200);

      expect(metricsResponse.text).toContain('http_requests_total');
      expect(metricsResponse.text).toContain('http_request_duration_seconds');
    });

    it('should provide health check endpoint', async () => {
      const healthResponse = await request(app.getHttpServer())
        .get('/health')
        .expect(200);

      expect(healthResponse.body).toHaveProperty('status', 'ok');
      expect(healthResponse.body).toHaveProperty('timestamp');
      expect(healthResponse.body).toHaveProperty('services');
      expect(healthResponse.body.services).toHaveProperty('user_service');
      expect(healthResponse.body.services).toHaveProperty('ocr_service');
      expect(healthResponse.body.services).toHaveProperty('queue_service');
    });
  });
});
