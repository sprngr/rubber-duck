import type { EmailService } from "./emailService";
import type { Logger } from "../logger";

/**
 * UserService: depends on EmailService and Logger via constructor injection.
 * Dependencies injected, not created internally.
 */
export class UserService {
  constructor(
    private readonly email: EmailService,
    private readonly logger: Logger,
  ) {}

  async createUser(name: string, email: string): Promise<{ id: string }> {
    this.logger.log(`creating user ${name}`);
    const id = crypto.randomUUID();
    await this.email.sendWelcome(email, name);
    return { id };
  }
}
