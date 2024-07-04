import { TransactionBlock } from '@mysten/sui.js/transactions';
import { client, keypair, getId } from '../utils.js';

(async () => {
	try {
		console.log("calling...")

		const tx = new TransactionBlock();

		const packageId = getId("package_id");

		const [mazu] = tx.moveCall({
			target: `${packageId}::vesting::unlock`,
			arguments: [
				tx.object("0x76d34a8b3691b95f4a663475b4b5be17caea2909f9fbde9b3aa21d235f04232b"), // Locked object 
				tx.pure(1), // amount
			],
		});

		// if Locked object has 0 coins left after unlock call:
		// so if locked.coins.value - amount == 0 then destroy_empty

		// tx.moveCall({
		// 	target: `${packageId}::vesting::destroy_empty`,
		// 	arguments: [
		// 		tx.object("0xb2b1148d2ee50063e292551956a906764762f8e1786083dc0adaf203a6e64bda"), // Locked object 
		// 		tx.object(getId("mazu::Vault")),
		// 	]
		// })

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