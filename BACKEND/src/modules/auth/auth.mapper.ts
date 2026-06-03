import { PublicUser, UserRow } from './auth.types';

export function toPublicUser(user: UserRow): PublicUser {
  return {
    id: user.id,
    username: user.username,
    name: user.name,
    mail: user.mail ?? user.email,
    age: user.age
  };
}
