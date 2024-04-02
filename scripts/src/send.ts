import { TransactionBlock } from '@mysten/sui.js/transactions';
import { client, keypair, getId } from './utils.js';

(async () => {
	try {
		console.log("calling...")

		const tx = new TransactionBlock();

		const [coin] = tx.splitCoins(tx.object(
			"0x84383f03d26edb2d1c59a811c0487f40c7eb18a192539692cd44d28cab19ef3f"
		), [1000000000000]);

		tx.transferObjects([coin], "0xb95877ace060f46272b7caa8926e5e0966720e6d084e2456b9b9ed9a63594ef2");

		tx.setGasBudget(10000000);

		const result = await client.signAndExecuteTransactionBlock({
			signer: keypair,
			transactionBlock: tx,
			options: {
				showObjectChanges: true,
				showEffects: true,
			},
			requestType: "WaitForLocalExecution"
		});

		console.log("result: ", JSON.stringify(result.objectChanges, null, 2));
		console.log("status: ", JSON.stringify(result.effects?.status, null, 2));

	} catch (e) {
		console.log(e)
	}
})()