# This iRule will send a percentage of traffic to the green pool
# Requirements:
#  - a data group with the name bluegreen_datagroup 

when CLIENT_ACCEPTED {
    set rand [expr [TCP::client_port] % 100]]
    set distribution [class match -value \"distribution\" equals bluegreen_datagroup]
    if { $rand > $distribution } 
        set green_pool [class match -value \"green_pool\" equals bluegreen_datagroup]
        {pool $green_pool} 
}