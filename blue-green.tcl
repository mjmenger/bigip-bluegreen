when CLIENT_ACCEPTED {
    set distribution [class match -value \"distribution\" equals bluegreen_datagroup]
    set blue_pool [class match -value \"blue_pool\" equals bluegreen_datagroup]
    set green_pool [class match -value \"green_pool\" equals bluegreen_datagroup]
    set rand [expr { rand() }]
    switch {[expr $rand < $distribution? "blue":"green"]}{
        "blue" {pool $blue_pool}
        default {pool $green_pool}
    }
}