
## Prerequisites
- AS3 3.26 or later [installed](https://clouddocs.f5.com/products/extensions/f5-appsvcs-extension/latest/userguide/installation.html)



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

## Buffer Control Plane Traffic
In testing this use-case, we modeled several between 100 and 500 randomly-arriving agents enabling and adjusting blue-green traffic flow through control plane adjustments. We found that it was necessary to provide an external buffer to address arrival peaks in defense of control plane stability. We created a [simple example of such a buffer](https://github.com/mjmenger/as3buffer) for the purpose of this proof of concept.

## The Steps for the Blue-Green workflow
The following steps take a virtual server through a blue-green workflow.
- Create the iRule within the target partition
- Enable the iRule on the target service
- Adjust the distribution of traffic
- Adjust the default pool
- Disable the iRule on the target service

Because of the resource utilization expectations of the solution, the iRule is very streamlined, and is assumed for use with fastL4 profiles.
```tcl
when CLIENT_ACCEPTED {
    set rand [expr {[TCP::client_port] % 100}]
    if { $rand > 50 }
    {pool /Common/Shared/green }
}
```
Notice that the distribution percentage (e.g. 50 in this example) and the target pool are statically assigned. One consequence of this approach is that each virtual server will have their own instance of the iRule. The use of functions like rand() and datagroup lookups were removed in pursuit of better system resource utilization at scale.

### Create the iRule
This step is performed to create the iRule the first time
```http
POST https://serveraddress/mgmt/tm/ltm/rule
Authorization: Basic admin adminpassword 
Content-Type: application/json

{
    "name":"/{{tenant}}/{{application}}/{{service}}_bluegreen_irule",
    "apiAnonymous":"when CLIENT_ACCEPTED {\nset rand [expr {[TCP::client_port] % 100}]\nif { $rand > {{distribution}} }\n{pool {{greenpool}}}\n}"
}

```

### Enable the iRule
if there are existing iRules on the service, the existing iRules should be included in the list 
```http
PATCH https://serveraddress/mgmt/tm/ltm/virtual/~{{ tenant }}~{{ application }}~{{ service }}
Authorization: Basic admin adminpassword 
Content-Type: application/json

{
    "rules": [{{service}}_bluegreen_irule]
}
```

### Update the distribution or pool
When a change to the distribution or the green pool is desired, a new version of the iRule is deployed. 
```http
PATCH https://serveraddress/mgmt/tm/ltm/rule/~{{ tenant }}~{{ application }}~{{ service }}_bluegreen_irule
Authorization: Basic admin adminpassword 
Content-Type: application/json

{
    "apiAnonymous":"when CLIENT_ACCEPTED {\nset rand [expr {[TCP::client_port] % 100}]\nif { $rand > {{distribution}} }\n{pool {{greenpool}}}\n}"
}


```

### Update the default pool

```http
PATCH https://serveraddress/mgmt/tm/ltm/virtual/~{{ tenant }}~{{ application }}~{{ service }}
Authorization: Basic admin adminpassword 
Content-Type: application/json

{
    "pool": "/Common/Shared/green"
}
```

### Disable the iRule
When the blue-green workflow is complete and the default pool is now the new (green) pool, the iRule is removed from the service.
```http
PATCH https://serveraddress/mgmt/tm/ltm/virtual/~{{ tenant }}~{{ application }}~{{ service }}
Authorization: Basic admin adminpassword 
Content-Type: application/json

{
    "rules": []
}
```