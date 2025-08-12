'use strict';

const userRepository = require('../data/userRepository');
const authenticationService = require('./authenticationService');
const {
    InvariantError,
    AuthenticationError,
    NotFoundError
} = require('../lib/errors');

const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { nanoid } = require('nanoid');

class UserService {
    /**
     * Mendaftarkan pengguna baru.
     */
    async registerUser({ name, email, password }) {
        const existingUser = await userRepository.getUserByEmail(email);
        if (existingUser) {
            throw new InvariantError('Email sudah digunakan');
        }

        const saltRounds = parseInt(process.env.BCRYPT_SALT_ROUNDS, 10);
        const hashedPassword = await bcrypt.hash(password, saltRounds);
        const id = `user-${nanoid(16)}`;

        await userRepository.addUser({
            id,
            name,
            email,
            role: 'pasien', // Default role
            hashedPassword
        });

        return { id, name, email };
    }

    /**
     * Memproses login pengguna dan mengembalikan token.
     */
    async loginUser({ email, password }) {
        const user = await userRepository.getUserByEmail(email);
        if (!user) {
            throw new AuthenticationError('Kredensial yang Anda berikan salah');
        }

        const isPasswordValid = await bcrypt.compare(password, user.password);
        if (!isPasswordValid) {
            throw new AuthenticationError('Kredensial yang Anda berikan salah');
        }

        const accessToken = this._createAccessToken({ id: user.id, role: user.role });
        const refreshToken = this._createRefreshToken({ id: user.id });

        await authenticationService.addRefreshToken(refreshToken);

        return { accessToken, refreshToken };
    }

    /**
     * Memperbarui access token menggunakan refresh token.
     */
    async refreshAccessToken(refreshToken) {
        await authenticationService.verifyRefreshToken(refreshToken);
        const { id } = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);

        const user = await userRepository.getUserById(id);
        if (!user) {
            throw new AuthenticationError('Refresh token tidak valid');
        }

        return this._createAccessToken({ id: user.id, role: user.role });
    }

    /**
     * Mengambil profil pengguna berdasarkan ID.
     */
    async getUserProfile(id) {
        const user = await userRepository.getUserById(id);
        if (!user) {
            throw new NotFoundError('User tidak ditemukan');
        }
        
        return user;
    }

    /**
     * Mengubah kata sandi pengguna.
     */
    async changeUserPassword(userId, { oldPassword, newPassword }) {
        const user = await userRepository.getUserById(userId);
        if (!user) {
            throw new NotFoundError('User tidak ditemukan');
        }

        const isOldPasswordValid = await bcrypt.compare(oldPassword, user.password);
        if (!isOldPasswordValid) {
            throw new AuthenticationError('Kata sandi lama salah');
        }

        const newHashedPassword = await bcrypt.hash(newPassword, parseInt(process.env.BCRYPT_SALT_ROUNDS, 10));
        await userRepository.updateUserPassword(user.id, newHashedPassword);
    }

    // --- Private Helper Methods ---

    _createAccessToken(payload) {
        return jwt.sign(payload, process.env.JWT_SECRET, { 
            expiresIn: process.env.JWT_EXPIRES_IN || '30m' 
        });
    }

    _createRefreshToken(payload) {
        return jwt.sign(payload, process.env.JWT_REFRESH_SECRET, { 
            expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d' 
        });
    }
}

module.exports = new UserService();