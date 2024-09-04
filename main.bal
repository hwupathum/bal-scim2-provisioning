import ballerina/http;
import ballerina/io;
import ballerinax/hubspot.crm.contact;
import ballerinax/scim;
import ballerina/lang.array;
import ballerina/regex;

configurable string HUBSPOT_API_KEY = "HUBSPOT_API_KEY";
configurable string USERNAME = "admin";
configurable string PASSWORD = "admin";

isolated function checkAuth(string authHeader) returns error? {

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

isolated function getUsername(string[] filter) returns string? {

    if filter.length() > 0 && filter[0].startsWith("userName Eq ") {
        return filter[0].substring(12);
    } else {
        return null;
    }
}

service /scim2 on new http:Listener(9090) {
    isolated resource function post Users(@http:Payload scim:UserResource userResource, @http:Header string authorization, http:Caller caller) returns error? {

        do {
	        _ = check checkAuth(authorization);
        } on fail var e {
        	http:Response response = new;
            response.statusCode = http:STATUS_UNAUTHORIZED;
            response.setJsonPayload({"message": e.message()});
            return check caller->respond(response);
        }

        contact:ConnectionConfig connectionConfig = {
            auth: {
                token: HUBSPOT_API_KEY
            }
        };

        string[] emails = userResource?.emails ?: [];
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

        http:Response response = new;
        if bEvent is contact:SimplePublicObject {
            io:println("Created the contact: " + bEvent.id);
            response.setJsonPayload(userResource.toJson());
            response.statusCode = http:STATUS_CREATED;
        } else {
            io:println("Error creating the contact: " + bEvent.message());
            response.statusCode = http:STATUS_BAD_REQUEST;
            response.setJsonPayload({"message": bEvent.message()});
        }
        return check caller->respond(response);
    }

    isolated resource function get Users(@http:Query string[] filter, @http:Header string authorization, http:Caller caller) returns error? {

        do {
	        _ = check checkAuth(authorization);
        } on fail var e {
        	http:Response response = new;
            response.statusCode = http:STATUS_UNAUTHORIZED;
            response.setJsonPayload({"message": e.message()});
            return check caller->respond(response);
        }

        contact:ConnectionConfig connectionConfig = {
            auth: {
                token: HUBSPOT_API_KEY
            }
        };

        string? userName = getUsername(filter);
        if !(userName is string) {
            http:Response response = new;
            response.statusCode = http:STATUS_UNAUTHORIZED;
            response.setJsonPayload({"message": "Invalid filter query"});
            return check caller->respond(response);
        }

        io:println("Get user: " + userName);

        contact:Client baseClient = check new contact:Client(connectionConfig);
        contact:SimplePublicObjectWithAssociations|error bEvent = check baseClient->getObjectById(userName, idProperty = "email");

        http:Response response = new;
        if bEvent is contact:SimplePublicObject {
            scim:UserResource userResource = {
                id: bEvent.id
            };
            json scimResponse = {
                "totalResults": 1,
                "startIndex": 1,
                "itemsPerPage": 1,
                "schemas": [
                    "urn:ietf:params:scim:api:messages:2.0:ListResponse"
                ],
                "Resources": [userResource.toJson()]
            };
            io:println("Got the contact: " + bEvent.id);
            response.setJsonPayload(scimResponse.toJson());
            response.statusCode = http:STATUS_OK;
        } else {
            io:println("Error creating the contact: " + bEvent.message());
            response.statusCode = http:STATUS_BAD_REQUEST;
            response.setJsonPayload({"message": bEvent.message()});
        }
        return check caller->respond(response);
    }


    resource function delete Users/[string contactId](http:Request request, @http:Header string authorization, http:Caller caller) returns error? {
        
        do {
	        _ = check checkAuth(authorization);
        } on fail var e {
        	http:Response response = new;
            response.statusCode = http:STATUS_UNAUTHORIZED;
            response.setJsonPayload({"message": e.message()});
            return check caller->respond(response);
        }

        contact:ConnectionConfig connectionConfig = {
            auth: {
                token: HUBSPOT_API_KEY
            }
        };

        io:println("Delete user: " + contactId);

        contact:Client baseClient = check new contact:Client(connectionConfig);
        http:Response response = check baseClient->archive(contactId);
        return check caller->respond(response);
    }

    resource function put Users/[string contactId](http:Request request, @http:Header string authorization, http:Caller caller) returns error? {

        do {
	        _ = check checkAuth(authorization);
        } on fail var e {
        	http:Response response = new;
            response.statusCode = http:STATUS_UNAUTHORIZED;
            response.setJsonPayload({"message": e.message()});
            return check caller->respond(response);
        }

        // Note: This is only a dummy method that does not call hubspot API.

        scim:UserResource userResource = {
            id: contactId
        };
        json scimResponse = {
            "totalResults": 1,
            "startIndex": 1,
            "itemsPerPage": 1,
            "schemas": [
                "urn:ietf:params:scim:api:messages:2.0:ListResponse"
            ],
            "Resources": [userResource.toJson()]
        };
        http:Response response = new;
        io:println("Updated the contact: " + contactId);
        response.setJsonPayload(scimResponse.toJson());
        response.statusCode = http:STATUS_OK;
    }

}
