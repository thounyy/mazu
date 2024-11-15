import { Transaction } from '@mysten/sui/transactions';
import { client, keypair, getId } from '../utils.js';


(async () => {
	
	try {
		console.log("calling...")

		const tx = new Transaction();

		const packageId = getId("package_id");

		tx.moveCall({
			target: `${packageId}::mazu::propose_update_metadata`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure.string("metadata"), // proposal name / human-readable id
				tx.pure.string("New name"),
				tx.pure.string("New symbol"),
				tx.pure.string("New description"),
				tx.pure.string("New icon url"),
			]
		});

		tx.moveCall({
			target: `${packageId}::multisig::approve_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure.string("metadata")
			]
		});

		const [proposal] = tx.moveCall({
			target: `${packageId}::multisig::execute_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure.string("metadata")
			]
		});

		const [request] = tx.moveCall({
			target: `${packageId}::mazu::start_update_metadata`,
			arguments: [
				tx.object(proposal)
			]
		});
		
		tx.moveCall({
			target: `${packageId}::mazu::complete_update_metadata`,
			arguments: [
				tx.object(getId("mazu::Vault")),
				tx.object(getId("coin::CoinMetadata")),
				tx.object(request)
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