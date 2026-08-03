import type { Logger } from "../logger";

/**
 * EmailService: depends on Logger via constructor injection.
 */
export class EmailService {
  constructor(private readonly logger: Logger) {}

  async sendWelcome(to: string, name: string): Promise<void> {
    this.logger.log(`sending welcome email to ${to}`);
  }
}
