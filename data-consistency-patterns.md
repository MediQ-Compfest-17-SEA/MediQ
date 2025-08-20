# Data Consistency Patterns untuk MediQ Microservices

## 1. Eventual Consistency (Sudah Diterapkan)
```typescript
// User Service - Event handler
@EventPattern('user_register_ocr')
async handleUserRegisterFromOcr(@Payload() data: { nik: string; name: string }) {
  // Data akan eventually consistent setelah message diproses
}
```

## 2. Saga Pattern (Direkomendasikan)
```typescript
// API Gateway - Orchestrator
export class UserRegistrationSaga {
  async registerUser(userData) {
    try {
      // Step 1: Create user
      const user = await this.userService.send('create_user', userData);
      
      // Step 2: Create initial queue entry  
      await this.queueService.send('init_patient_queue', { userId: user.id });
      
      return user;
    } catch (error) {
      // Compensating actions
      await this.userService.send('rollback_user', { userId: user.id });
      throw error;
    }
  }
}
```

## 3. Event Sourcing
```typescript
// User Service - Event store
export class UserEventStore {
  async saveEvent(event) {
    await this.prisma.userEvent.create({
      data: {
        aggregateId: event.userId,
        eventType: event.type,
        eventData: event.data,
        version: event.version,
        timestamp: new Date()
      }
    });
  }
}
```

## 4. Two-Phase Commit (Untuk operasi critical)
```typescript
// Distributed transaction coordinator
export class TransactionCoordinator {
  async distributedTransaction(operation) {
    // Phase 1: Prepare
    const prepared = await Promise.all([
      this.userService.send('prepare_user_update', operation.userData),
      this.queueService.send('prepare_queue_update', operation.queueData)
    ]);
    
    // Phase 2: Commit or Rollback
    if (prepared.every(p => p.success)) {
      await Promise.all([
        this.userService.send('commit_user_update', operation.userData),
        this.queueService.send('commit_queue_update', operation.queueData)
      ]);
    } else {
      // Rollback
      await this.rollback(operation);
    }
  }
}
```

## 5. Database Per Service + Outbox Pattern
```typescript
// User Service - Outbox table
model OutboxEvent {
  id        String   @id @default(uuid())
  eventType String
  payload   Json
  processed Boolean  @default(false)
  createdAt DateTime @default(now())
}

// Publisher service
export class OutboxPublisher {
  @Cron('*/5 * * * * *') // Every 5 seconds
  async publishEvents() {
    const events = await this.prisma.outboxEvent.findMany({
      where: { processed: false },
      take: 10
    });
    
    for (const event of events) {
      await this.messagingService.send(event.eventType, event.payload);
      await this.markAsProcessed(event.id);
    }
  }
}
```

## Implementasi untuk MediQ:

### A. Immediate Actions:
1. **Event Sourcing** untuk audit trail user registrations
2. **Outbox Pattern** untuk reliable message delivery  
3. **Idempotency** keys untuk duplicate prevention

### B. Advanced Patterns:
1. **CQRS** - Separate read/write models
2. **Circuit Breaker** untuk fault tolerance
3. **Distributed locks** untuk race conditions
