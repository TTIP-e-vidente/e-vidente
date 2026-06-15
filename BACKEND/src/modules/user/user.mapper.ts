import { formatBirthDate } from '../../shared/validation/birth_date';
import { UserPublicRow } from './user.types';

export interface PublicUser {
  id: string;
  username: string;
  name: string;
  mail: string | null;
  birth_date: string | null;
  email_notifications_enabled: boolean;
}

export function toPublicUser(row: UserPublicRow): PublicUser {
  return {
    id: row.id,
    username: row.username,
    name: row.name,
    mail: row.mail,
    birth_date: formatBirthDate(row.birth_date),
    email_notifications_enabled: row.email_notifications_enabled
  };
}
