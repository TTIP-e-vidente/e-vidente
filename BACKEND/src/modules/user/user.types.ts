export interface UserPublicRow {
  id: string;
  username: string;
  name: string;
  mail: string | null;
  birth_date: Date | string | null;
}
