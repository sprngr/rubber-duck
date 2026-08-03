export interface PaymentInput {
  payerEmail: string;
  payerPassword: string;
  amount: number;
}

export function validatePayment(input: PaymentInput): string[] {
  const errors: string[] = [];

  // Duplicated validation: email format (same as userValidator, orderValidator)
  if (!input.payerEmail || input.payerEmail.length === 0) {
    errors.push("email required");
  } else if (!input.payerEmail.includes("@")) {
    errors.push("email invalid format");
  } else if (!input.payerEmail.includes(".")) {
    errors.push("email invalid format");
  }

  // Duplicated validation: password strength (same as userValidator, orderValidator)
  if (!input.payerPassword || input.payerPassword.length < 8) {
    errors.push("password too short");
  } else if (!/[A-Z]/.test(input.payerPassword)) {
    errors.push("password needs uppercase");
  } else if (!/[0-9]/.test(input.payerPassword)) {
    errors.push("password needs digit");
  }

  // Payment-specific
  if (input.amount <= 0) {
    errors.push("amount must be positive");
  }

  return errors;
}
