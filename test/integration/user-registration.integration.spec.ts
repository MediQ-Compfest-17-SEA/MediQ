import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { PrismaClient } from '@prisma/client';

describe('User Registration Integration Tests', () => {
  let app: INestApplication;
  let prisma: PrismaClient;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [], // Import actual modules for integration testing
    }).compile();

    app = moduleFixture.createNestApplication();
    prisma = new PrismaClient({
      datasources: {
        db: {
          url: process.env.TEST_DATABASE_URL || 'mysql://root:password@localhost:3306/mediq_test',
        },
      },
    });
    
    await app.init();
  });

  beforeEach(async () => {
    // Clean up database before each test
    await prisma.user.deleteMany();
  });

  afterAll(async () => {
    await prisma.$disconnect();
    await app.close();
  });

  describe('User Service ↔ Database Integration', () => {
    it('should create user with complete CRUD operations', async () => {
      const userData = {
        nik: '1111222233334444',
        nama: 'Integration Test User',
        email: 'integration@test.com',
        password: 'password123',
        tempat_lahir: 'Test City',
        tanggal_lahir: '1990-01-01',
        alamat: 'Test Address 123',
        rt: '001',
        rw: '002',
        kelurahan: 'Test Village',
        kecamatan: 'Test District',
        agama: 'Islam',
        status_perkawinan: 'Belum Kawin',
        pekerjaan: 'Tester',
        kewarganegaraan: 'WNI',
        masa_berlaku: '2025-01-01',
        role: 'PASIEN',
      };

      // CREATE - User creation
      const createResponse = await request(app.getHttpServer())
        .post('/users')
        .send(userData)
        .expect(201);

      expect(createResponse.body).toHaveProperty('id');
      expect(createResponse.body).toHaveProperty('nik', userData.nik);
      expect(createResponse.body).toHaveProperty('nama', userData.nama);
      expect(createResponse.body).not.toHaveProperty('password'); // Password should be excluded

      const userId = createResponse.body.id;

      // READ - Get user by ID
      const getResponse = await request(app.getHttpServer())
        .get(`/users/${userId}`)
        .expect(200);

      expect(getResponse.body).toHaveProperty('id', userId);
      expect(getResponse.body).toHaveProperty('nik', userData.nik);

      // READ - Get all users
      const getAllResponse = await request(app.getHttpServer())
        .get('/users')
        .expect(200);

      expect(getAllResponse.body).toHaveLength(1);
      expect(getAllResponse.body[0]).toHaveProperty('id', userId);

      // READ - Check NIK availability
      const checkNikResponse = await request(app.getHttpServer())
        .get(`/users/check-nik/${userData.nik}`)
        .expect(200);

      expect(checkNikResponse.body).toHaveProperty('exists', true);

      // UPDATE - Update user role
      const updateRoleResponse = await request(app.getHttpServer())
        .patch(`/users/${userId}/role`)
        .send({ role: 'OPERATOR' })
        .expect(200);

      expect(updateRoleResponse.body).toHaveProperty('role', 'OPERATOR');

      // DELETE - Remove user
      await request(app.getHttpServer())
        .delete(`/users/${userId}`)
        .expect(200);

      // Verify deletion
      await request(app.getHttpServer())
        .get(`/users/${userId}`)
        .expect(404);
    });

    it('should enforce database constraints and validations', async () => {
      const validUserData = {
        nik: '2222333344445555',
        nama: 'Valid User',
        email: 'valid@test.com',
        password: 'password123',
        tempat_lahir: 'Valid City',
        tanggal_lahir: '1985-05-15',
        alamat: 'Valid Address 456',
        rt: '003',
        rw: '004',
        kelurahan: 'Valid Village',
        kecamatan: 'Valid District',
        agama: 'Kristen',
        status_perkawinan: 'Kawin',
        pekerjaan: 'Valid Job',
        kewarganegaraan: 'WNI',
        masa_berlaku: '2025-05-15',
        role: 'PASIEN',
      };

      // Create valid user first
      await request(app.getHttpServer())
        .post('/users')
        .send(validUserData)
        .expect(201);

      // Try to create user with duplicate NIK
      const duplicateNikData = { ...validUserData, email: 'different@test.com' };
      await request(app.getHttpServer())
        .post('/users')
        .send(duplicateNikData)
        .expect(409);

      // Try to create user with duplicate email
      const duplicateEmailData = { ...validUserData, nik: '9999888877776666' };
      await request(app.getHttpServer())
        .post('/users')
        .send(duplicateEmailData)
        .expect(409);

      // Try to create user with invalid NIK length
      const invalidNikData = { ...validUserData, nik: '123', email: 'invalid@test.com' };
      await request(app.getHttpServer())
        .post('/users')
        .send(invalidNikData)
        .expect(400);

      // Try to create user with invalid email format
      const invalidEmailData = { ...validUserData, nik: '3333444455556666', email: 'invalid-email' };
      await request(app.getHttpServer())
        .post('/users')
        .send(invalidEmailData)
        .expect(400);

      // Try to create user with invalid role
      const invalidRoleData = { ...validUserData, nik: '4444555566667777', email: 'role@test.com', role: 'INVALID_ROLE' };
      await request(app.getHttpServer())
        .post('/users')
        .send(invalidRoleData)
        .expect(400);
    });

    it('should handle database connection failures gracefully', async () => {
      // Simulate database connection failure
      await prisma.$disconnect();

      const userData = {
        nik: '5555666677778888',
        nama: 'DB Failure Test User',
        email: 'dbfailure@test.com',
        password: 'password123',
        tempat_lahir: 'DB Test City',
        tanggal_lahir: '1990-01-01',
        alamat: 'DB Test Address 123',
        rt: '001',
        rw: '002',
        kelurahan: 'DB Test Village',
        kecamatan: 'DB Test District',
        agama: 'Islam',
        status_perkawinan: 'Belum Kawin',
        pekerjaan: 'DB Tester',
        kewarganegaraan: 'WNI',
        masa_berlaku: '2025-01-01',
        role: 'PASIEN',
      };

      const response = await request(app.getHttpServer())
        .post('/users')
        .send(userData)
        .expect(503);

      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toContain('Database connection failed');

      // Reconnect for cleanup
      await prisma.$connect();
    });

    it('should support database transactions and rollback on failure', async () => {
      const userData = {
        nik: '6666777788889999',
        nama: 'Transaction Test User',
        email: 'transaction@test.com',
        password: 'password123',
        tempat_lahir: 'Transaction City',
        tanggal_lahir: '1990-01-01',
        alamat: 'Transaction Address 123',
        rt: '001',
        rw: '002',
        kelurahan: 'Transaction Village',
        kecamatan: 'Transaction District',
        agama: 'Islam',
        status_perkawinan: 'Belum Kawin',
        pekerjaan: 'Transaction Tester',
        kewarganegaraan: 'WNI',
        masa_berlaku: '2025-01-01',
        role: 'PASIEN',
      };

      // Mock a scenario where user creation succeeds but related operation fails
      // This should trigger a rollback
      const response = await request(app.getHttpServer())
        .post('/users/create-with-related-data')
        .send({
          user_data: userData,
          trigger_failure: true, // This should cause rollback
        })
        .expect(500);

      expect(response.body).toHaveProperty('error');

      // Verify user was not created due to rollback
      const checkResponse = await request(app.getHttpServer())
        .get(`/users/check-nik/${userData.nik}`)
        .expect(200);

      expect(checkResponse.body).toHaveProperty('exists', false);
    });
  });

  describe('User Profile and Authentication Integration', () => {
    it('should support full authentication lifecycle with database persistence', async () => {
      const userData = {
        nik: '7777888899990000',
        nama: 'Auth Test User',
        email: 'authtest@test.com',
        password: 'password123',
        tempat_lahir: 'Auth City',
        tanggal_lahir: '1990-01-01',
        alamat: 'Auth Address 123',
        rt: '001',
        rw: '002',
        kelurahan: 'Auth Village',
        kecamatan: 'Auth District',
        agama: 'Islam',
        status_perkawinan: 'Belum Kawin',
        pekerjaan: 'Auth Tester',
        kewarganegaraan: 'WNI',
        masa_berlaku: '2025-01-01',
        role: 'PASIEN',
      };

      // Create user
      const createResponse = await request(app.getHttpServer())
        .post('/users')
        .send(userData)
        .expect(201);

      const userId = createResponse.body.id;

      // Login with created user
      const loginResponse = await request(app.getHttpServer())
        .post('/auth/login/user')
        .send({
          email: userData.email,
          password: userData.password,
        })
        .expect(201);

      expect(loginResponse.body).toHaveProperty('access_token');
      expect(loginResponse.body.user).toHaveProperty('id', userId);

      const { access_token } = loginResponse.body;

      // Get user profile using JWT token
      const profileResponse = await request(app.getHttpServer())
        .get('/users/profile')
        .set('Authorization', `Bearer ${access_token}`)
        .expect(200);

      expect(profileResponse.body).toHaveProperty('id', userId);
      expect(profileResponse.body).toHaveProperty('nama', userData.nama);
      expect(profileResponse.body).not.toHaveProperty('password');
    });

    it('should handle password updates and login with new password', async () => {
      const userData = {
        nik: '8888999900001111',
        nama: 'Password Test User',
        email: 'passwordtest@test.com',
        password: 'oldpassword123',
        tempat_lahir: 'Password City',
        tanggal_lahir: '1990-01-01',
        alamat: 'Password Address 123',
        rt: '001',
        rw: '002',
        kelurahan: 'Password Village',
        kecamatan: 'Password District',
        agama: 'Islam',
        status_perkawinan: 'Belum Kawin',
        pekerjaan: 'Password Tester',
        kewarganegaraan: 'WNI',
        masa_berlaku: '2025-01-01',
        role: 'PASIEN',
      };

      // Create user
      const createResponse = await request(app.getHttpServer())
        .post('/users')
        .send(userData)
        .expect(201);

      const userId = createResponse.body.id;

      // Login with old password
      const loginResponse = await request(app.getHttpServer())
        .post('/auth/login/user')
        .send({
          email: userData.email,
          password: userData.password,
        })
        .expect(201);

      const { access_token } = loginResponse.body;

      // Update password
      await request(app.getHttpServer())
        .patch(`/users/${userId}/password`)
        .set('Authorization', `Bearer ${access_token}`)
        .send({
          current_password: 'oldpassword123',
          new_password: 'newpassword123',
        })
        .expect(200);

      // Try login with old password (should fail)
      await request(app.getHttpServer())
        .post('/auth/login/user')
        .send({
          email: userData.email,
          password: 'oldpassword123',
        })
        .expect(401);

      // Login with new password (should succeed)
      const newLoginResponse = await request(app.getHttpServer())
        .post('/auth/login/user')
        .send({
          email: userData.email,
          password: 'newpassword123',
        })
        .expect(201);

      expect(newLoginResponse.body).toHaveProperty('access_token');
    });
  });
});
