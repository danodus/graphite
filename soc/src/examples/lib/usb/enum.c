// Enumerate the (newly connected) device
//

#include "usb_sys.h"
#include "usb.h"

#include <stdio.h>

uint32_t now_ms(void);

DEV_DESC dev_desc;
uint8_t  buffer[256];

void prn_dev_desc(uint8_t *data);
void prn_cf_full(uint8_t *data);

void prn_all(TASK *task)
{
    prn_dev_desc((uint8_t*) &dev_desc);
    prn_cf_full((uint8_t*) buffer);
    printf("# of NAKs: %x\n", task->nak);
    printf("# of TOs:  %x\n", task->tout); 
}

void set_driver(TASK *task, uint8_t *data);

int nxt_addr = 1;

enum enum_state {
  set_addr, get_dev_desc, get_cfg_desc, set_config, get_full_config, dev_enumerated
};

void enum_dev(TASK *task, uint8_t *data)
{
    struct config_desc *desc_conf = (struct config_desc*)buffer;

    switch (task->state) {
    
    // Enumerate the device:
    // 1. set address, wait 50ms for device to set it
    // 2. get device descriptor, set EP0 size
    // 3. get config descriptor, with size of full config data
    // 4. set active configuration to 1
    // 5. fetch the full configuration data and init the right driver
    //
    case set_addr:
        task->addr = 0;
        setup_req(task, (SU_OUT|SU_STD|SU_DEV), SET_ADDRESS, nxt_addr, 0, 0);
        task->when = now_ms() + 50;
        task->state = get_dev_desc;
        return;
        
    case get_dev_desc:
        if (task->req->resp != REQ_OK) break;
        task->addr = nxt_addr++;
        printf("SET ADDR ok\n");

        setup_req(task, (SU_IN|SU_STD|SU_DEV), GET_DESC, DEV_ID<<8, 0, sizeof(DEV_DESC));
        task->setup.pData = (uint8_t *) &dev_desc;
        task->state = get_cfg_desc;
        return;
    
    case get_cfg_desc:
        if (task->req->resp != REQ_OK) break;
        printf("GET TASK DESC ok\n");
        
        setup_req(task, (SU_IN|SU_STD|SU_DEV), GET_DESC, CNF_ID<<8, 0, sizeof(CNF_DESC));
        task->setup.pData = buffer;
        task->state = set_config;
        return;

    case set_config:
        if (task->req->resp != REQ_OK) break;
        printf("GET CONF DESC ok, size = %d\n", ((struct config_desc*)buffer)->wTotalLength);
        
        setup_req(task, (SU_OUT|SU_STD|SU_DEV), SET_CONF, 1, 0, 0);
        task->when = now_ms() + 10; // [needed ?]
        task->state = get_full_config;
        return;

    case get_full_config:
        if (task->req->resp != REQ_OK) break;
        printf("SET CONFIG ok\n");

        if (desc_conf->wTotalLength > sizeof(buffer)) {
            printf("configuration too large\n");
            task->state = dev_stall;
            return;
        }
        setup_req(task, (SU_IN|SU_STD|SU_DEV), GET_DESC, CNF_ID<<8, 0, desc_conf->wTotalLength);
        task->setup.pData = buffer;
        task->state = dev_enumerated;
        return;

    case dev_enumerated:
        if (task->req->resp != REQ_OK) break;
        printf("GET CONF FULL ok\n");
        prn_all(task);
        set_driver(task, buffer);
        task->state = dev_init;
        (*task->driver)(task, buffer);
        return;
        
    case dev_stall:
        task->when = now_ms() + 255;
        return;
    }
    printf("Enumeration %x step failed (%x)\n", task->state, task->req->resp);
    task->state = dev_stall;
    return;
}

uint8_t *config_end;

// Find a descriptor in the configuration data starting at 'data'
//
void  *find_desc(void *data, uint8_t id)
{
    ANY_DESC *dsc = data;
    
    while (data < config_end && dsc->bDescriptorType != id) {
        data = (uint8_t *)data + dsc->bLength;
        dsc  = data;
    }
    if (data == config_end) {
        return NULL;
    }
    return data;
}

void drv_unkown(TASK *task, uint8_t *data)
{
    //printf("Unkown device, port stalled\n");
    return;
}

void set_driver(TASK *task, uint8_t *data)
{
    CNF_DESC *conf = (struct config_desc *)data;
    IFC_DESC *iface;

    // set the driver based on the first interface found
    // to-do: itterate through all interaces
    config_end = data + conf->wTotalLength;
    iface = find_desc(data, IFC_ID);
    switch (iface->bInterfaceClass) {
    case 3:  task->driver = drv_hid;     break;
    case 9:  task->driver = drv_hub;     break;
    default: task->driver = drv_unkown;
    }
}
