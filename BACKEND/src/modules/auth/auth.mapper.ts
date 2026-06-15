import { formatBirthDate } from '../../shared/validation/birth_date';
import { PublicUser, UserRow } from './auth.types';

export function toPublicUser(user: UserRow): PublicUser {
  return {
    id: user.id,
    username: user.username,
    name: user.name,
    mail: user.mail,
    birth_date: formatBirthDate(user.birth_date),
    email_notifications_enabled: user.email_notifications_enabled
  };
}
