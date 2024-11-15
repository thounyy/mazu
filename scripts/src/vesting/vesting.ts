import { Transaction } from '@mysten/sui/transactions';
import { client, keypair, getId } from '../utils.js';


(async () => {
	const addresses = [
		"0xf54b6ae5ab6ce6af4a6e460bbaf6626f798478e14af102bf370c882b915cbf63",
		"0xcee1f191d654f66fe62629925673f146d73adbfc0202adaf2fcabfcd0061e7e1",
		"0xf38622ccfe15dc3c740996c4c2fde94e630b1d1933d46d07a908e935d4daf90e",
		"0x83635952ab6cf365a114fa9106e29688daef7b64859ddae98a7d93dac6cf89bd",
		"0x194f8059a1808cc35a36954605ef33b09d9b2e3ea613ca1bd11a442738418548",
		"0xdf4e89d931b85ad3874f212efb5a5ec1ea5e040fa48ce1a1ccc7bceeebdf1586",
		"0xf97e4dc932d8f0e053962e3cd30f809877a72dd0b8bbe19fd4fe059939ef011a",
		"0x1288f9e240cc76af8120cb3389c47b81096c74069a345a6e85c7ded244735e77",
		"0x50c4d6d117d536bf12827a7830e4971d55e976ccc048ca1f544989c4e3cbc774",
		"0x48cfbedaa73334ef0c8564bc22a30d149692471be2ce4ed8be52e9d88f9d5d68",
		"0x99d8669090fe87ba1654d47213e5e49997e11ae58644e7a92f8b7ee6db1f14ab",
		"0x6e2c27697a02ccd4c34cc0c234713cfef437a699288696fac04e57b9c30dcc95",
		"0x3472c0903c27c965c46c652a7572095accda465fb2a927d8fcb5ef8f9f1fa50f",
		"0x3eb73d280dd0c9b5b4921be85985ba9be16cfff3f5ef6a82faf0fed171bbfc2a",
		"0x93e977fb22df373967560256279ccdef67442d7e0269ab039781507e8eba18ea",
		"0x5ea40ba60946de1d0d3f0ae619cc12de6a5f3498d28021d895d4ef9dc94fe00a",
		"0xa9d4b70a95ed673a156a957f38808abf0d8cbf0af6fe22bbccef4f80893f42fc",
		"0x87475e2f3ceba905dd1bdc89e0a96c3a3b991e2347a1a6a59e235230a9b85078",
		"0xf87c9972e2fe30a685fd38272af940ed393d9b18b8106f90188cbb01d1946eac",
		"0x9f167e24944d83beb65ade8e2b3267212a1b06a9ae421be9ec4b4d846c2f2ed5",
		"0x3df79d6e8595a0ade9d59c80cb17cbc4efdb57de99ddafe891d7adb75cb768df",
		"0x6013f34a077b1cd8a6611e6cb1b91a7bf88271a7da8612778856fb0d0e36a32d",
		"0x503e472c0ae9719feb43c04e9323a23af92e6e964c79df8e0b88f68eba3aef5c",
		"0x9903bbe7b49e97ce25689670aedd8090df2c1eb58b7899e7475b9e692fb0d670",
		"0xdab1872980a8adc0d7e1a196659961ac538dd7c36fd1fc4c2c7c2c6a7cd3c9fc",
		"0xc469e19fff128e2e1e82e24b0cdae741513e897a27bea3a944587cd50c79603e",
		"0xb8b28fcd4cd23d688f691988e6a7e6a674c09fba41e8f7c2be9148804d86261c",
		"0xca876e740fa13532ab91456d64d4f73d91bf5c5bf2e449695f9cfb72b279efb7",
		"0xd4865a2fea35b9d48795e731d44ee290aa1d44448fdc9dbd529e8cd96113cd93",
		"0x35f80cba3a1f135c45039ecd6d06796f869607b845a8f06a96b1ee3a18a471cc",
		"0x276c8c715f172d703e6de17a97103b1379438ab887a766dff55b512c036f24db",
		"0x65771663253ba6f2eb7587b079538cfb811a843868989f90c1dfe3227c88a14b",
		"0xd2a3dbb90b593440bb62199a2e3eeb14b1e3dd85d21adc378b0812ff70c0305d",
		"0x1d2c19099ab343ea042683077c4cdc70e5ed6f7a9282f991312bf7b6b54003e1",
		"0x4ef5c190f8ef1e786873b3309c4d33cce3a988bfa636b1e85e35d41f32ecfde2",
		"0xe08027c085acdd5a358b78f56ee8ab32678c1c707341343e4d18ca69e4db9f82",
		"0x1637a9f83c62d24f4d4e299ad492e2032fa1e17bcc4086796175e72b9b8d2666",
	];
	const allocations = [
		10666666_666560000,
		666666_666660000,
		6933333_333264000,
		13333333_333200000,
		2666666_666640000,
		6666666_666600000,
		7466666_666592000,
		4479999_999955200,
		2986666_666636800,
		2239999_999977600,
		2239999_999977600,
		1493333_333318400,
		1493333_333318400,
		1045333_333322900,
		746666_666659200,
		746666_666659200,
		746666_666659200,
		746666_666659200,
		746666_666659200,
		746666_666659200,
		746666_666659200,
		746666_666659200,
		746666_666659200,
		447999_999995500,
		447999_999995500,
		447999_999995500,
		447999_999995500,
		373333_333329600,
		298666_666663700,
		298666_666663700,
		298666_666663700,
		298666_666663700,
		298666_666663700,
		298666_666663700,
		223999_999997800,
		149333_333331800,
		359999_999996400,
	];


	try {
		console.log("calling...")

		const tx = new Transaction();

		const packageId = getId("package_id");

		tx.moveCall({
			target: `${packageId}::vesting::propose`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure.string("vesting"), // proposal name / human-readable id
				tx.pure.string(""), // "team" or "private_sale"
				tx.pure.vector("u64", allocations), // vector of amounts to send
				tx.pure.vector("address", addresses) // vector of addresses to be sent to
			]
		});

		tx.moveCall({
			target: `${packageId}::multisig::approve_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure.string("vesting")
			]
		});

		const [proposal] = tx.moveCall({
			target: `${packageId}::multisig::execute_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure.string("vesting")
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

		tx.setGasBudget(1000000000);

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