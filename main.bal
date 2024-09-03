import ballerina/http;
import ballerina/io;
import ballerinax/scim;
import ballerinax/hubspot.crm.contact;

configurable string HUBSPOT_API_KEY = "HUBSPOT_API_KEY";

service /scim2 on new http:Listener(9090) {
    resource function post Users(http:Caller caller, http:Request request) returns error? {

        // Retrieve the Authorization header
        // string|error authHeader = request.getHeader("Authorization");
        // if authHeader is string {
        //     io:println("Authorization Header: " + authHeader);
        // }

        json jsonPayload = check request.getJsonPayload();
        scim:UserResource userResource = check jsonPayload.cloneWithType(scim:UserResource);

        contact:ConnectionConfig connectionConfig = {
            auth: {
                token: HUBSPOT_API_KEY
            }
        };
        contact:Client baseClient = check new contact:Client(connectionConfig);
        contact:SimplePublicObjectInput contact = {
            properties : {
                "email": userResource?.emails.first(),
                "firstname": userResource.name?.givenName,
                "lastname": userResource.name?.familyName,
                "lifecyclestage": "Subscriber"
            }      
        };

        contact:SimplePublicObject|error bEvent = baseClient->create(contact);

        // Send a response back
        http:Response res = new;
        if (bEvent is contact:SimplePublicObject) {
            res.statusCode = 200;
            io:println("Created the contact" + bEvent.toString());
            res.setPayload("Created the contact" + bEvent.toString());
        } else {
            res.statusCode = 400;
            io:println(bEvent.stackTrace());
            io:println(bEvent.message());
            res.setPayload(bEvent.message());
        }
        check caller->respond(res);
    }
}
