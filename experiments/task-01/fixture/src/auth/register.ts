type Request = { body: { email?: string; password?: string; age?: string } };
type Response = { status: (code: number) => { json: (body: unknown) => unknown } };

function hash(password: string): string {
  return `hash:${password}`;
}

const userRepo = {
  async create(data: { email: string; passwordHash: string; age: number }) {
    return { id: "u_123", ...data };
  },
};

import { parseAge } from "./parseAge";

export async function register(req: Request, res: Response) {
  const { email, password, age } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: "missing required fields" });
  }

  const parsedAge = parseAge(age ?? "");

  if (parsedAge < 13) {
    return res.status(400).json({ error: "must be 13+" });
  }

  const user = await userRepo.create({
    email,
    passwordHash: hash(password),
    age: parsedAge,
  });

  return res.status(201).json({ id: user.id });
}
