import { TransactionBlock } from '@mysten/sui.js/transactions';
import { client, keypair, getId } from './utils.js';

(async () => {
	try {
		console.log("calling...")

		const tx = new TransactionBlock();

		const [coin] = tx.splitCoins(tx.object(
			"0x483b027d97cc4117530009694452ac0a7b5339daa9cadfa9ce09d54930cb7f15"
		), [1000]);

		const [id] = tx.moveCall({
			target: `0x2::object::id`,
			arguments: [coin],
			typeArguments: [`0x2::coin::Coin<0x2::sui::SUI>`],
		});

		console.log(id);

		// tx.transferObjects([coin], "0x1637a9f83c62d24f4d4e299ad492e2032fa1e17bcc4086796175e72b9b8d2666");
		tx.transferObjects([coin], "0xdc2dbdf749bcf228a97339020607110baf45248ccc3e7671edd3e3c866a75717");

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