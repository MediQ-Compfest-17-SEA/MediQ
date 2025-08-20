import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { ClientProxy } from '@nestjs/microservices';

describe('Auth Flow Integration Tests', () => {
  let app: INestApplication;
  let userServiceClient: ClientProxy;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [], // Import actual modules for integration testing
    }).compile();

    app = moduleFixture.createNestApplication();
    userServiceClient = app.get('USER_SERVICE');
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('Full Authentication Workflow', () => {
    it('should complete admin login flow via API Gateway', async () => {
      const loginData = {
        email: 'admin@mediq.com',
        password: 'admin123',
      };

      const response = await request(app.getHttpServer())
        .post('/auth/login/admin')
        .send(loginData)
        .expect(201);

      expect(response.body).toHaveProperty('access_token');
      expect(response.body).toHaveProperty('refresh_token');
      expect(response.body.user).toHaveProperty('role', 'ADMIN_FASKES');
    });

    it('should complete user login flow via API Gateway', async () => {
      const loginData = {
        email: 'user@mediq.com', 
        password: 'user123',
      };

      const response = await request(app.getHttpServer())
        .post('/auth/login/user')
        .send(loginData)
        .expect(201);

      expect(response.body).toHaveProperty('access_token');
      expect(response.body).toHaveProperty('refresh_token');
      expect(response.body.user.role).toMatch(/PASIEN|OPERATOR/);
    });

    it('should refresh token successfully', async () => {
      // First login
      const loginResponse = await request(app.getHttpServer())
        .post('/auth/login/admin')
        .send({
          email: 'admin@mediq.com',
          password: 'admin123',
        });

      const { refresh_token } = loginResponse.body;

      // Use refresh token
      const refreshResponse = await request(app.getHttpServer())
        .get('/auth/refresh')
        .set('Authorization', `Bearer ${refresh_token}`)
        .expect(200);

      expect(refreshResponse.body).toHaveProperty('access_token');
      expect(refreshResponse.body).toHaveProperty('refresh_token');
    });

    it('should logout successfully and invalidate tokens', async () => {
      const loginResponse = await request(app.getHttpServer())
        .post('/auth/login/admin')
        .send({
          email: 'admin@mediq.com',
          password: 'admin123',
        });

      const { access_token } = loginResponse.body;

      // Logout
      await request(app.getHttpServer())
        .get('/auth/logout')
        .set('Authorization', `Bearer ${access_token}`)
        .expect(200);

      // Try to access protected route with old token
      await request(app.getHttpServer())
        .get('/users/profile')
        .set('Authorization', `Bearer ${access_token}`)
        .expect(401);
    });

    it('should handle authentication failures gracefully', async () => {
      const invalidLoginData = {
        email: 'invalid@mediq.com',
        password: 'wrongpassword',
      };

      await request(app.getHttpServer())
        .post('/auth/login/admin')
        .send(invalidLoginData)
        .expect(401);
    });

    it('should enforce role-based access control', async () => {
      // Login as regular user
      const userLoginResponse = await request(app.getHttpServer())
        .post('/auth/login/user')
        .send({
          email: 'user@mediq.com',
          password: 'user123',
        });

      const { access_token } = userLoginResponse.body;

      // Try to access admin-only route
      await request(app.getHttpServer())
        .patch('/users/1/role')
        .set('Authorization', `Bearer ${access_token}`)
        .send({ role: 'ADMIN_FASKES' })
        .expect(403);
    });
  });

  describe('RabbitMQ Communication Reliability', () => {
    it('should handle message queue failures gracefully', async () => {
      // Mock RabbitMQ failure scenario
      jest.spyOn(userServiceClient, 'send').mockRejectedValueOnce(new Error('RabbitMQ connection failed'));

      const loginData = {
        email: 'admin@mediq.com',
        password: 'admin123',
      };

      const response = await request(app.getHttpServer())
        .post('/auth/login/admin')
        .send(loginData);

      // Should get service unavailable or retry logic
      expect([503, 201]).toContain(response.status);
    });

    it('should implement retry logic for failed messages', async () => {
      let callCount = 0;
      jest.spyOn(userServiceClient, 'send').mockImplementation(() => {
        callCount++;
        if (callCount < 3) {
          throw new Error('Temporary failure');
        }
        return Promise.resolve({ access_token: 'token', user: { id: 1 } });
      });

      const loginData = {
        email: 'admin@mediq.com',
        password: 'admin123',
      };

      const response = await request(app.getHttpServer())
        .post('/auth/login/admin')
        .send(loginData);

      expect(response.status).toBe(201);
      expect(callCount).toBeGreaterThanOrEqual(3);
    });

    it('should timeout after configured duration', async () => {
      jest.spyOn(userServiceClient, 'send').mockImplementation(() => 
        new Promise(resolve => setTimeout(resolve, 10000)) // 10 second delay
      );

      const loginData = {
        email: 'admin@mediq.com',
        password: 'admin123',
      };

      const start = Date.now();
      const response = await request(app.getHttpServer())
        .post('/auth/login/admin')
        .send(loginData);

      const duration = Date.now() - start;
      expect(duration).toBeLessThan(6000); // Should timeout at 5 seconds
      expect([408, 503]).toContain(response.status);
    });
  });
});
