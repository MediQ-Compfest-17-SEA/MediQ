'use strict';

require('dotenv').config();
const Hapi = require('@hapi/hapi');

// Impor plugin dan logika internal
const userApi = require('./src/api/users');
const { ClientError } = require('./src/lib/errors');

// Impor plugin untuk dokumentasi
const Inert = require('@hapi/inert');
const Vision = require('@hapi/vision');
const HapiSwagger = require('hapi-swagger');
const pack = require('./package.json');

// Daftar asal yang diizinkan untuk CORS
const allowedOrigins = process.env.CORS_ALLOWED_ORIGINS ? process.env.CORS_ALLOWED_ORIGINS.split(',') : ['*'];
/**
 * Fungsi untuk membuat dan mengonfigurasi instance server Hapi.
 * Fungsi ini tidak menjalankan server, hanya menyiapkannya.
 */
const init = async () => {
    const server = Hapi.server({
        port: process.env.PORT || 3001,
        host: process.env.HOST || 'localhost',
        routes: {
            cors: {
                origin: allowedOrigins,
            },
        },
    });

    // Registrasi plugin pihak ketiga (Swagger, dll.)
    await server.register([
        Inert,
        Vision,
        {
            plugin: HapiSwagger,
            options: {
                info: {
                    title: 'Dokumentasi API MediQ - User Service',
                    version: pack.version,
                    description: 'API untuk manajemen pengguna, otentikasi, dan profil.'
                },
                grouping: 'tags',
                tags: [
                    { name: 'auth', description: 'Endpoint terkait otentikasi (login, register, dll.)' },
                    { name: 'users', description: 'Endpoint untuk manajemen profil pengguna' },
                ],
            },
        },
    ]);

    // Registrasi plugin internal (API rute)
    await server.register(userApi);

    // Ekstensi untuk menangani dan memformat error secara terpusat
    server.ext('onPreResponse', (request, h) => {
        const { response } = request;
        
        if (response instanceof Error) {
            if (response instanceof ClientError) {
                const newResponse = h.response({
                    status: 'fail',
                    message: response.message
                });
                newResponse.code(response.statusCode);
                return newResponse;
            }

            if (!response.isServer) {
                return h.continue;
            }

            console.error(response);
            const newResponse = h.response({
                status: 'error',
                message: 'Maaf, terjadi kegagalan pada server kami.'
            });
            newResponse.code(500);
            return newResponse;
        }

        return h.continue;
    });

    return server;
};

/**
 * Fungsi untuk menjalankan server.
 * Hanya dipanggil jika file ini dieksekusi secara langsung.
 */
const start = async () => {
    console.log('Starting server...');
    const server = await init();
    await server.start();
    console.log(`Server running at: ${server.info.uri}`);
    console.log(`API documentation available at: ${server.info.uri}/documentation`);
};

// Menangani promise yang tidak tertangani untuk mencegah crash
process.on('unhandledRejection', (err) => {
    console.error('Unhandled rejection:', err);
    process.exit(1);
});

// Cek apakah file ini dijalankan langsung oleh Node atau diimpor oleh file lain (seperti tes)
if (require.main === module) {
    start();
}

// Ekspor fungsi init agar bisa digunakan oleh lingkungan pengujian
module.exports = { init };