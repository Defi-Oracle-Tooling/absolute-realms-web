import { AzureFunction, Context, HttpRequest } from "@azure/functions";

const httpTrigger: AzureFunction = async function (context: Context, req: HttpRequest): Promise<void> {
    context.log('HTTP trigger function processed a request.');

    const responseMessage = {
        "@context": "https://www.w3.org/ns/did/v1",
        "id": "did:web:absoluterealms.world",
        "verificationMethod": [
            {
                "id": "did:web:absoluterealms.world#key-1",
                "type": "RsaVerificationKey2018",
                "controller": "did:web:absoluterealms.world",
                "publicKeyPem": "-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----"
            }
        ],
        "authentication": [
            "did:web:absoluterealms.world#key-1"
        ]
    };

    context.res = {
        // status: 200, /* Defaults to 200 */
        body: responseMessage
    };
};

export default httpTrigger;
