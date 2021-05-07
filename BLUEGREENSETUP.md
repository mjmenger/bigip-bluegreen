## Prerequisites
- iControlREST 
- TMOS 15.1+


## BIG-IP initial configuration
The following steps could also be performed with F5 [Declarative Onboarding](https://clouddocs.f5.com/products/extensions/f5-declarative-onboarding/latest/) (DO). For now that declaration is left as an exercise for the reader.

### Enable Burst Handling for AS3
Because of the potential for occasional peaks of automated control plane traffic, it is necessary to enable [burst handling](https://clouddocs.f5.com/products/extensions/f5-appsvcs-extension/latest/userguide/burst-handling.html) on the BIG-IP. 
```http
POST https://serveraddress/mgmt/shared/appsvcs/settings
Authorization: Basic admin adminpassword 
Content-Type: application/json

{
    "burstHandlingEnabled": true
}
```

### Verify Burst Handling
In addition to the receipt of a 200 response code from the previous step, the burst handling configuration setting can be verified with the follow REST call.
```http
GET https://serveraddress/mgmt/shared/appsvcs/settings
Authorization: Basic admin adminpassword 
Content-Type: application/json

```

### Make additional RAM available to restjavad
Because of the volume and occasional complexity of control plane traffic of this use-case, it is necessary to [provide additional memory to the restjavad process](https://clouddocs.f5.com/products/extensions/f5-appsvcs-extension/latest/userguide/best-practices.html#increase-the-restjavad-memory-allocation). If you already have this value set to a larger value than 1000, do not adjust it downward.
```http
PATCH https://serveraddress/mgmt/tm/sys/db/provision.extramb
Authorization: Basic admin adminpassword 
Content-Type: application/json

{
    "value": "1000"
}
```
followed by to direct restjavad to use the memory allocation  
```http
PATCH https://serveraddress/mgmt/tm/sys/db/restjavad.useextramb
Authorization: Basic admin adminpassword 
Content-Type: application/json

{
    "value": true
}
```
and finally request a restart of the restjavad process to enable the consequences of the previous two steps.  
Note: this call will result in a 502 error because we're restarting the backend of the iControlREST endpoint.
```http
POST https://serveraddress/mgmt/tm/sys/service
Authorization: Basic admin adminpassword 
Content-Type: application/json

{
    "command": "restart",
    "name": "restjavad"
}
```
You'll want to wait for the restjavad process to return to operation, likely between 15 and 30 seconds.