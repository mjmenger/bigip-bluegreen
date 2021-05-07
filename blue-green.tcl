when CLIENT_ACCEPTED {
    set rand [expr [TCP::client_port] % 100]
    if { $rand > 50 } {
        pool /Common/Shared/green
    } 
}
