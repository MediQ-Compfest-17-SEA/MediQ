-- MySQL database initialization script for MediQ Backend
-- Creates databases for User Service and Patient Queue Service

CREATE DATABASE IF NOT EXISTS mediq_users;
CREATE DATABASE IF NOT EXISTS mediq_queue;
CREATE DATABASE IF NOT EXISTS mediq_institutions;

-- Create users with proper permissions
CREATE USER IF NOT EXISTS 'mediq_user'@'%' IDENTIFIED BY 'mediq_password_2024';
CREATE USER IF NOT EXISTS 'mediq_queue'@'%' IDENTIFIED BY 'mediq_password_2024';
CREATE USER IF NOT EXISTS 'mediq_institution'@'%' IDENTIFIED BY 'mediq_password_2024';

-- Grant permissions
GRANT ALL PRIVILEGES ON mediq_users.* TO 'mediq_user'@'%';
GRANT ALL PRIVILEGES ON mediq_queue.* TO 'mediq_queue'@'%';
GRANT ALL PRIVILEGES ON mediq_institutions.* TO 'mediq_institution'@'%';

FLUSH PRIVILEGES;

-- Show created databases
SHOW DATABASES;
