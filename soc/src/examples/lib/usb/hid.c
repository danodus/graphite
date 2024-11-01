// Handle HID functions
//
//

#include "usb_sys.h"
#include "usb.h"

#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>

uint32_t now_ms(void);

#define KBD          0x01
#define MSE          0x02

enum hid_state {
    hid_init, hid_mouse1, hid_mouse2, hid_keybd1, hid_keybd2, hid_idle
};

struct hid_data {
    uint8_t flags;
    uint8_t ms_ep;
    uint8_t ms_toggle;
    uint8_t ms_pkt[8];
    uint8_t kbd_ep;
    uint8_t kbd_toggle;
    uint8_t kbd_pkt[8];
};

#define local ((struct hid_data *)task->data)

// Driver for HID keyboard and mouse
//
void drv_hid(TASK *task, uint8_t *config)
{
    REQ  *req;
    IFC_DESC *iface;
    EPT_DESC *ept;
    
    switch (task->state) {
    
    // Read configuration data, find interfaces for
    // a boot keyboard (3,1,1) and/or a boot mouse (3,1,2).
    //
    case hid_init:
        printf("HID connected\n");
        
        task->data = malloc(sizeof(struct hid_data));
        while (1) {
            if ((iface = find_desc(config, IFC_ID)) == NULL)
                break;
            config = (uint8_t *)iface + iface->bLength;

            if (iface->bInterfaceClass == 3 && iface->bInterfaceSubClass == 1) {
                switch (iface->bInterfaceProtocol) {
                case KBD:   task->state   = hid_keybd1;
                            local->flags |= KBD;
                            ept = find_desc(config, EPT_ID);
                            local->kbd_ep  = ept->bEndpointAddress & 0x0f;
                            printf("std keyboard detected (%d)\n", local->kbd_ep);
                            break;

                case MSE:   task->state   = hid_mouse1;
                            local->flags |= MSE;
                            ept = find_desc(config, EPT_ID);
                            local->ms_ep  = ept->bEndpointAddress & 0x0f;
                            printf("std mouse detected (%d)\n", local->ms_ep);
                            break;

                default:    printf("HID boot device not recognised\n");
                            continue;
                }
            }
        }
        if (local->flags == 0) {
            printf("No boot HID device found\n");
            task->state = hid_idle;
        }
        return;
    // Read the keyboard and/or mouse data, alternating between the two
    // for combined devices (e.g. keyboard with a trackpad)
    //
    case hid_mouse1:
        data_req(task, local->ms_ep, IN, local->ms_pkt, 8);
        task->req->toggle =local->ms_toggle;
        task->state = hid_mouse2;
        return;
        
    case hid_mouse2:
        if (task->req->resp == PID_STALL) {
            printf("stalled\n");
            task->state = hid_idle;
            return;
        }
        task->state = (local->flags & KBD) ? hid_keybd1 : hid_mouse1;
        task->when = now_ms() + 10;
        if (task->req->resp == REQ_OK) {
            local->ms_toggle = task->req->toggle;
            printf("MOUSE: ");
            for(int i=0; i<8; i++) printf("%x ", local->ms_pkt[i]);
            printf("\n");
        }
        return;
    
    case hid_keybd1:
        data_req(task, local->kbd_ep, IN, local->kbd_pkt, 8);
        task->req->toggle =local->kbd_toggle;
        task->state = hid_keybd2;
        return;
        
    case hid_keybd2:
        if (task->req->resp == PID_STALL) {
            printf("stalled\n");
            task->state = hid_idle;
            return;
        }
        task->state = (local->flags & MSE) ? hid_mouse1 : hid_keybd1;
        task->when = now_ms() + 10;
        if (task->req->resp == REQ_OK) {
            local->kbd_toggle = task->req->toggle;
            printf("KEYBD: ");
            for(int i=0; i<8; i++) printf("%x ", local->kbd_pkt[i]);
            printf("\n");
        }
        return;

    case hid_idle:
        task->when = now_ms() + 255;
        return;

    }
    printf("HID driver step failed (%x, %x)\n", task->state, task->req->resp);
    task->state = dev_stall;
    return;
}
