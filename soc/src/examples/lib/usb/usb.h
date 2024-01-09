#ifndef USB_H
#define USB_H

// (pseudo-) PID values
//
#define PID_OUT           0xe1
#define PID_IN            0x69
#define PID_SOF           0xa5
#define PID_SETUP         0x2d
#define PID_DATA0         0xc3
#define PID_DATA1         0x4b
#define PID_ACK           0xd2
#define PID_NAK           0x5a
#define PID_STALL         0x1e

#define REQ_OK            0x00
#define REQ_CRC           0x10
#define REQ_TIMEOUT       0x20
#define REQ_ERR           0x30

// SETUP type values
//
#define SU_OUT            0x00
#define SU_IN             0x80

#define SU_STD            0x00
#define SU_CLS            0x20
#define SU_VDOR           0x40

#define SU_DEV            0x00
#define SU_IFACE          0x01
#define SU_EP             0x02
#define SU_OTHER          0x03

// SETUP command values
//
#define GET_STAT          0x00
#define CLR_FEAT          0x01
#define SET_FEAT          0x03
#define SET_ADDRESS       0x05
#define GET_DESC          0x06
#define GET_CONF          0x08
#define SET_CONF          0x09

// Descriptor IDs
//
#define DEV_ID            0x01
#define CNF_ID            0x02
#define STR_ID            0x03
#define IFC_ID            0x04
#define EPT_ID            0x05

// Descriptor definitions
//
#pragma pack(push, 1)

struct dev_desc
{
  uint8_t  bLength;
  uint8_t  bDescriptorType;
  uint16_t bcdUSB;
  uint8_t  bDeviceClass;
  uint8_t  bDeviceSubClass;
  uint8_t  bDeviceProtocol;
  uint8_t  bMaxPacketSize0;
  uint16_t idVendor;
  uint16_t idProduct;
  uint16_t bcdDevice;
  uint8_t  iManufacturer;
  uint8_t  iProduct;
  uint8_t  iSerialNumber;
  uint8_t  bNumConfigurations;
};
typedef struct dev_desc DEV_DESC;

struct config_desc
{
  uint8_t  bLength;
  uint8_t  bDescriptorType;
  uint16_t wTotalLength;
  uint8_t  bNumInterfaces;
  uint8_t  bConfigurationValue;
  uint8_t  iConfiguration;
  uint8_t  bmAttributes;
  uint8_t  bMaxPower;
};
typedef struct config_desc CNF_DESC;

struct iface_desc
{
  uint8_t  bLength;
  uint8_t  bDescriptorType;
  uint8_t  bInterfaceNumber;
  uint8_t  bAlternateSetting;
  uint8_t  bNumEndpoints;
  uint8_t  bInterfaceClass;
  uint8_t  bInterfaceSubClass;
  uint8_t  bInterfaceProtocol;
  uint8_t  iInterface;
};
typedef struct iface_desc IFC_DESC;

struct ep_desc
{
  uint8_t  bLength;
  uint8_t  bDescriptorType;
  uint8_t  bEndpointAddress;
  uint8_t  bmAttributes;
  uint16_t wMaxPacketSize;
  uint8_t  bInterval;
};
typedef struct ep_desc EPT_DESC;

struct any_desc
{
  uint8_t bLength;
  uint8_t bDescriptorType;
};
typedef struct any_desc ANY_DESC;

#pragma pack(pop)

#endif
