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
				tx.object("0xad73d1a442a1a12d4dc58eeb796d135a7d400eb55b4ab5dad8073b4e3ec5af2b"), 
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