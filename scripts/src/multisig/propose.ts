import { Transaction } from '@mysten/sui/transactions';
import { client, keypair, getId } from '../utils.js';


(async () => {
	
	// add a new proposal to the multisig

	try {
		console.log("calling...")

		const tx = new Transaction();

		const packageId = getId("package_id");

		tx.moveCall({
			target: `${packageId}::multisig::propose_modify`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure.string("add_members_increase_threshold"), // proposal name / human-readable id
				tx.pure.bool(true), // is it to add members (false if remove)
				tx.pure.u64(1), // new threshold, can be the same as before
				tx.pure.vector("address", [
					"0xb2b1148d2ee50063e292551956a906764762f8e1786083dc0adaf203a6e64bda",
					"0x244d0dd19b90b0ded063d5543b5e4b83b4e3b1ae1b8993e0f11abbd7ae77ad6b"
				]), // addresses to add or remove
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