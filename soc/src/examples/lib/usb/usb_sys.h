#ifndef USB_SYS_H
#define USB_SYS_H

#include <stdint.h>

#define IN             1
#define OUT            2

// SETUP packet definition
//
struct usb_setup {
	uint8_t   bmReqTyp;
	uint8_t   bReq;
	uint16_t  wValue;
	uint16_t  wIndex;
	uint16_t  wLength;
  uint8_t  *pData;
};
typedef struct usb_setup SU;

// Request data block
//
struct req {
    struct task *task;
    uint32_t     when;

    uint8_t      ep;
    uint8_t      state;
    uint16_t     len;
    uint16_t     size;
    uint16_t     maxsz;
    uint8_t     *buf;
    uint8_t      pid;
    uint8_t      toggle;
    uint8_t      resp;
    int8_t       retry;
};
typedef struct req REQ;

enum rq_state {
  rq_idle,                           // request inactive (complete)
  rq_setup,  rq_su_data, rq_su_sts,  // setup request
  rq_in,     rq_out,                 // bulk & int requests
  rq_iso_in, rq_iso_out              // iso requests
};

// Task data block
//
typedef struct task TASK;
typedef void (driver_t)(TASK *, uint8_t *);

struct task {
    uint32_t     prt_flags;
    uint8_t      prt_speed;
    uint8_t      dummy;

    uint8_t      addr;
    uint8_t      state;
    uint32_t     when;
    uint16_t     nak;
    uint16_t     tout;
    
    driver_t    *driver;
    void        *data;
    SU           setup;
    REQ         *req;
};

enum { dev_init = 0, dev_stall = 255 };

// task flags
#define PORT_IDLE      0x000000000
#define ROOT_PORT      0x000000001
#define HUB_PORT       0x000000002
#define PRT_POWER      0x000000004
#define PRT_CONNECT    0x000000008
#define PRT_RESET      0x000000010
#define PRT_ENABLED    0x000000020
#define PRT_STALL      0x000000040

// speeds, 3 = mixed mode (LS behind hub)
#define SPEED_FS       1
#define SPEED_LS       2
#define SPEED_MM       3

// prn.c
void   prn_all(TASK *task);
// task.c
void   root_config(int speed, int enable_sof);
TASK  *clr_task(TASK *task);
TASK  *new_task(void);
// req.c
void   do_request_step(REQ *req);
void   setup_req(TASK *task, uint8_t typ, uint8_t req, uint16_t val, uint16_t idx, uint16_t len);
void   data_req(TASK *task, uint8_t ep, uint8_t dir, uint8_t *data, uint16_t len);
// enum.c
void  *find_desc(void *data, uint8_t type);
void   enum_dev(TASK *task, uint8_t *data);
// hub.c
void   drv_hub(TASK *task, uint8_t *data);
void   free_hub_tasks(TASK *task);
// hid.c
void   drv_hid(TASK *task, uint8_t *data);


#endif