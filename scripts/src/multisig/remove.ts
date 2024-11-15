import { Transaction } from '@mysten/sui/transactions';
import { client, keypair, getId } from '../utils.js';


(async () => {
	
	// if the address approved a proposal it can be undone this way

	try {
		console.log("calling...")

		const tx = new Transaction();

		const packageId = getId("package_id");

		tx.moveCall({
			target: `${packageId}::multisig::remove_approval`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure.string("add_members_increase_threshold")
			]
		});

		tx.setGasBudget(10000000);

		const result = await client.signAndExecuteTransaction({
			signer: keypair,
			transaction: tx,
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