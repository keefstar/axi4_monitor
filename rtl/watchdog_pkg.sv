package watchdog_pkg;
/* Fault source indicies - maps each fault type to its bit postion 
in violation_notif, status_reg, enable_reg, clear_reg, rcvy_ack */
typedef enum int unsigned { 
    WRITE_FAULT = 0,
    READ_FAULT = 1
} fault_src_e;

 /* Total number of fault sources — must match NUM_SOURCES parameter */
localparam int NUM_SOURCES = 2;

endpackage