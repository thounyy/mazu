import * as fs from "fs";
import { createObjectCsvWriter } from 'csv-writer';
import { getFullnodeUrl, SuiClient, SuiTransactionBlockResponse } from '@mysten/sui.js/client';

export const client = new SuiClient({ url: "https://rpc-mainnet.suiscan.xyz" });

(async () => {

	const currentAddresses = fs.readFileSync('./src/airdrop-utils/pikka-addresses.json', 'utf8');
	const parsedAddresses = JSON.parse(currentAddresses);
	const senders = [];
	for (const address in parsedAddresses) {
		senders.push(parsedAddresses[address].sender);
	}

	fs.writeFileSync(`./src/airdrop-utils/pikka-senders.json`, JSON.stringify(senders, null, 2));

	if (senders) {
		const currentList = fs.readFileSync('./src/airdrop-utils/airdrop_list.json', 'utf8');
		const parsedList = JSON.parse(currentList);
		parsedList.push(...senders);
		const uniqueList = [...new Set(parsedList)];
		const newList = JSON.stringify(uniqueList, null, 2);
		fs.writeFileSync('./src/airdrop-utils/airdrop_list.json', newList, 'utf8');
	}
})()