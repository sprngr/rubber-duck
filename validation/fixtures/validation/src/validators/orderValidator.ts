export interface OrderInput {
  customerEmail: string;
  customerPassword: string;
  quantity: number;
}

export function validateOrder(input: OrderInput): string[] {
  const errors: string[] = [];

  // Duplicated validation: email format (same as userValidator)
  if (!input.customerEmail || input.customerEmail.length === 0) {
    errors.push("email required");
  } else if (!input.customerEmail.includes("@")) {
    errors.push("email invalid format");
  } else if (!input.customerEmail.includes(".")) {
    errors.push("email invalid format");
  }

  // Duplicated validation: password strength (same as userValidator)
  if (!input.customerPassword || input.customerPassword.length < 8) {
    errors.push("password too short");
  } else if (!/[A-Z]/.test(input.customerPassword)) {
    errors.push("password needs uppercase");
  } else if (!/[0-9]/.test(input.customerPassword)) {
    errors.push("password needs digit");
  }

  // Order-specific
  if (input.quantity <= 0) {
    errors.push("quantity must be positive");
  }

  return errors;
}
