import { getDevProgressByUsername, saveDevProgress } from './player.service';
import { SavePlayerProgressInput } from './player.types';

export async function savePlayerProgress(input: SavePlayerProgressInput): Promise<unknown> {
  return saveDevProgress(input);
}

export async function getPlayerProgressByUsername(username: string): Promise<unknown | null> {
  return getDevProgressByUsername(username);
}
