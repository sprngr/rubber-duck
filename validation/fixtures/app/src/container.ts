import { UserService } from "./services/userService";
import { EmailService } from "./services/emailService";
import { Logger } from "./logger";

/**
 * DI container: composes services with their dependencies.
 * Pattern: constructor injection, single composition root.
 */
export class Container {
  readonly logger: Logger;
  readonly email: EmailService;
  readonly users: UserService;

  constructor() {
    this.logger = new Logger();
    this.email = new EmailService(this.logger);
    this.users = new UserService(this.email, this.logger);
  }
}

export const container = new Container();
