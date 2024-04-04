import { TransactionBlock } from '@mysten/sui.js/transactions';
import { client, keypair, getId } from '../utils.js';

(async () => {
	try {
		console.log("calling...")

		const tx = new TransactionBlock();

		const packageId = getId("package_id");

		const [coins, rewards] = tx.moveCall({
			target: `${packageId}::staking::unstake`,
			arguments: [
				tx.object(getId("mazu::Vault")), 
				tx.object(getId("staking::Staking")), 
				tx.object("0x6f9d38226ba98b50eb37b4d85f0bc544e6225339f1ed4a04fefb71c1bc095abd"), // the Staked object
				tx.object("0x0000000000000000000000000000000000000000000000000000000000000006"),
			],
			typeArguments: [
				`${packageId}::mazu::MAZU`
			],
		});

		tx.transferObjects([coins, rewards], keypair.getPublicKey().toSuiAddress());

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