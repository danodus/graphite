#include "usb_sys.h"
#include "usb.h"

#include <stdio.h>

#ifndef NOPRINT

void prn_dev_desc(uint8_t *data)
{
    struct dev_desc *desc = (struct dev_desc *)data;
    
    printf("Device VID=%x PID=%x:\n",   desc->idVendor, desc->idProduct);
    printf("  bcdUSB=%x\n",             desc->bcdUSB);
    printf("  bDeviceClass=%x\n",       desc->bDeviceClass);
    printf("  bDeviceSubClass=%x\n",    desc->bDeviceSubClass);
    printf("  bDeviceProtocol=%x\n",    desc->bDeviceProtocol);
    printf("  bMaxPacketSize0=%d\n",    desc->bMaxPacketSize0);
    printf("  bcdDevice=%x\n",          desc->bcdDevice);
    printf("  bNumConfigurations=%d\n", desc->bNumConfigurations);
}

void prn_cf_desc(uint8_t *data)
{
    struct config_desc *desc = (struct config_desc *)data;
    
    printf("CONFIGURATION:\n");
    //printf("  bLength=%x\n",             desc->bLength);
    //printf("  bDescriptorType=%x\n",     desc->bDescriptorType);
    printf("  wTotalLength=%d\n",        desc->wTotalLength);
    printf("  bNumInterfaces=%d\n",      desc->bNumInterfaces);
    printf("  bConfigurationValue=%d\n", desc->bConfigurationValue);
    //printf("  iConfiguration=%x\n",      desc->iConfiguration);
    printf("  bmAttributes=%x\n",        desc->bmAttributes);
    printf("  bMaxPower=%d\n",           desc->bMaxPower);
}

void prn_if_desc(uint8_t *data)
{
    struct iface_desc *desc = (struct iface_desc *)data;
    printf("INTERFACE:\n");
    //printf("  bLength=%x\n",             desc->bLength);
    //printf("  bDescriptorType=%x\n",     desc->bDescriptorType);
    printf("  bInterfaceNumber=%d\n",    desc->bInterfaceNumber);
    printf("  bAlternateSetting=%d\n",   desc->bAlternateSetting);
    printf("  bNumEndpoints=%d\n",       desc->bNumEndpoints);
    printf("  bInterfaceClass=%x\n",     desc->bInterfaceClass);
    printf("  bInterfaceSubClass=%x\n",  desc->bInterfaceSubClass);
    printf("  bInterfaceProtocol=%x\n",  desc->bInterfaceProtocol);
    //printf("  iInterface=%x\n",          desc->iInterface);
}

void prn_ep_desc(uint8_t *data)
{
    struct ep_desc *desc = (struct ep_desc *)data;

    printf("ENDPOINT:\n");
    //printf("  bLength=%x\n",             desc->bLength);
    //printf("  bDescriptorType=%x\n",     desc->bDescriptorType);
    printf("  bEndpointAddress=%x\n",    desc->bEndpointAddress);
    printf("  bmAttributes=%x\n",        desc->bmAttributes);
    printf("  wMaxPacketSize=%d\n",      desc->wMaxPacketSize);
    printf("  bInterval=%d\n",           desc->bInterval);
}

void prn_unknown_desc(uint8_t *data)
{
    ANY_DESC *desc = (ANY_DESC *)data;
    printf("UNKOWN DESCRIPTOR:\n");
    printf("  bLength=%d\n",             desc->bLength);
    printf("  bDescriptorType=%x\n",     desc->bDescriptorType);
}

void prn_cf_full(uint8_t *data)
{
    CNF_DESC *desc = (CNF_DESC *)data;
    ANY_DESC *hdr  = (ANY_DESC *)data;
    uint8_t *end = data + desc->wTotalLength;
    
    do {
        switch (hdr->bDescriptorType) {
        
        case 2:  prn_cf_desc(data);     break;
        case 4:  prn_if_desc(data);     break;
        case 5:  prn_ep_desc(data);     break;
        default: prn_unknown_desc(data);
        }
        data += hdr->bLength;
        hdr = (ANY_DESC *)data;
    } while (data < end);
}

#else

void prn_dev_desc(uint8_t *data) {}
void prn_cf_full(uint8_t *data) {}

#endif
