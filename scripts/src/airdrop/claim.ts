import { TransactionBlock } from '@mysten/sui.js/transactions';
import { client, keypair, getId } from '../utils.js';

(async () => {
	try {
		console.log("calling...")

		const tx = new TransactionBlock();

		const packageId = getId("package_id");

		const [mazu] = tx.moveCall({
			target: `${packageId}::airdrop::claim`,
			arguments: [
				tx.object("0xfa9c02c85217a3176ed422ca74e1c4457573da2634c7601b0d78493b386737d2"), 
				tx.object(getId("airdrop::Airdrop")), 
				tx.pure(getId("mazu::Vault")),
			],
			typeArguments: [],
		});

		tx.transferObjects([mazu], keypair.getPublicKey().toSuiAddress());

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