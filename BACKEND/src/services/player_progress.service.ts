import { getDevProgressByUsername, saveDevProgress } from './player.service';

export type SavePlayerProgressInput = {
  username: string;
  name?: string;
  restriction: string;
  expToAdd: number;
  nodeId?: string;
  gameType?: string;
  accuracy?: number;
  completed?: boolean;
  score?: number;
};

export async function savePlayerProgress(input: SavePlayerProgressInput): Promise<unknown> {
  return saveDevProgress(input);
}

export async function getPlayerProgressByUsername(username: string): Promise<unknown | null> {
  return getDevProgressByUsername(username);
}
