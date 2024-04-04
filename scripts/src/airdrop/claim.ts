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
				tx.object("0xddcccba581ec5ba81281fac61b25a33534fb4cd375cfdd0bdcee2a0fa9723eac"), 
				tx.object(getId("airdrop::Airdrop")), 
				tx.object(getId("mazu::Vault")),
			],
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