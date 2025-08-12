'use strict';

class ClientError extends Error {
    constructor(message, statusCode = 400) {
        super(message);
        this.statusCode = statusCode;
        this.name = 'ClientError';
    }
}

class InvariantError extends ClientError {
    constructor(message) { super(message, 400); this.name = 'InvariantError'; }
}
class AuthenticationError extends ClientError {
    constructor(message) { super(message, 401); this.name = 'AuthenticationError'; }
}
class NotFoundError extends ClientError {
    constructor(message) { super(message, 404); this.name = 'NotFoundError'; }
}

module.exports = {
    ClientError,
    InvariantError,
    AuthenticationError,
    NotFoundError,
};