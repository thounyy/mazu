import { TransactionBlock } from '@mysten/sui.js/transactions';
import { client, keypair, getId } from '../utils.js';


(async () => {
	try {
		console.log("calling...")

		const tx = new TransactionBlock();

		const packageId = getId("package_id");

		tx.moveCall({
			target: `${packageId}::vesting::propose`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure("vesting"), // proposal name / human-readable id
				tx.pure("team"), // "team" or "private_sale"
				tx.pure([10000000000000000]), // vector of amounts to send
				tx.pure([
					// "0x67fa77f2640ca7e0141648bf008e13945263efad6dc429303ad49c740e2084a9",
					"0xdc2dbdf749bcf228a97339020607110baf45248ccc3e7671edd3e3c866a75717",
				]) // vector of addresses to be sent to
			]
		});

		tx.moveCall({
			target: `${packageId}::multisig::approve_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure("vesting")
			]
		});

		const [proposal] = tx.moveCall({
			target: `${packageId}::multisig::execute_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure("vesting")
			]
		});

		const [request] = tx.moveCall({
			target: `${packageId}::vesting::start`,
			arguments: [
				tx.object(proposal)
			]
		});

		tx.moveCall({
			target: `${packageId}::vesting::new`,
			arguments: [
				tx.object(request),
				tx.object(getId("mazu::Vault")),
			]
		});

		tx.moveCall({
			target: `${packageId}::vesting::complete`,
			arguments: [
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