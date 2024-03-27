import { TransactionBlock } from '@mysten/sui.js/transactions';
import { client, keypair, getId } from '../utils.js';

(async () => {
	try {
		console.log("calling...")

		const tx = new TransactionBlock();

		const packageId = getId("package");

		tx.moveCall({
			target: `${packageId}::staking::propose_start`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure("start")
			]
		});

		tx.moveCall({
			target: `${packageId}::multisig::approve_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure("start")
			]
		});

		const [proposal] = tx.moveCall({
			target: `${packageId}::multisig::execute_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure("start")
			]
		});

		const [request] = tx.moveCall({
			target: `${packageId}::staking::start_start`,
			arguments: [
				tx.object(proposal)
			]
		});

		tx.moveCall({
			target: `${packageId}::staking::complete_start`,
			arguments: [
				tx.object("0x0000000000000000000000000000000000000000000000000000000000000006"),
				tx.object(getId("staking::Staking")), 
				tx.object(request)
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