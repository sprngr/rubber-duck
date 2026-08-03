/**
 * Logger: leaf dependency, no injection needed.
 */
export class Logger {
  log(msg: string): void {
    console.log(`[app] ${msg}`);
  }
}
