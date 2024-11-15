import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import dotenv from "dotenv";
import * as fs from "fs";

export interface IObjectInfo {
    type: string | undefined
	id: string | undefined
}

dotenv.config();

export const keypair = Ed25519Keypair.fromSecretKey(Uint8Array.from(Buffer.from(process.env.MAINNET_KEY!, "base64")).slice(1));

export const client = new SuiClient({ url: getFullnodeUrl("mainnet") });

export const getId = (type: string): string => {
    try {
        const rawData = fs.readFileSync('./created_mainnet.json', 'utf8');
        const parsedData: IObjectInfo[] = JSON.parse(rawData);
        const typeToId = new Map(parsedData.map(item => [item.type, item.id]));
        for (let [key, value] of typeToId) {
            if (key && key.startsWith(type) && value) {
                return value;
            }
        }
        throw new Error(`No ID found for type: ${type}`);
    } catch (error) {
        console.error('Error:', error);
        throw error;
    }
}