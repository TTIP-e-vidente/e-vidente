import { formatBirthDate } from '../../shared/validation/birth_date';
import { PublicUser, UserRow } from './auth.types';

export function toPublicUser(user: UserRow): PublicUser {
  return {
    id: user.id,
    username: user.username,
    name: user.name,
    mail: user.mail ?? user.email,
    birth_date: formatBirthDate(user.birth_date)
  };
}
