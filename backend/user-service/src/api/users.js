'use strict';

const Joi = require('joi');
const userService = require('../services/userService');
const authenticationService = require('../services/authenticationService');

const validateJwt = async (decoded, request, h) => {
    const payload = decoded.decoded.payload;

    if (!payload || !payload.id) {
        return { isValid: false };
    }

    const credentials = {
        id: payload.id,
        role: payload.role,
    };

    return { isValid: true, credentials };
};

module.exports = {
    name: 'user-api',
    version: '1.0.0',
    register: async (server) => {
        await server.register(require('@hapi/jwt'));

        server.auth.strategy('jwt', 'jwt', {
            keys: process.env.JWT_SECRET,
            verify: { aud: false, iss: false, sub: false },
            validate: validateJwt
        });
        server.auth.default('jwt');
    
        server.route([
            // =================================================================
            // == Endpoint Grup 'auth': Registrasi & Otentikasi
            // =================================================================
            {
                method: 'POST',
                path: '/register',
                options: {
                    auth: false,
                    tags: ['api', 'auth'],
                    description: 'Mendaftarkan pengguna baru.',
                    notes: 'Membuat akun pengguna dengan peran default "pasien".',
                    validate: {
                        payload: Joi.object({
                            name: Joi.string().min(3).required().description('Nama lengkap pengguna'),
                            email: Joi.string().email().required().description('Alamat email unik pengguna'),
                            password: Joi.string().min(6).required().description('Kata sandi pengguna')
                        })
                    },
                },
                handler: async (request, h) => {
                    const newUser = await userService.registerUser(request.payload);
                    return h.response({
                        status: 'success',
                        message: 'User registered successfully',
                        data: newUser
                    }).code(201);
                },
            },
            {
                method: 'POST',
                path: '/login',
                options: {
                    auth: false,
                    tags: ['api', 'auth'],
                    description: 'Login untuk mendapatkan access dan refresh token.',
                    notes: 'Mengembalikan accessToken (durasi pendek) dan refreshToken (durasi panjang).',
                    validate: {
                        payload: Joi.object({
                            email: Joi.string().email().required(),
                            password: Joi.string().required()
                        })
                    },
                },
                handler: async (request, h) => {
                    const { accessToken, refreshToken } = await userService.loginUser(request.payload);
                    return h.response({
                        status: 'success',
                        message: 'Login successful',
                        data: { accessToken, refreshToken },
                    }).code(200);
                },
            },
            {
                method: 'PUT',
                path: '/token/refresh',
                options: {
                    auth: false,
                    tags: ['api', 'auth'],
                    description: 'Memperbarui access token menggunakan refresh token.',
                    notes: 'Kirim refreshToken yang valid untuk mendapatkan accessToken baru.',
                    validate: {
                        payload: Joi.object({
                            refreshToken: Joi.string().required(),
                        }),
                    },
                },
                handler: async (request, h) => {
                    const accessToken = await userService.refreshAccessToken(request.payload.refreshToken);
                    return { status: 'success', data: { accessToken } };
                },
            },
            {
                method: 'DELETE',
                path: '/logout',
                options: {
                    auth: false,
                    tags: ['api', 'auth'],
                    description: 'Logout dan membatalkan refresh token.',
                    notes: 'Mengirim refreshToken akan menghapusnya dari database, membuatnya tidak valid.',
                    validate: {
                        payload: Joi.object({
                            refreshToken: Joi.string().required(),
                        }),
                    },
                },
                handler: async (request, h) => {
                    await authenticationService.deleteRefreshToken(request.payload.refreshToken);
                    return { status: 'success', message: 'Logout successful' };
                },
            },
            // =================================================================
            // == Endpoint Grup 'users': Manajemen Profil Pengguna
            // =================================================================
            {
                method: 'GET',
                path: '/profile',
                options: {
                    tags: ['api', 'users'],
                    description: 'Mengambil data profil pengguna yang sedang login.',
                    notes: 'Membutuhkan header "Authorization: Bearer {accessToken}" yang valid.'
                },
                    handler: async (request, h) => {
                    // Ambil data lengkap pengguna menggunakan ID dari credentials
                    const userId = request.auth.credentials.id;
                    const userProfile = await userService.getUserProfile(userId);
                    
                    delete userProfile.password;
                    return h.response({ status: 'success', data: userProfile });
                },
            },
            {
                method: 'POST',
                path: '/password/change',
                options: {
                    tags: ['api', 'users'],
                    description: 'Mengubah kata sandi pengguna yang sedang login.',
                    notes: 'Membutuhkan header otentikasi. Pengguna harus memberikan kata sandi lama dan baru.',
                    validate: {
                        payload: Joi.object({
                            oldPassword: Joi.string().required(),
                            newPassword: Joi.string().min(6).required()
                        })
                    }
                },
                handler: async (request, h) => {
                    // Teruskan hanya ID pengguna, bukan seluruh objek credentials
                    const userId = request.auth.credentials.id;
                    await userService.changeUserPassword(userId, request.payload);
                    return { status: 'success', message: 'Password changed successfully' };
                },
            }
        ]);
    }
};