import ballerina/http;
import ballerina/io;
import ballerinax/hubspot.crm.contact;
import ballerinax/scim;
import ballerina/lang.array;
import ballerina/regex;

configurable string HUBSPOT_API_KEY = "HUBSPOT_API_KEY";
configurable string USERNAME = "admin";
configurable string PASSWORD = "admin";

function checkAuth(string authHeader) returns error? {

    if authHeader.startsWith("Basic ") {
        string encodedCredentials = authHeader.substring(6);
        string decodedCredentials = check string:fromBytes(check array:fromBase64(encodedCredentials));
        string[] credentials = regex:split(decodedCredentials,":");

        if credentials.length() == 2 {
            string username = credentials[0];
            string password = credentials[1];

            // Check username and password
            if (USERNAME == username && PASSWORD == password) {
                return;
            } else {
                return error("Invalid credentials");
            }
        } else {
            return error("Invalid credentials format.");
        }
    } else {
        return error("Authorization header must be Basic.");
    }
}

service /scim2 on new http:Listener(9090) {
    resource function post Users(@http:Payload scim:UserResource userResource, @http:Header string authorization, http:Caller caller) returns error? {

        error|null authError = check checkAuth(authorization);
        if (authError is error) {
            return authError;
        }

        string[] emails = userResource?.emails ?: [];

        contact:ConnectionConfig connectionConfig = {
            auth: {
                token: HUBSPOT_API_KEY
            }
        };
        contact:SimplePublicObjectInput contact = {
            properties: {
                "email": emails.pop(),
                "firstname": userResource.name?.givenName,
                "lastname": userResource.name?.familyName,
                "lifecyclestage": "subscriber"
            }
        };
        contact:Client baseClient = check new contact:Client(connectionConfig);

        contact:SimplePublicObject|error bEvent = baseClient->create(contact);

        if (bEvent is contact:SimplePublicObject) {
            io:println("Created the contact" + bEvent.toString());
            http:Response res = new;
            res.setJsonPayload(userResource.toJson());
            res.statusCode = 201;
            _ = check caller->respond(res);
        } else {
            io:println(bEvent.message());
            return error(bEvent.message());
        }
    }
}
