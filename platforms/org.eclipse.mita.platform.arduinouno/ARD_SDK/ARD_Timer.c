#include "ARD_Timer.h"


Retcode_T Timer_Connect(void) {
	cli();

	TCCR1A = 0;
	TCCR1B = 0;
	TCNT1 = 0;
	OCR1A = 1999;
	TCCR1B |= (1 << WGM12);
	TCCR1B |= (1 << CS11);
	sei();

	return RETCODE_OK;
}


Retcode_T Timer_Enable(void) {
	cli();
	TIMSK1 |= (1 << OCIE1A);
	sei();
	return RETCODE_OK;
}


ISR(TIMER1_COMPA_vect) {
	Tick_Timer();
}
