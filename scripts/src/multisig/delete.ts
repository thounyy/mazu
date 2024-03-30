import { TransactionBlock } from '@mysten/sui.js/transactions';
import { client, keypair, getId } from '../utils.js';


(async () => {
	
	// only possible if the proposal hasn't been approved by anyone yet

	try {
		console.log("calling...")

		const tx = new TransactionBlock();

		const packageId = getId("package_id");

		tx.moveCall({
			target: `${packageId}::multisig::delete_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure("add_members_increase_threshold"),
			]
		});

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