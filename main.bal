import ballerina/http;
import ballerina/io;
import ballerinax/hubspot.crm.contact;
import ballerinax/scim;
import ballerina/lang.array;
import ballerina/regex;

configurable string HUBSPOT_API_KEY = ?;
configurable string USERNAME = ?;
configurable string PASSWORD = ?;

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

isolated function getEmail(string[] filter) returns string? {

    if filter.length() > 0 && filter[0].startsWith("userName Eq ") {
        return filter[0].substring(12);
    } else {
        return null;
    }
}

isolated function getContactIdByEmail(contact:Client baseClient, string email) returns error|string {

    contact:SimplePublicObjectWithAssociations userResponse = check baseClient->getObjectById(email, idProperty = "email");
    return userResponse.id;
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

        string email = (userResource?.emails ?: []).pop();

        contact:Client baseClient = check new contact:Client(connectionConfig);
        http:Response response = new;
        do {
            if userResource.name != null {
                string contactId = check getContactIdByEmail(baseClient, email);
                contact:SimplePublicObjectInput contact = {
                    properties: {
                        "email": email,
                        "firstname": "",
                        "lastname": "",
                        "lifecyclestage": "customer"
                    }
                };
                _ = check baseClient->update(contactId, contact);
                io:println("Updated the contact: " + contactId);
            } else {
                contact:SimplePublicObjectInput contact = {
                    properties: {
                        "email": email,
                        "firstname": userResource.name?.givenName,
                        "lastname": userResource.name?.familyName,
                        "lifecyclestage": "subscriber"
                    }
                };
                _ = check baseClient->create(contact);
                io:println("Created the contact: " + email);
            }
            response.setJsonPayload(userResource.toJson());
            response.statusCode = http:STATUS_CREATED;
        } on fail var e {
            io:println("Error updating/creating the contact: " + e.message());
            response.statusCode = http:STATUS_BAD_REQUEST;
            response.setJsonPayload({"message": e.message()});
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

        string? email = getEmail(filter);
        if !(email is string) {
            http:Response response = new;
            response.statusCode = http:STATUS_UNAUTHORIZED;
            response.setJsonPayload({"message": "Invalid filter query"});
            return check caller->respond(response);
        }

        io:println("Get user: " + email);

        contact:Client baseClient = check new contact:Client(connectionConfig);
        http:Response response = new;
        do {
            string userId = check getContactIdByEmail(baseClient, email);
            scim:UserResource userResource = {
                id: userId
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
            io:println("Got the contact: " + userId);
            response.setJsonPayload(scimResponse.toJson());
            response.statusCode = http:STATUS_OK;
        } on fail var e {
            io:println("Error creating the contact: " + e.message());
            response.statusCode = http:STATUS_BAD_REQUEST;
            response.setJsonPayload({"message": e.message()});
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
