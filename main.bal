import ballerina/http;
import ballerina/io;
import ballerinax/scim;

service /scim2 on new http:Listener(9090) {
    resource function post Users(http:Caller caller, UserResource userResource) returns error? {

        // Log the payload
        io:println(userResource.toJsonString());

        // Send a response back
        check caller->respond("Payload received successfully");
    }
}

public type UserResource record {
    string[]|string schemas;
    record {
        string givenName?;
        string familyName;
    } name;
    string userName?;
    json[]|string emails?;
    scim:SCIMEnterpriseUser urn\:ietf\:params\:scim\:schemas\:extension\:enterprise\:2\.0\:User?;
    scim:Role[] roles?;
    string id?;
};