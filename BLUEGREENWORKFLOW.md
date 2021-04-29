


## Buffer Control Plane Traffic
In testing this use-case, we modeled between 100 and 500 randomly-arriving agents enabling and adjusting blue-green traffic flow through control plane adjustments. We found that it was necessary to provide an external buffer to address arrival peaks in defense of control plane stability. We created a [simple example of such a buffer](https://github.com/mjmenger/as3buffer) for the purpose of this proof of concept.

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

### Disable and Remove the iRule
When the blue-green workflow is complete and the default pool is now the new (green) pool, the iRule is removed from the service.  
Note: if there are additional iRules on the service beyond the blue-green iRule, it will be necessary to parse the existing list, remove the blue-green iRule, and PATCH the list without it.
```http
PATCH https://serveraddress/mgmt/tm/ltm/virtual/~{{ tenant }}~{{ application }}~{{ service }}
Authorization: Basic admin adminpassword 
Content-Type: application/json

{
    "rules": []
}
```
 
```http
DELETE https://serveraddress/mgmt/tm/ltm/rule/~{{ tenant }}~{{ application }}~{{ service }}_bluegreen_irule
Authorization: Basic admin adminpassword 
Content-Type: application/json

```