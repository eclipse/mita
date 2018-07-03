#include "Timer.h"

#include "avr/interrupt.h"

Exception_T Timer_Connect(void) {
	cli();

	OCR1A = 1999;
	TCCR1B |= _BV(WGM12);
	TCCR1B |= _BV(CS11);
	sei();

	return STATUS_OK;
}


Exception_T Timer_Enable(void) {
	cli();
	TIMSK1 |= _BV(OCIE1A);
	sei();
	return STATUS_OK;
}


ISR(TIMER1_COMPA_vect) {
	#ifdef TIMED_APPLICATION
	Tick_Timer();
	#endif
}
