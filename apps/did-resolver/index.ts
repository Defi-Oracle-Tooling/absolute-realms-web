import { AzureFunction, Context, HttpRequest } from "@azure/functions";

const httpTrigger: AzureFunction = async function (context: Context, req: HttpRequest): Promise<void> {
    context.log('HTTP trigger function processed a request.');

    const responseMessage = {
        "@context": "https://www.w3.org/ns/did/v1",
        "id": "did:web:absoluterealms.world",
        "verificationMethod": [],
        "authentication": []
    };

    context.res = {
        // status: 200, /* Defaults to 200 */
        body: responseMessage
    };
};

export default httpTrigger;
