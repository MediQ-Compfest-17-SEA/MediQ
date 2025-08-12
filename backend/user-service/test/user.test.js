'use strict';

const Lab = require('@hapi/lab');
const { expect } = require('@hapi/code');
const { init } = require('../index'); // Impor fungsi init dari server.js
const pool = require('../src/lib/database'); // Impor pool database untuk cleanup

const { afterEach, beforeEach, describe, it } = exports.lab = Lab.script();

describe('User API End-to-End Tests', () => {
    
    let server;

    // Fungsi helper untuk membersihkan database setelah setiap tes
    const cleanupDb = async () => {
        await pool.query('DELETE FROM authentications');
        await pool.query('DELETE FROM users');
    };

    // Sebelum setiap tes, inisialisasi server dan bersihkan DB
    beforeEach(async () => {
        await cleanupDb(); // Pastikan database bersih sebelum tes dimulai
        server = await init();
        await server.initialize();
    });

    // Setelah setiap tes, hentikan server
    afterEach(async () => {
        await server.stop();
    });

    // --- Pengujian Registrasi ---
    describe('POST /register', () => {
        it('should register a new user successfully', async () => {
            const response = await server.inject({
                method: 'POST',
                url: '/register',
                payload: {
                    name: 'Test User',
                    email: 'test.success@example.com',
                    password: 'password123'
                }
            });

            const payload = JSON.parse(response.payload);
            expect(response.statusCode).to.equal(201);
            expect(payload.status).to.equal('success');
            expect(payload.data.email).to.equal('test.success@example.com');
        });

        it('should fail to register with an existing email', async () => {
            // Daftarkan user pertama
            await server.inject({
                method: 'POST',
                url: '/register',
                payload: { name: 'First User', email: 'test.duplicate@example.com', password: 'password123' }
            });

            // Coba daftarkan lagi dengan email yang sama
            const response = await server.inject({
                method: 'POST',
                url: '/register',
                payload: { name: 'Second User', email: 'test.duplicate@example.com', password: 'password456' }
            });

            const payload = JSON.parse(response.payload);
            expect(response.statusCode).to.equal(400); // Di-handle oleh InvariantError
            expect(payload.message).to.equal('Email sudah digunakan');
        });

        it('should fail with invalid payload (short password)', async () => {
            const response = await server.inject({
                method: 'POST',
                url: '/register',
                payload: { name: 'Test User', email: 'test.invalid@example.com', password: '123' } // Password terlalu pendek
            });
            expect(response.statusCode).to.equal(400); // Error validasi Joi
        });
    });

    // --- Pengujian Otentikasi (Login, Logout, Refresh) ---
    describe('Authentication Flow', () => {
        // Fungsi helper untuk mendaftar dan login user dalam satu langkah
        const registerAndLogin = async () => {
            const userCredentials = {
                email: 'test.auth@example.com',
                password: 'password123'
            };
            await server.inject({
                method: 'POST',
                url: '/register',
                payload: { name: 'Auth User', ...userCredentials }
            });
            const response = await server.inject({
                method: 'POST',
                url: '/login',
                payload: userCredentials
            });
            return JSON.parse(response.payload).data; // Mengembalikan { accessToken, refreshToken }
        };

        it('should login successfully and return tokens', async () => {
            const { accessToken, refreshToken } = await registerAndLogin();
            expect(accessToken).to.be.a.string();
            expect(refreshToken).to.be.a.string();
        });

        it('should fail to login with wrong password', async () => {
            await registerAndLogin(); // Daftarkan user
            const response = await server.inject({
                method: 'POST',
                url: '/login',
                payload: { email: 'test.auth@example.com', password: 'wrongpassword' }
            });
            expect(response.statusCode).to.equal(401); // AuthenticationError
        });

        it('should refresh access token successfully', async () => {
            const { refreshToken } = await registerAndLogin();
            const response = await server.inject({
                method: 'PUT',
                url: '/token/refresh',
                payload: { refreshToken }
            });
            const payload = JSON.parse(response.payload);
            expect(response.statusCode).to.equal(200);
            expect(payload.data.accessToken).to.be.a.string();
        });

        it('should logout successfully by revoking refresh token', async () => {
            const { refreshToken } = await registerAndLogin();
            
            // Logout
            const logoutResponse = await server.inject({
                method: 'DELETE',
                url: '/logout',
                payload: { refreshToken }
            });
            expect(logoutResponse.statusCode).to.equal(200);

            // Coba gunakan refresh token yang sama lagi, seharusnya gagal
            const refreshResponse = await server.inject({
                method: 'PUT',
                url: '/token/refresh',
                payload: { refreshToken }
            });

            const payload = JSON.parse(refreshResponse.payload);
            expect(refreshResponse.statusCode).to.equal(400); // InvariantError
            expect(payload.message).to.equal('Refresh token tidak valid');
        });
    });

    // --- Pengujian Rute Terlindungi ---
describe('Protected Routes', () => {
        // Fungsi untuk memberi jeda singkat
        const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

        it('should get profile successfully with valid token', async () => {
            // 1. Setup
            const email = 'profile.finaltest@example.com';
            const password = 'password123';

            await server.inject({
                method: 'POST',
                url: '/register',
                payload: { name: 'Profile Test User', email, password },
            });

            const loginResponse = await server.inject({
                method: 'POST',
                url: '/login',
                payload: { email, password },
            });
            const { accessToken } = JSON.parse(loginResponse.payload).data;

            await delay(50);

            // 2. Action
            const profileResponse = await server.inject({
                method: 'GET',
                url: '/profile',
                headers: { Authorization: `Bearer ${accessToken}` }
            });

            // 3. Assert
            const profilePayload = JSON.parse(profileResponse.payload);
            expect(profileResponse.statusCode).to.equal(200);
            expect(profilePayload.data.email).to.equal(email);
        });

        it('should change password successfully', async () => {
            // 1. Setup
            const email = 'changepass.finaltest@example.com';
            const oldPassword = 'password123';
            const newPassword = 'newpassword456';

            await server.inject({
                method: 'POST',
                url: '/register',
                payload: { name: 'Change Pass User', email, password: oldPassword }
            });

            const loginResponse = await server.inject({
                method: 'POST',
                url: '/login',
                payload: { email, password: oldPassword },
            });
            const { accessToken } = JSON.parse(loginResponse.payload).data;

            // 2. Action
            const changePassResponse = await server.inject({
                method: 'POST',
                url: '/password/change',
                headers: { Authorization: `Bearer ${accessToken}` },
                payload: { oldPassword, newPassword },
            });
            expect(changePassResponse.statusCode).to.equal(200);

            // 3. Assert
            const newLoginResponse = await server.inject({
                method: 'POST',
                url: '/login',
                payload: { email, password: newPassword },
            });
            expect(newLoginResponse.statusCode).to.equal(200);
        });

        it('should fail to get profile without token', async () => {
            const response = await server.inject({
                method: 'GET',
                url: '/profile',
            });
            expect(response.statusCode).to.equal(401);
        });
    });
});