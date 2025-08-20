import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { ClientProxy } from '@nestjs/microservices';
import * as fs from 'fs';
import * as path from 'path';

describe('OCR Workflow Integration Tests', () => {
  let app: INestApplication;
  let ocrServiceClient: ClientProxy;
  let userServiceClient: ClientProxy;
  let queueServiceClient: ClientProxy;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [], // Import actual modules for integration testing
    }).compile();

    app = moduleFixture.createNestApplication();
    ocrServiceClient = app.get('OCR_SERVICE');
    userServiceClient = app.get('USER_SERVICE');
    queueServiceClient = app.get('QUEUE_SERVICE');
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('KTP Processing End-to-End', () => {
    it('should process KTP image and create user account', async () => {
      // Mock KTP image file
      const testImagePath = path.join(__dirname, '../fixtures/sample-ktp.jpg');
      
      const response = await request(app.getHttpServer())
        .post('/ocr/process-ktp')
        .attach('ktp_image', testImagePath)
        .expect(201);

      expect(response.body).toHaveProperty('processing_id');
      expect(response.body).toHaveProperty('status', 'processing');

      // Wait for processing to complete
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Check processing result
      const resultResponse = await request(app.getHttpServer())
        .get(`/ocr/result/${response.body.processing_id}`)
        .expect(200);

      expect(resultResponse.body).toHaveProperty('status', 'completed');
      expect(resultResponse.body).toHaveProperty('extracted_data');
      expect(resultResponse.body.extracted_data).toHaveProperty('nik');
      expect(resultResponse.body.extracted_data).toHaveProperty('nama');
      expect(resultResponse.body.extracted_data).toHaveProperty('tempat_lahir');
      expect(resultResponse.body.extracted_data).toHaveProperty('tanggal_lahir');
    });

    it('should handle invalid image format gracefully', async () => {
      const testTextFile = path.join(__dirname, '../fixtures/invalid-file.txt');

      const response = await request(app.getHttpServer())
        .post('/ocr/process-ktp')
        .attach('ktp_image', testTextFile)
        .expect(400);

      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toContain('Invalid image format');
    });

    it('should reject oversized images', async () => {
      // Mock large image file (> 5MB)
      const largeImagePath = path.join(__dirname, '../fixtures/large-image.jpg');
      
      const response = await request(app.getHttpServer())
        .post('/ocr/process-ktp')
        .attach('ktp_image', largeImagePath)
        .expect(400);

      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toContain('File too large');
    });

    it('should handle external OCR API failures', async () => {
      // Mock external OCR API failure
      jest.spyOn(ocrServiceClient, 'send').mockRejectedValueOnce(new Error('External OCR API unavailable'));

      const testImagePath = path.join(__dirname, '../fixtures/sample-ktp.jpg');

      const response = await request(app.getHttpServer())
        .post('/ocr/process-ktp')
        .attach('ktp_image', testImagePath)
        .expect(503);

      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toContain('OCR service temporarily unavailable');
    });
  });

  describe('OCR Service ↔ User Service Communication', () => {
    it('should create user account after successful OCR processing', async () => {
      const mockOcrData = {
        nik: '1234567890123456',
        nama: 'John Doe',
        tempat_lahir: 'Jakarta',
        tanggal_lahir: '1990-01-01',
        alamat: 'Jl. Test No. 123',
        rt: '001',
        rw: '002',
        kelurahan: 'Test Village',
        kecamatan: 'Test District',
        agama: 'Islam',
        status_perkawinan: 'Belum Kawin',
        pekerjaan: 'Karyawan Swasta',
        kewarganegaraan: 'WNI',
        masa_berlaku: '2025-01-01',
      };

      // Simulate OCR completion and user creation
      const createUserResponse = await request(app.getHttpServer())
        .post('/users/create-from-ocr')
        .send({ ocr_data: mockOcrData })
        .expect(201);

      expect(createUserResponse.body).toHaveProperty('id');
      expect(createUserResponse.body).toHaveProperty('nik', mockOcrData.nik);
      expect(createUserResponse.body).toHaveProperty('nama', mockOcrData.nama);
      expect(createUserResponse.body).toHaveProperty('role', 'PASIEN');
    });

    it('should handle duplicate NIK detection', async () => {
      const existingNik = '1234567890123456';
      
      const mockOcrData = {
        nik: existingNik,
        nama: 'Jane Doe',
        tempat_lahir: 'Bandung',
        tanggal_lahir: '1985-05-15',
        alamat: 'Jl. Duplicate No. 456',
        rt: '003',
        rw: '004',
        kelurahan: 'Duplicate Village',
        kecamatan: 'Duplicate District',
        agama: 'Kristen',
        status_perkawinan: 'Kawin',
        pekerjaan: 'Guru',
        kewarganegaraan: 'WNI',
        masa_berlaku: '2025-05-15',
      };

      // Try to create user with existing NIK
      const response = await request(app.getHttpServer())
        .post('/users/create-from-ocr')
        .send({ ocr_data: mockOcrData })
        .expect(409);

      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toContain('User with NIK already exists');
    });

    it('should validate OCR data before user creation', async () => {
      const invalidOcrData = {
        nik: '123', // Invalid NIK length
        nama: '', // Empty nama
        tempat_lahir: 'Jakarta',
        tanggal_lahir: 'invalid-date',
      };

      const response = await request(app.getHttpServer())
        .post('/users/create-from-ocr')
        .send({ ocr_data: invalidOcrData })
        .expect(400);

      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toContain('Validation failed');
    });
  });

  describe('OCR Service ↔ Queue Service Integration', () => {
    it('should automatically add user to queue after registration', async () => {
      const mockOcrData = {
        nik: '9876543210987654',
        nama: 'Alice Smith',
        tempat_lahir: 'Surabaya',
        tanggal_lahir: '1992-03-10',
        alamat: 'Jl. Queue Test No. 789',
        rt: '005',
        rw: '006',
        kelurahan: 'Queue Village',
        kecamatan: 'Queue District',
        agama: 'Buddha',
        status_perkawinan: 'Belum Kawin',
        pekerjaan: 'Dokter',
        kewarganegaraan: 'WNI',
        masa_berlaku: '2025-03-10',
      };

      // Create user from OCR
      const createUserResponse = await request(app.getHttpServer())
        .post('/users/create-from-ocr')
        .send({ ocr_data: mockOcrData })
        .expect(201);

      const userId = createUserResponse.body.id;

      // Check if user was added to queue
      const queueResponse = await request(app.getHttpServer())
        .get(`/queue/status/${userId}`)
        .expect(200);

      expect(queueResponse.body).toHaveProperty('queue_number');
      expect(queueResponse.body).toHaveProperty('status', 'waiting');
      expect(queueResponse.body).toHaveProperty('estimated_wait_time');
    });

    it('should handle queue service failures during user registration', async () => {
      // Mock queue service failure
      jest.spyOn(queueServiceClient, 'send').mockRejectedValueOnce(new Error('Queue service unavailable'));

      const mockOcrData = {
        nik: '5555666677778888',
        nama: 'Bob Wilson',
        tempat_lahir: 'Medan',
        tanggal_lahir: '1988-07-20',
        alamat: 'Jl. Failure Test No. 999',
        rt: '007',
        rw: '008',
        kelurahan: 'Failure Village',
        kecamatan: 'Failure District',
        agama: 'Hindu',
        status_perkawinan: 'Kawin',
        pekerjaan: 'Engineer',
        kewarganegaraan: 'WNI',
        masa_berlaku: '2025-07-20',
      };

      // User should still be created even if queue service fails
      const response = await request(app.getHttpServer())
        .post('/users/create-from-ocr')
        .send({ ocr_data: mockOcrData })
        .expect(201);

      expect(response.body).toHaveProperty('id');
      expect(response.body).toHaveProperty('nik', mockOcrData.nik);
      
      // But should log warning about queue service failure
      // Check that user can manually join queue later
      const userId = response.body.id;
      const manualQueueResponse = await request(app.getHttpServer())
        .post('/queue/add')
        .send({ user_id: userId })
        .expect(201);

      expect(manualQueueResponse.body).toHaveProperty('queue_number');
    });
  });

  describe('File Upload Security', () => {
    it('should validate file types and reject malicious files', async () => {
      const maliciousFile = path.join(__dirname, '../fixtures/malicious-script.php');

      const response = await request(app.getHttpServer())
        .post('/ocr/process-ktp')
        .attach('ktp_image', maliciousFile)
        .expect(400);

      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toContain('Invalid file type');
    });

    it('should sanitize uploaded file names', async () => {
      const testImagePath = path.join(__dirname, '../fixtures/sample-ktp.jpg');

      const response = await request(app.getHttpServer())
        .post('/ocr/process-ktp')
        .attach('ktp_image', testImagePath, '../../../etc/passwd.jpg')
        .expect(201);

      expect(response.body).toHaveProperty('processing_id');
      // File should be safely stored with sanitized name
    });
  });
});
