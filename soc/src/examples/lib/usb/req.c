// Build requests out of single transactions.
//

#include "usb_sys.h"
#include "usb_regs.h"
#include "usb.h"

#include <stdio.h>

extern uint32_t *usbh;
uint32_t now_ms(void);
void wait_ms(uint32_t ms);

static int out_txn(REQ *req, int want_hs)
{
    //printf("out_txn()\n");
    uint32_t i, token, len;
    uint8_t *tx = req->buf;

    // prepare transfer: set packet size, load fifo
    len = req->size = (req->len > req->maxsz) ? req->maxsz : req->len;
    for (i=0; i < len; i++) {
        usbh[REG_DATA] = *tx++;
    }
    usbh[REG_TXLEN] = len;

    // set up SIE and schedule new transfer
    token = (req->pid << 16) | ((req->task->addr & 0x3ff) << 9) | ((req->ep & 0xf) << 5);
    if (want_hs)    token |= TKN_HS;
    if (req->toggle) token |= TKN_DATA1;
    usbh[REG_TOKEN] = (token | TKN_START);

    // wait for request acceptance (start bit auto-resets)
    //printf("wait for request acceptance...\n");
    while (usbh[REG_TOKEN] & TKN_START) {
        wait_ms(1);
    }

    // no handshake expected -> done
    if (!want_hs) return REQ_OK;

    // wait for transaction to finish (i.e. SIE returns to idle)
    //printf("wait for transaction to finish...\n");
    while (!(usbh[REG_RXSTS] & SIE_IDLE)) {
        wait_ms(1);
    }

    // did handshake time out? -> error
    if (usbh[REG_RXSTS] & RX_TIMEOUT) {
        req->resp = REQ_TIMEOUT;
        return REQ_ERR;
    }

    req->resp = (usbh[REG_RXSTS] >> 16) & 0xff;
    return (req->resp == PID_ACK) ? REQ_OK : REQ_ERR;
}

static int in_txn(REQ *req, int want_hs)
{
    //printf("in_txn()\n");
    uint32_t i, token, len;
    uint8_t *rx = req->buf;
    
    // No tx data
	usbh[REG_TXLEN] = 0;

    // set up SIE and request transfer
    token = (PID_IN << 16) | ((req->task->addr & 0x3ff) << 9) | ((req->ep & 0xf) << 5);
    if (want_hs)    token |= TKN_HS;
    if (req->toggle) token |= TKN_DATA1;
    usbh[REG_TOKEN] = token | TKN_START | TKN_IN;
    // wait for request acceptance and for txn finish
    //printf("wait for request acceptance and for txn finish...\n");
    while (  usbh[REG_TOKEN] & TKN_START) {
        wait_ms(1);
    }
    while (!(usbh[REG_RXSTS] & SIE_IDLE)) {
        wait_ms(1);
    }

    // did response time out? -> report
    if (usbh[REG_RXSTS] & RX_TIMEOUT) {
       req->resp = REQ_TIMEOUT;
       return REQ_ERR;
    }

    // check response type, and error on anything not PID_DATAx
    req->resp = (usbh[REG_RXSTS] >> 16) & 0xff;
    if ((req->resp & 0x3) != 0x3) {
        //printf("BAD TYPE\n");
        return REQ_ERR;
    }

    // bad CRC  -> treat as if nothing received at all
    if (usbh[REG_RXSTS] & RX_CRCERR) {
       req->resp = REQ_CRC;
       printf("BAD CRC\n");
       return REQ_ERR;
    }
    
    // bad toggle? -> treat as if nothing received at all
    //if ((req->resp == PID_DATA0) ^ (req->toggle == 0)) {
    //   printf("BAD TOGGLE\n");
    //   return REQ_ERR;
    //}

    // fetch IN buf, check for buffer overflow
    req->size = usbh[REG_RXSTS] & 0xffff;
    if (req->size > req->len)
        req->size = req->len;
    for (i=0; i < req->size; i++) {
        *rx++ = usbh[REG_DATA];
    }
    return REQ_OK;
}

static int do_txn(REQ *req, int want_hs)
{
    int      speed = req->task->prt_speed;

    root_config(speed, usbh[REG_CTRL] & 0x1);
    if (req->pid == PID_IN) {
        return in_txn(req, want_hs);
    } else {
        return out_txn(req, want_hs);
    }
}

static int rq_next_state(REQ *req)
{
    int      dir = req->task->setup.bmReqTyp & SU_IN;
    uint16_t len = req->task->setup.wLength;

    switch (req->state) {
    
    case rq_setup:
        req->len = len;
        if (len) {
            req->buf = req->task->setup.pData;
            req->pid = dir ? PID_IN : PID_OUT;
            req->toggle = 1;
            return rq_su_data;
        }
        /* fall through */

    case rq_su_data:
        req->len    = 0;
        req->pid    = dir ? PID_OUT : PID_IN;
        req->toggle = 1;
        return rq_su_sts;

    default:
        return rq_idle;
    }
}

void do_request_step(REQ *req)
{
    TASK *task = req->task;

    //uart[2] = req->state;
    if (req->when > now_ms() || req->retry == 0 || req->state == rq_idle)
        return;

    switch(req->state) {

    case rq_idle:
        return;

    case rq_in:    case rq_out:
    case rq_setup: case rq_su_data: case rq_su_sts:

        // fetch data in max packet size chunks, with handshake
        while (do_txn(req, 1) == REQ_OK) {
            req->retry = 25;
            req->len -= (req->len >= req->size) ? req->size : req->len;
            req->buf += req->size;
            req->toggle = 1 - req->toggle;
            if (req->len == 0)
                req->state = rq_next_state(req);
            req->resp = REQ_OK;
            return;
        }

        // immediate stop after a STALL is received
        if (req->resp == PID_STALL) {
            req->state = rq_idle;
            return;
        }

        // otherwise, give up after retries exhausted
        if (--req->retry == 0) {
            req->state = rq_idle;
            req->resp = REQ_ERR;
            return;
        }
        
        // bad PID_DATAx sequence? -> try again
        if (req->resp == PID_DATA0 || req->resp == PID_DATA1) {
            return;
        }

        // NAK and TIMEOUT: try again in 2ms
        if (req->resp == PID_NAK || req->resp == REQ_TIMEOUT) {
            if (req->resp == PID_NAK)         task->nak++;
            if (req->resp == REQ_TIMEOUT) task->tout++;
            req->when = now_ms() + 2;
        } else
            req->state = rq_idle;
        return;

    default:
        printf("s=%x\n", req->state);
    }    
}

void setup_req(TASK *task, uint8_t typ, uint8_t req, uint16_t val, uint16_t idx, uint16_t len)
{
    REQ *rq = task->req;

    task->setup.bmReqTyp = typ;
    task->setup.bReq     = req;
    task->setup.wValue   = val;
    task->setup.wIndex   = idx;
    task->setup.wLength  = len;
    
    rq->len    = 8;
    rq->buf    = (uint8_t *)(&task->setup);
    rq->toggle = 0;
    rq->retry  = 25;
    rq->ep     = 0;
    rq->state  = rq_setup;
    rq->pid    = PID_SETUP;
}

void data_req(TASK *task, uint8_t ep, uint8_t dir, uint8_t *data, uint16_t len)
{
    REQ *rq = task->req;
    
    rq->len    = len;
    rq->buf    = data;
    rq->ep     = ep;
    rq->retry  = 1;
    rq->state  = (dir==IN) ? rq_in  : rq_out;
    rq->pid    = (dir==IN) ? PID_IN : PID_OUT;
}

