#ifndef ISABUS_H
#define ISABUS_H

typedef struct _isabus_device isabus_device;
struct _isabus_device
{
	uint16_t iobase;
	uint8_t irq;
};

#endif /* ISABUS_H */
