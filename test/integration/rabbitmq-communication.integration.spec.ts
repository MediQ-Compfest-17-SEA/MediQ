import { Test, TestingModule } from '@nestjs/testing';
import { ClientProxy, ClientsModule, Transport } from '@nestjs/microservices';
import { INestApplication } from '@nestjs/common';
import * as amqp from 'amqplib';

describe('RabbitMQ Communication Integration Tests', () => {
  let app: INestApplication;
  let connection: amqp.Connection;
  let channel: amqp.Channel;
  let userServiceClient: ClientProxy;
  let ocrServiceClient: ClientProxy;
  let queueServiceClient: ClientProxy;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [
        ClientsModule.register([
          {
            name: 'USER_SERVICE',
            transport: Transport.RMQ,
            options: {
              urls: [process.env.RABBITMQ_URL || 'amqp://localhost:5672'],
              queue: 'user_service_queue',
              queueOptions: {
                durable: true,
              },
            },
          },
          {
            name: 'OCR_SERVICE',
            transport: Transport.RMQ,
            options: {
              urls: [process.env.RABBITMQ_URL || 'amqp://localhost:5672'],
              queue: 'ocr_service_queue',
              queueOptions: {
                durable: true,
              },
            },
          },
          {
            name: 'QUEUE_SERVICE',
            transport: Transport.RMQ,
            options: {
              urls: [process.env.RABBITMQ_URL || 'amqp://localhost:5672'],
              queue: 'patient_queue_service_queue',
              queueOptions: {
                durable: true,
              },
            },
          },
        ]),
      ],
    }).compile();

    app = moduleFixture.createNestApplication();
    userServiceClient = app.get('USER_SERVICE');
    ocrServiceClient = app.get('OCR_SERVICE');
    queueServiceClient = app.get('QUEUE_SERVICE');

    // Direct RabbitMQ connection for testing
    connection = await amqp.connect(process.env.RABBITMQ_URL || 'amqp://localhost:5672');
    channel = await connection.createChannel();

    await app.init();
  });

  afterAll(async () => {
    await userServiceClient.close();
    await ocrServiceClient.close();
    await queueServiceClient.close();
    await channel.close();
    await connection.close();
    await app.close();
  });

  describe('Message Delivery Reliability', () => {
    it('should deliver messages reliably with acknowledgements', async () => {
      const testMessage = { nik: '1234567890123456', nama: 'Test User' };
      let messageReceived = false;
      let messageData = null;

      // Set up message consumer
      await channel.assertQueue('test_queue', { durable: true });
      
      await channel.consume('test_queue', (msg) => {
        if (msg) {
          messageReceived = true;
          messageData = JSON.parse(msg.content.toString());
          channel.ack(msg);
        }
      });

      // Send message via client
      const response = await userServiceClient.send('user.create', testMessage).toPromise();

      // Wait for message processing
      await new Promise(resolve => setTimeout(resolve, 100));

      expect(messageReceived).toBe(true);
      expect(messageData).toEqual(testMessage);
    });

    it('should handle message failures and redelivery', async () => {
      const testMessage = { test: 'failure-scenario' };
      let deliveryCount = 0;

      await channel.assertQueue('failure_test_queue', { durable: true });

      await channel.consume('failure_test_queue', (msg) => {
        if (msg) {
          deliveryCount++;
          if (deliveryCount < 3) {
            // Reject message to trigger redelivery
            channel.nack(msg, false, true);
          } else {
            // Accept message on third attempt
            channel.ack(msg);
          }
        }
      });

      await userServiceClient.send('test.failure', testMessage).toPromise();

      // Wait for redelivery attempts
      await new Promise(resolve => setTimeout(resolve, 500));

      expect(deliveryCount).toBe(3);
    });

    it('should handle dead letter queue for failed messages', async () => {
      const testMessage = { test: 'dead-letter-scenario' };
      let dlqMessageReceived = false;

      // Set up main queue with DLQ configuration
      await channel.assertQueue('main_queue', {
        durable: true,
        arguments: {
          'x-dead-letter-exchange': 'dlx',
          'x-dead-letter-routing-key': 'failed',
          'x-message-ttl': 1000, // 1 second TTL
        },
      });

      // Set up dead letter exchange and queue
      await channel.assertExchange('dlx', 'direct', { durable: true });
      await channel.assertQueue('dead_letter_queue', { durable: true });
      await channel.bindQueue('dead_letter_queue', 'dlx', 'failed');

      // Consumer that always rejects messages
      await channel.consume('main_queue', (msg) => {
        if (msg) {
          channel.nack(msg, false, false); // Reject without requeue
        }
      });

      // Dead letter queue consumer
      await channel.consume('dead_letter_queue', (msg) => {
        if (msg) {
          dlqMessageReceived = true;
          channel.ack(msg);
        }
      });

      // Send message to main queue
      await channel.sendToQueue('main_queue', Buffer.from(JSON.stringify(testMessage)), {
        persistent: true,
      });

      // Wait for DLQ processing
      await new Promise(resolve => setTimeout(resolve, 2000));

      expect(dlqMessageReceived).toBe(true);
    });
  });

  describe('Cross-Service Communication Patterns', () => {
    it('should support request-response pattern between services', async () => {
      const userCreateMessage = {
        nik: '2222333344445555',
        nama: 'RPC Test User',
        email: 'rpc@test.com',
      };

      // Mock user service response
      await channel.assertQueue('user_service_queue', { durable: true });
      
      await channel.consume('user_service_queue', (msg) => {
        if (msg) {
          const request = JSON.parse(msg.content.toString());
          const response = {
            id: 'user123',
            ...request,
            created_at: new Date().toISOString(),
          };

          channel.sendToQueue(msg.properties.replyTo, Buffer.from(JSON.stringify(response)), {
            correlationId: msg.properties.correlationId,
          });
          
          channel.ack(msg);
        }
      });

      // Send request and wait for response
      const result = await userServiceClient.send('user.create', userCreateMessage).toPromise();

      expect(result).toHaveProperty('id');
      expect(result).toHaveProperty('nik', userCreateMessage.nik);
      expect(result).toHaveProperty('created_at');
    });

    it('should support publish-subscribe pattern for events', async () => {
      const eventData = { user_id: 'user123', event: 'user_registered' };
      let ocrServiceReceived = false;
      let queueServiceReceived = false;

      // Set up event exchange
      await channel.assertExchange('user_events', 'fanout', { durable: true });

      // OCR service subscriber
      const ocrQueue = await channel.assertQueue('', { exclusive: true });
      await channel.bindQueue(ocrQueue.queue, 'user_events', '');
      await channel.consume(ocrQueue.queue, (msg) => {
        if (msg) {
          ocrServiceReceived = true;
          channel.ack(msg);
        }
      });

      // Queue service subscriber  
      const queueQueue = await channel.assertQueue('', { exclusive: true });
      await channel.bindQueue(queueQueue.queue, 'user_events', '');
      await channel.consume(queueQueue.queue, (msg) => {
        if (msg) {
          queueServiceReceived = true;
          channel.ack(msg);
        }
      });

      // Publish event
      await channel.publish('user_events', '', Buffer.from(JSON.stringify(eventData)));

      // Wait for event processing
      await new Promise(resolve => setTimeout(resolve, 100));

      expect(ocrServiceReceived).toBe(true);
      expect(queueServiceReceived).toBe(true);
    });

    it('should handle service discovery and dynamic routing', async () => {
      const serviceMessage = { action: 'dynamic_route_test' };
      const services = ['service_a', 'service_b', 'service_c'];
      let receivedServices = [];

      // Set up multiple service instances
      for (const serviceName of services) {
        await channel.assertQueue(serviceName, { durable: true });
        await channel.consume(serviceName, (msg) => {
          if (msg) {
            receivedServices.push(serviceName);
            channel.ack(msg);
          }
        });
      }

      // Send messages to different services
      for (const serviceName of services) {
        await channel.sendToQueue(serviceName, Buffer.from(JSON.stringify(serviceMessage)));
      }

      // Wait for processing
      await new Promise(resolve => setTimeout(resolve, 100));

      expect(receivedServices).toHaveLength(3);
      expect(receivedServices).toEqual(expect.arrayContaining(services));
    });
  });

  describe('Message Serialization and Validation', () => {
    it('should handle complex message serialization', async () => {
      const complexMessage = {
        user: {
          nik: '3333444455556666',
          nama: 'Complex User',
          metadata: {
            registration_source: 'OCR',
            confidence_score: 0.95,
            extracted_fields: ['nik', 'nama', 'alamat'],
          },
        },
        timestamp: new Date().toISOString(),
        nested_array: [
          { field: 'tempat_lahir', value: 'Jakarta' },
          { field: 'tanggal_lahir', value: '1990-01-01' },
        ],
      };

      let receivedMessage = null;

      await channel.assertQueue('serialization_test', { durable: true });
      await channel.consume('serialization_test', (msg) => {
        if (msg) {
          receivedMessage = JSON.parse(msg.content.toString());
          channel.ack(msg);
        }
      });

      await channel.sendToQueue('serialization_test', Buffer.from(JSON.stringify(complexMessage)));

      await new Promise(resolve => setTimeout(resolve, 100));

      expect(receivedMessage).toEqual(complexMessage);
      expect(receivedMessage.user.metadata.confidence_score).toBe(0.95);
      expect(receivedMessage.nested_array).toHaveLength(2);
    });

    it('should validate message schemas', async () => {
      const invalidMessage = {
        nik: 123, // Should be string
        nama: null, // Should not be null
        // Missing required fields
      };

      const validMessage = {
        nik: '4444555566667777',
        nama: 'Valid User',
        email: 'valid@test.com',
      };

      let validationErrors = [];
      let validMessages = [];

      await channel.assertQueue('validation_test', { durable: true });
      await channel.consume('validation_test', (msg) => {
        if (msg) {
          try {
            const message = JSON.parse(msg.content.toString());
            
            // Simple validation logic
            if (typeof message.nik !== 'string' || !message.nama || message.nik.length !== 16) {
              validationErrors.push(message);
            } else {
              validMessages.push(message);
            }
            
            channel.ack(msg);
          } catch (error) {
            validationErrors.push({ error: error.message });
            channel.nack(msg, false, false);
          }
        }
      });

      // Send invalid message
      await channel.sendToQueue('validation_test', Buffer.from(JSON.stringify(invalidMessage)));
      
      // Send valid message
      await channel.sendToQueue('validation_test', Buffer.from(JSON.stringify(validMessage)));

      await new Promise(resolve => setTimeout(resolve, 100));

      expect(validationErrors).toHaveLength(1);
      expect(validMessages).toHaveLength(1);
      expect(validMessages[0]).toEqual(validMessage);
    });
  });

  describe('Connection Management and Resilience', () => {
    it('should handle connection failures and reconnection', async () => {
      let reconnectionAttempts = 0;
      let messagesAfterReconnection = 0;

      // Simulate connection failure by closing current connection
      await connection.close();

      // Reconnect with retry logic
      let newConnection;
      let newChannel;
      
      try {
        for (let i = 0; i < 3; i++) {
          try {
            reconnectionAttempts++;
            newConnection = await amqp.connect(process.env.RABBITMQ_URL || 'amqp://localhost:5672');
            newChannel = await newConnection.createChannel();
            break;
          } catch (error) {
            if (i === 2) throw error;
            await new Promise(resolve => setTimeout(resolve, 1000));
          }
        }

        await newChannel.assertQueue('reconnection_test', { durable: true });
        await newChannel.consume('reconnection_test', (msg) => {
          if (msg) {
            messagesAfterReconnection++;
            newChannel.ack(msg);
          }
        });

        // Send test message after reconnection
        await newChannel.sendToQueue('reconnection_test', Buffer.from('reconnection test'));

        await new Promise(resolve => setTimeout(resolve, 100));

        expect(reconnectionAttempts).toBeGreaterThan(0);
        expect(messagesAfterReconnection).toBe(1);

      } finally {
        if (newChannel) await newChannel.close();
        if (newConnection) await newConnection.close();
        
        // Restore original connection for other tests
        connection = await amqp.connect(process.env.RABBITMQ_URL || 'amqp://localhost:5672');
        channel = await connection.createChannel();
      }
    });

    it('should implement heartbeat and connection monitoring', async () => {
      const heartbeatInterval = 1000; // 1 second
      let heartbeatCount = 0;

      // Set up heartbeat mechanism
      const heartbeatTimer = setInterval(async () => {
        try {
          await channel.checkQueue('heartbeat_test');
          heartbeatCount++;
        } catch (error) {
          clearInterval(heartbeatTimer);
        }
      }, heartbeatInterval);

      // Wait for several heartbeats
      await new Promise(resolve => setTimeout(resolve, 3500));
      clearInterval(heartbeatTimer);

      expect(heartbeatCount).toBeGreaterThanOrEqual(3);
    });

    it('should handle message ordering and priorities', async () => {
      const messages = [
        { id: 1, priority: 5, content: 'normal priority' },
        { id: 2, priority: 10, content: 'high priority' },
        { id: 3, priority: 1, content: 'low priority' },
        { id: 4, priority: 10, content: 'another high priority' },
      ];

      const receivedMessages = [];

      // Set up priority queue
      await channel.assertQueue('priority_test', {
        durable: true,
        arguments: { 'x-max-priority': 10 },
      });

      await channel.consume('priority_test', (msg) => {
        if (msg) {
          const message = JSON.parse(msg.content.toString());
          receivedMessages.push(message);
          channel.ack(msg);
        }
      });

      // Send messages with different priorities
      for (const message of messages) {
        await channel.sendToQueue('priority_test', Buffer.from(JSON.stringify(message)), {
          priority: message.priority,
        });
      }

      // Wait for processing
      await new Promise(resolve => setTimeout(resolve, 200));

      // High priority messages should be processed first
      expect(receivedMessages[0].priority).toBe(10);
      expect(receivedMessages[1].priority).toBe(10);
      expect(receivedMessages[2].priority).toBe(5);
      expect(receivedMessages[3].priority).toBe(1);
    });
  });
});
