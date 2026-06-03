import { UserPublicRow } from './user.types';

export interface PublicUser {
  id: string;
  username: string;
  name: string;
  mail: string | null;
  age: number | null;
}

export function toPublicUser(row: UserPublicRow): PublicUser {
  return {
    id: row.id,
    username: row.username,
    name: row.name,
    mail: row.mail,
    age: row.age
  };
}
