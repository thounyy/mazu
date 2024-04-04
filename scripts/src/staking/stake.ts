import { TransactionBlock } from '@mysten/sui.js/transactions';
import { client, keypair, getId } from '../utils.js';

(async () => {
	try {
		console.log("calling...")

		const tx = new TransactionBlock();

		const packageId = getId("package_id");

		const [coin] = tx.splitCoins(tx.object(
			"0xb1e548c96820dc6dbe7422f7ed934a01da0c700d6f4e0d7f5f6810bd396f7b96"
		), [10]);
		
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