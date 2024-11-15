import { Transaction } from '@mysten/sui/transactions';
import { client, keypair, getId } from '../utils.js';

(async () => {
	try {
		console.log("calling...")

		const tx = new Transaction();

		const packageId = getId("package_id");

		const [coin] = tx.splitCoins(tx.object(
			"0x483b027d97cc4117530009694452ac0a7b5339daa9cadfa9ce09d54930cb7f15"
		), [10]);
		
		const [staked] = tx.moveCall({
			target: `${packageId}::staking::stake`,
			arguments: [
				tx.object(getId("staking::Staking")), 
				coin, 
				tx.object("0x0000000000000000000000000000000000000000000000000000000000000006"),
				tx.pure.u64(0),
			],
			typeArguments: [
				`${packageId}::mazu::MAZU`
			],
		});

		tx.transferObjects([staked], keypair.getPublicKey().toSuiAddress());

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