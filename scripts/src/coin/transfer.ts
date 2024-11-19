import { Transaction } from '@mysten/sui/transactions';
import { client, keypair, getId } from '../utils.js';


(async () => {
	
	try {
		console.log("calling...")

		const tx = new Transaction();

		const packageId = getId("package_id");

		tx.moveCall({
			target: `${packageId}::mazu::propose_transfer`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure.string("transfer"), // proposal name / human-readable id
				tx.pure.string("public_sale"), // stakeholder name (Vault fields)
				tx.pure.u64(333_333_333_333_333), // amount
				tx.pure.address("0xdc2dbdf749bcf228a97339020607110baf45248ccc3e7671edd3e3c866a75717"), // recipient
			]
		});

		tx.moveCall({
			target: `${packageId}::multisig::approve_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure.string("transfer")
			]
		});

		const [proposal] = tx.moveCall({
			target: `${packageId}::multisig::execute_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure.string("transfer")
			]
		});

		const [request] = tx.moveCall({
			target: `${packageId}::mazu::start_transfer`,
			arguments: [
				tx.object(proposal)
			]
		});
		
		tx.moveCall({
			target: `${packageId}::mazu::complete_transfer`,
			arguments: [
				tx.object(getId("mazu::Vault")),
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