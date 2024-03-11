import { TransactionBlock } from '@mysten/sui.js/transactions';
import { client, keypair, getId } from './utils.js';

(async () => {
	try {
		console.log("calling...")

		const tx = new TransactionBlock();

		const packageId = getId("package");

		const [coin] = tx.splitCoins(tx.object(getId(`coin::Coin<${packageId}::mazu::MAZU>`)), [10]);
		
		const [staked] = tx.moveCall({
			target: `${packageId}::staking::stake`,
			arguments: [
				tx.object(getId("staking::Staking")), 
				coin, 
				tx.object("0x0000000000000000000000000000000000000000000000000000000000000006"),
				tx.pure(0),
			],
			typeArguments: [
				`${packageId}::mazu::MAZU`
			],
		});

		tx.transferObjects([staked], keypair.getPublicKey().toSuiAddress());

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