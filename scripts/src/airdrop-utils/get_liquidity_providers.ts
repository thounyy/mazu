import * as fs from "fs";
import { createObjectCsvWriter } from 'csv-writer';
import { getFullnodeUrl, SuiClient, SuiTransactionBlockResponse } from '@mysten/sui/client';

export const client = new SuiClient({ url: "https://rpc-mainnet.suiscan.xyz" });

(async () => {
	const navi = {
		function: "entry_deposit",
		module: "incentive_v2",
		package: "0xc6374c7da60746002bfee93014aeb607e023b2d6b25c9e55a152b826dbc8c1ce",
	}
	const scallop = {
		function: "mint",
		module: "mint",
		package: "0x38fe42a5a69f7eb3635404389e8003be9457b1a5c873f133184648c7e9bd47b7",
	}
	const suilend = {
		function: "deposit_liquidity_and_mint_ctokens",
		module: "lending_market",
		package: "0x6772fecce84a160a7687bf8546ea51d2748559551927762886468f97aff75a38",
	}
	const aftermath = {
		function: "deposit_1_coins",
		module: "amm_interface",
		package: "0x0625dc2cd40aee3998a1d6620de8892964c15066e0a285d8b573910ed4c75d50",
	}
	const turbos = {
		function: "mint",
		module: "position_manager",
		package: "0x1a3c42ded7b75cdf4ebc7c7b7da9d1e1db49f16fcdca934fac003f35f39ecad9",
	}
	const flowx = {
		function: "add_liquidity",
		module: "router",
		package: "0xba153169476e8c3114962261d1edc70de5ad9781b83cc617ecc8c1923191cae0"
	}
	const kriya = {
		function: "add_liquidity",
		module: "spot_dex",
		package: "0xa0eba10b173538c8fecca1dff298e488402cc9ff374f8a12ca7758eebe830b66"
	}
	const typus = {
		function: "deposit",
		module: "tails_staking",
		package: "0x1ee07392805d5b26a1c248b5739b768d426579ac1f4aeb50152f7ca06d3e2a00"
	}
	const buck = {
		function: "borrow",
		module: "buck",
		package: "0x2545d6a3da56cfd79a0394710f42d038baf87bcf6cfd7f5bb14906dcd7f4e8b3"
	}

	console.log("querying all txs...")

	let hasNextPage = true;
	let nextCursor = null;
	let allTxs: SuiTransactionBlockResponse[] = [];
	
	let page = 0;
	while (hasNextPage && page < 1000) {
		const txs = await client.queryTransactionBlocks({
			cursor: nextCursor,
			filter: { 
				MoveFunction: buck
			},
			options: {
				// showEffects: true,
				// showObjectChanges: true,
				showInput: true,
				// showEvents: true,
			}
		})
		console.log(page);

		allTxs.push(...txs.data);
		hasNextPage = txs.hasNextPage;
		nextCursor = txs.nextCursor;
		page++;
	}
    
	// const filteredTxs = allTxs.filter(tx => 
	// 	tx.transaction?.data.transaction.kind === 'ProgrammableTransaction' && 
	// 	tx.transaction?.data.transaction.inputs[5].type === 'pure' &&
	// 	Number(tx.transaction?.data.transaction.inputs[5].value) > 1000000000000
	// );

	const senders = allTxs
		.map((tx) => tx.transaction?.data.sender)
		.filter((item, index, self) => self.indexOf(item) === index);

	fs.writeFileSync(`./src/airdrop-utils/buck1-providers.json`, JSON.stringify(senders, null, 2));

	// if (senders) {
	// 	const currentList = fs.readFileSync('./src/airdrop-utils/airdrop_list.json', 'utf8');
	// 	const parsedList = JSON.parse(currentList);
	// 	parsedList.push(...senders);
	// 	const uniqueList = [...new Set(parsedList)];
	// 	const newList = JSON.stringify(uniqueList, null, 2);
	// 	fs.writeFileSync('./src/airdrop-utils/airdrop_list.json', newList, 'utf8');
	// }
})()