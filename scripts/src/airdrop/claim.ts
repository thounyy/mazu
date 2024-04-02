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
				tx.object("0x9111d3d896fc8652547b9ecf53ce0dfb7e4486436a7bc7ab9d4fc8e60cf7d0c5"), 
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