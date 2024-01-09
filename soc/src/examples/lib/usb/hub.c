// Handle hub functions
// 1. When a hub connects, create a new task for each port
// 2. Monitor hub interupt endpoint for status changes (notably port disconnect events)
//

#include "usb_sys.h"
#include "usb.h"

#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

uint32_t now_ms(void);

#pragma pack(push, 1)
struct hub_desc {
  uint8_t  bLength;
  uint8_t  bDescriptorType;
  uint8_t  bNbrPorts;
  uint8_t  wHubCharacteristicsL;
  uint8_t  wHubCharacteristicsH;
  uint8_t  bPwrOn2PwrGood;
  uint8_t  bHubContrCurrent;
  uint8_t  DeviceRemovable;
  uint8_t  PortPwrCtrlMask;
};
typedef struct hub_desc HUBDESC;
#pragma pack(pop)

#define HUB_ID       0x29
#define POWER        0x08
#define RESET        0x04
#define ENABLE       0x01

// Port status word bits
#define HAS_POWER   0x00000100
#define CONNECTED   0x00000001
#define ENABLED     0x00000002
#define HAS_RESET   0x00100000
#define IS_LS_DEV   0x00000200

enum hub_state {
    hub_init, build_ports, get_status, act_status, do_next, cmd_wait, hub_wait
};

struct hub_data {
    uint32_t status;
    uint8_t  nports;
    uint8_t  idx;
    TASK    *port[8];
};

#define cnfg ((struct hub_data *)task->data)

// Driver for the hub itself
//
void drv_hub(TASK *task, uint8_t *data)
{
    HUBDESC *hub_desc;
    TASK    *port;
    static TASK *lock = NULL;
    uint32_t status, idx, i;
    
    switch (task->state) {
    
    // It seems hubs do not include the hub descriptor in the full configuration. Fetch it now,
    // re-using the config buffer for hub descriptor.
    //
    case hub_init:
        printf("hub connected\n");
        setup_req(task, (SU_IN|SU_CLS|SU_DEV), GET_DESC, HUB_ID<<8, 0, sizeof(HUBDESC));
        task->setup.pData = data;
        task->state = build_ports;
        return;
        
    case build_ports:
        if (task->req->resp != REQ_OK) break;
        printf("GET HUB DESC ok\n");

        hub_desc = (struct hub_desc *)task->setup.pData;
        task->data   = malloc(sizeof(struct hub_data));
        cnfg->nports = hub_desc->bNbrPorts;
        for(i=1; i <= cnfg->nports; i++) {
            port = new_task();
            port->prt_flags = HUB_PORT;
            cnfg->port[i] = port;
        }
        task->state = get_status;
        cnfg->idx = 1;

        
        return;
    
    // Hub event loop: for each port in turn, check status and act accordingly
    //
    case get_status:
        setup_req(task, (SU_IN|SU_CLS|SU_OTHER), GET_STAT, 0, cnfg->idx, 4);
        task->setup.pData = (uint8_t *)&(cnfg->status);
        task->state = act_status;
        return;
        
    case act_status:
        if (task->req->resp != REQ_OK) break;
        
        // release reset lock if possible (port has received address or stalled)
        if (lock) {
            if ((lock->addr != 0) || (lock->prt_flags & PRT_STALL))
                lock = NULL;
        }
        idx    = cnfg->idx;
        port   = cnfg->port[idx];
        status = cnfg->status;
    
        // check that port is still connected to the device
        //
        if ( (((status & ENABLED) == 0) && (port->prt_flags & PRT_ENABLED)) || (port->prt_flags & PRT_STALL) ) {
            printf("port %x powered down\n", idx);
            clr_task(port);
            port->prt_flags = HUB_PORT;
            setup_req(task, (SU_OUT|SU_CLS|SU_OTHER), CLR_FEAT, POWER, idx, 0);
            task->state = cmd_wait;
            return;
        }
        
        // power up port, wait for device insertion and reset device
        //
        if ((status & HAS_POWER) == 0) {
            setup_req(task, (SU_OUT|SU_CLS|SU_OTHER), SET_FEAT, POWER, idx, 0);
            task->state = cmd_wait;
        }
        else if ((status & CONNECTED) == 0) {
            port->prt_flags |= PRT_POWER;
            task->state = do_next;
        }
        else if ((status & HAS_RESET) == 0) {
            port->prt_flags |= PRT_CONNECT;
            // only can reset if no other reset is pending, otherwise wait
            if (lock == NULL) {
                lock = port;
                setup_req(task, (SU_OUT|SU_CLS|SU_OTHER), SET_FEAT, RESET, idx, 0);
                task->state = cmd_wait;
            }
            else
                task->state = hub_wait;
        }
        else if (status & ENABLED) {
            if ((port->prt_flags & PRT_ENABLED) == 0) {
                printf("port %x connected, status = %x\n", idx, status);
                port->prt_flags |= (PRT_RESET|PRT_ENABLED);
                port->prt_speed  = (status & IS_LS_DEV) ? SPEED_MM : SPEED_FS;
                port->driver     = &enum_dev;
                port->state      = dev_init;
                port->when       = now_ms() + 100;
            }
            task->state = do_next;
        }
        else
            task->state = do_next;
        return;
    
    case do_next:
        if (++(cnfg->idx) > cnfg->nports) cnfg->idx = 1;
        task->state = hub_wait;
        return;
        
    case cmd_wait:
        if (task->req->resp != REQ_OK) break;
        //printf("SET/CLR FEAT ok\n");
        /* fall through */

    case hub_wait:
        task->when = now_ms() + 255;
        task->state = get_status;
        return;
        
    case dev_stall:
        task->when = now_ms() + 255;
        return;

    }
    printf("Hub driver step failed (%x, %x)\n", task->state, task->req->resp);
    //task->state = dev_stall;
    return;
}

// If a hub disconnects, also disconnect its attached devices
//
void free_hub_tasks(TASK *task)
{
    for(int i=1; i <= cnfg->nports; i++) {
        clr_task(cnfg->port[i]);
    }
}


