#!/usr/bin/env node

// Simple webhook server to handle GitHub push events
// Automatically triggers deployment when repositories are updated

const http = require('http');
const crypto = require('crypto');
const { exec } = require('child_process');
const fs = require('fs');

const PORT = 9999;
const SECRET = 'mediq-webhook-secret-2024'; // Change this to a secure secret
const PROJECT_ROOT = '/home/killerking/automated_project/compfest/MediQ';

// Verify GitHub webhook signature
function verifySignature(payload, signature, secret) {
    const expectedSignature = crypto
        .createHmac('sha256', secret)
        .update(payload)
        .digest('hex');
    
    return crypto.timingSafeEqual(
        Buffer.from(`sha256=${expectedSignature}`),
        Buffer.from(signature)
    );
}

// Execute deployment script
function triggerDeployment(repository) {
    console.log(`🚀 Triggering deployment for ${repository}`);
    
    const deployScript = `${PROJECT_ROOT}/scripts/auto-deploy.sh`;
    
    exec(`${deployScript} webhook`, (error, stdout, stderr) => {
        if (error) {
            console.error(`❌ Deployment failed: ${error.message}`);
            return;
        }
        
        if (stderr) {
            console.warn(`⚠️  Deployment warnings: ${stderr}`);
        }
        
        console.log(`✅ Deployment output: ${stdout}`);
    });
}

// Create webhook server
const server = http.createServer((req, res) => {
    if (req.method !== 'POST') {
        res.writeHead(405, { 'Content-Type': 'text/plain' });
        res.end('Method Not Allowed');
        return;
    }
    
    if (req.url !== '/webhook') {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not Found');
        return;
    }
    
    let body = '';
    
    req.on('data', chunk => {
        body += chunk.toString();
    });
    
    req.on('end', () => {
        try {
            // Verify signature if provided
            const signature = req.headers['x-hub-signature-256'];
            if (signature && !verifySignature(body, signature, SECRET)) {
                console.log('❌ Invalid webhook signature');
                res.writeHead(401, { 'Content-Type': 'text/plain' });
                res.end('Unauthorized');
                return;
            }
            
            const payload = JSON.parse(body);
            
            // Check if this is a push event to main branch
            if (payload.ref === 'refs/heads/main' || payload.ref === 'refs/heads/master') {
                const repository = payload.repository.name;
                
                // Only deploy for MediQ repositories
                if (repository.startsWith('MediQ-Backend-')) {
                    triggerDeployment(repository);
                    
                    res.writeHead(200, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({
                        status: 'success',
                        message: `Deployment triggered for ${repository}`,
                        timestamp: new Date().toISOString()
                    }));
                } else {
                    res.writeHead(200, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({
                        status: 'ignored',
                        message: 'Not a MediQ repository',
                        repository: repository
                    }));
                }
            } else {
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({
                    status: 'ignored',
                    message: 'Not a main branch push',
                    ref: payload.ref
                }));
            }
            
        } catch (error) {
            console.error('❌ Webhook processing error:', error.message);
            res.writeHead(400, { 'Content-Type': 'text/plain' });
            res.end('Bad Request');
        }
    });
});

// Start server
server.listen(PORT, () => {
    console.log(`🎣 GitHub webhook server listening on port ${PORT}`);
    console.log(`📡 Webhook URL: http://localhost:${PORT}/webhook`);
    console.log(`🔐 Secret: ${SECRET}`);
    console.log('🔄 Ready to receive GitHub push events...');
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('🛑 Shutting down webhook server...');
    server.close(() => {
        console.log('✅ Webhook server stopped');
        process.exit(0);
    });
});

process.on('SIGINT', () => {
    console.log('🛑 Shutting down webhook server...');
    server.close(() => {
        console.log('✅ Webhook server stopped');
        process.exit(0);
    });
});
