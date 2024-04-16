import * as fs from "fs";
import { SuiClientWithEndpoint, SuiMultiClient } from "@polymedia/suits";

(async () => {   
    const RPC_ENDPOINTS: string[] = [
        "https://fullnode.mainnet.sui.io/",
        "https://mainnet.suiet.app",
        "https://rpc-mainnet.suiscan.xyz",
        "https://sui-mainnet-ca-2.cosmostation.io",
        "https://sui-mainnet-endpoint.blockvision.org",
        "https://sui-mainnet-eu-3.cosmostation.io",
        "https://sui-mainnet-eu-4.cosmostation.io",
        // "https://sui-mainnet-rpc.bartestnet.com",
        "https://sui-mainnet-us-1.cosmostation.io",
        "https://sui-mainnet-us-2.cosmostation.io",
        "https://sui-mainnet.public.blastapi.io",
        "https://sui.publicnode.com",
    
        "https://sui-mainnet-rpc-germany.allthatnode.com",
        "https://sui-mainnet-rpc.allthatnode.com",
        "https://sui-mainnet.nodeinfra.com",                    // 429 too many requests (occasionally)
        "https://sui1mainnet-rpc.chainode.tech",                // 502 bad gateway (works now)
        // "https://mainnet.sui.rpcpool.com",                   // 403 forbidden when using VPN
        // "https://sui-mainnet-rpc-korea.allthatnode.com",     // too slow/far
    
        // "https://mainnet-rpc.sui.chainbase.online",          // 567 response
        // "https://sui-mainnet-ca-1.cosmostation.io",          // 404
        // "https://sui-rpc-mainnet.testnet-pride.com",         // 502 bad gateway
        // "https://sui-mainnet-eu-1.cosmostation.io",          // 000
        // "https://sui-mainnet-eu-2.cosmostation.io",          // 000
    ]
    try {
        const coinType = "0xbde4ba4c2e274a60ce15c1cfff9e5c42e41654ac8b6d906a57efa4bd3c29f47d::hasui::HASUI";
        const limit = 9999;
        
        /* Fetch holders */

        const urlHolders = `https://suiscan.xyz/api/sui-backend/mainnet/api/coins/${coinType}/holders?sortBy=AMOUNT&orderBy=DESC&searchStr=&page=0&size=${limit}`;
        const resp: ApiResponse = await fetch(urlHolders)
        .then((response: Response) => {
            if (!response.ok)
                throw new Error(`HTTP error: ${response.status}`);
            return response.json() as Promise<ApiResponse>;
        });

        const output = new Array<AddressAndBalance>();
        for (const holder of resp.content) {
            output.push({
                address: holder.address,
                balance: holder.amount,
            });
        }
        
        const multiClient = new SuiMultiClient(RPC_ENDPOINTS, 334);
        const fetchBalance = (client: SuiClientWithEndpoint, input: AddressAndBalance) => {
            return client.getBalance({
                owner: input.address,
                coinType: coinType,
            }).then(balance => {
                return { address: input.address, balance: balance.totalBalance };
            }).catch((error: unknown) => {
                console.error(`Error getting balance for address ${input.address} from rpc ${client.endpoint}: ${error}`);
                throw error;
            });
        };
        
        const allBalances = await multiClient.executeInBatches(output, fetchBalance);

        const balances = allBalances.filter(balance => Number(balance.balance) > 1000000);
        console.log(balances);

        fs.writeFileSync("./holders.json", JSON.stringify(balances, null, 2));
    } catch (e) { console.log(e) }
})()

type ApiResponse = {
    content: Holder[];

    first: boolean;
    last: boolean;
    totalPages: number;
    empty: boolean;
    totalElements: number;
    numberOfElements: number;

    number: number;
    size: number;
    sort: any;
    pageable: any;
};

type Holder =  {
    address: string;
    holderName: null | string;
    holderImg: null | string;
    amount: number;
    usdAmount: number;
    percentage: number;
    countObjects: number;
    coinType: string;
    denom: string;
};

type AddressAndBalance = {
    address: string;
    balance: number; // TODO use bigint
};