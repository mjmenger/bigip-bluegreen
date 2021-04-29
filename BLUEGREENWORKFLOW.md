
## Prerequisites
- AS3 3.27 or later installed

## the steps for the workflow



### Enable Burst Handling for AS3

```http
POST https://{{$dotenv bigip1}}/mgmt/shared/appsvcs/settings
Authorization: Basic {{$dotenv user}} {{$dotenv password}} 
Content-Type: application/json

{
    "burstHandlingEnabled": true
}
```

### Verify Burst Handling

```http
GET https://{{$dotenv bigip1}}/mgmt/shared/appsvcs/settings
Authorization: Basic {{$dotenv user}} {{$dotenv password}} 
Content-Type: application/json

```

### Make additional RAM available to restjavad

```http
PATCH https://{{$dotenv bigip1}}/mgmt/tm/sys/db/provision.extramb
Authorization: Basic {{$dotenv user}} {{$dotenv password}} 
Content-Type: application/json

{
    "value": "1000"
}
```
followed by  
```http
PATCH https://{{$dotenv bigip1}}/mgmt/tm/sys/db/restjavad.useextramb
Authorization: Basic {{$dotenv user}} {{$dotenv password}} 
Content-Type: application/json

{
    "value": true
}
```
followed by  
Note: this call will result in a 502 error because we're restarting the backend of the iControlREST endpoint.
```http
POST https://{{$dotenv bigip1}}/mgmt/tm/sys/service
Authorization: Basic {{$dotenv user}} {{$dotenv password}} 
Content-Type: application/json

{
    "command": "restart",
    "name": "restjavad"
}
```
You'll want to wait for the restjavad process to 

### Create / Replace the iRule
This step is performed every time the distribution and the target greenpool change
```http
POST https://{{$dotenv bigip1}}/mgmt/tm/ltm/rule
Authorization: Basic {{$dotenv user}} {{$dotenv password}} 
Content-Type: application/json

{
    "name":"/{{tenant}}/{{application}}/{{tenant}}_bluegreen_irule",
    "apiAnonymous":"when CLIENT_ACCEPTED {\nset rand [expr {[TCP::client_port] % 100}]\nif { $rand > {{distribution}} }\n{pool {{greenpool}}}\n}"
}

```

### Enable the iRule
if there are existing iRules on the service, the existing iRules should be included in the list 
```http
PATCH https://{{$dotenv bigip1}}/mgmt/tm/ltm/virtual/~{{ tenant }}~{{ application }}~{{ service }}
Authorization: Basic {{$dotenv user}} {{$dotenv password}} 
Content-Type: application/json

{
    "rules": [{{tenant}}_bluegreen_irule]
}
```

### Update the default pool

```http
PATCH https://{{$dotenv bigip1}}/mgmt/tm/ltm/virtual/~{{ tenant }}~{{ application }}~{{ service }}
Authorization: Basic {{$dotenv user}} {{$dotenv password}} 
Content-Type: application/json

{
    "pool": "/Common/Shared/blue"
}
```

