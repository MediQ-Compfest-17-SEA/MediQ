'use strict';

const pool = require('../lib/database');
const { NotFoundError } = require('../lib/errors');

class UserRepository {
    async addUser({ id, name, email, role, hashedPassword }) {
        await pool.query(
            'INSERT INTO users (id, name, email, role, password) VALUES (?, ?, ?, ?, ?)',
            [id, name, email, role, hashedPassword]
        );
    }

    async getUserByEmail(email) {
        const [rows] = await pool.query('SELECT * FROM users WHERE email = ?', [email]);
        return rows[0];
    }

    async getUserById(id) {
        const [rows] = await pool.query('SELECT * FROM users WHERE id = ?', [id]);
        return rows[0];
    }
    
    async updateUserProfile(id, { name }) {
        const [result] = await pool.query(
            'UPDATE users SET name = ? WHERE id = ?',
            [name, id]
        );
        if (result.affectedRows === 0) {
            throw new NotFoundError('Gagal memperbarui profil. User tidak ditemukan.');
        }
    }

    async updateUserPassword(id, hashedPassword) {
        const [result] = await pool.query(
            'UPDATE users SET password = ? WHERE id = ?',
            [hashedPassword, id]
        );
        if (result.affectedRows === 0) {
            throw new NotFoundError('Gagal memperbarui password. User tidak ditemukan.');
        }
    }
}

module.exports = new UserRepository();