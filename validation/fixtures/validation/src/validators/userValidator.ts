export interface UserInput {
  email: string;
  password: string;
  age: number;
}

export function validateUser(input: UserInput): string[] {
  const errors: string[] = [];

  // Duplicated validation: email format
  if (!input.email || input.email.length === 0) {
    errors.push("email required");
  } else if (!input.email.includes("@")) {
    errors.push("email invalid format");
  } else if (!input.email.includes(".")) {
    errors.push("email invalid format");
  }

  // Duplicated validation: password strength
  if (!input.password || input.password.length < 8) {
    errors.push("password too short");
  } else if (!/[A-Z]/.test(input.password)) {
    errors.push("password needs uppercase");
  } else if (!/[0-9]/.test(input.password)) {
    errors.push("password needs digit");
  }

  // User-specific
  if (input.age < 0 || input.age > 150) {
    errors.push("age out of range");
  }

  return errors;
}
