'use strict';

const pool = require('../lib/database');
const { InvariantError } = require('../lib/errors');

class AuthenticationService {
    async addRefreshToken(token) {
        await pool.query('INSERT INTO authentications VALUES (?)', [token]);
    }

    async getRefreshToken(token) {
        const [rows] = await pool.query('SELECT token FROM authentications WHERE token = ?', [token]);
        if (rows.length === 0) {
            throw new InvariantError('Refresh token tidak ditemukan');
        }
        return rows[0].token;
    }

async verifyRefreshToken(token) {
    // Menggunakan pool yang sudah kita definisikan secara konsisten
    const [rows] = await pool.query('SELECT token FROM authentications WHERE token = ?', [token]);
    
    // Logika yang benar: throw error jika array 'rows' kosong
    if (rows.length === 0) {
        throw new InvariantError('Refresh token tidak valid');
    }
}

    async deleteRefreshToken(token) {
        await pool.query('DELETE FROM authentications WHERE token = ?', [token]);
    }
}

module.exports = new AuthenticationService(); 