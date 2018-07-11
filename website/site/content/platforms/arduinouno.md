---
title: "Arduino Uno"
description: "See what you can do with the Arduino Uno: all the sensors and connectivity, examples, how it works and how the platform can be used."
weight: 40
draft: false
toc: true
menu:
  main:
    parent: Platforms
    identifier: arduinouno
    weight: 0
---

The Arduino Uno is a popular platform and is often used for the very beginning of getting in touch with embedded systems. 
Meanwhile there are a lot of projects, also in the context of IoT devices, where the Arduino Uno has been used to realize them.
Currently the Arduino Uno is supported with its basic functionalities: two buttons and GPIOs

## Sensor: button_one (Button)

#### Modalities
<table>
    <thead>
        <tr>
            <td>Name</td>
            <td>Description</td>
        </tr>
    </thead>
    <tbody>
		<tr>
			<td><div class="highlight"><pre><b>is_pressed</b> : <span class="kt">bool</span></pre></div></td>
			<td>True if the button is pressed in this very right moment. False otherwise.</td>
		</tr>
    </tbody>
</table>


#### Events
<table>
    <thead>
        <tr>
            <td>Name</td>
            <td>Description</td>
        </tr>
    </thead>
    <tbody>
		<tr>
			<td><div class="highlight"><pre><b>pressed</b></pre></div></td>
			<td>Fires after the button was pressed.</td>
		</tr>
		<tr>
			<td><div class="highlight"><pre><b>released</b></pre></div></td>
			<td>Fires after the button was released.</td>
		</tr>
    </tbody>
</table>

## Sensor: button_two (Button)


#### Modalities
<table>
    <thead>
        <tr>
            <td>Name</td>
            <td>Description</td>
        </tr>
    </thead>
    <tbody>
		<tr>
			<td><div class="highlight"><pre><b>is_pressed</b> : <span class="kt">bool</span></pre></div></td>
			<td>True if the button is pressed in this very right moment. False otherwise.</td>
		</tr>
    </tbody>
</table>


#### Events
<table>
    <thead>
        <tr>
            <td>Name</td>
            <td>Description</td>
        </tr>
    </thead>
    <tbody>
		<tr>
			<td><div class="highlight"><pre><b>pressed</b></pre></div></td>
			<td>Fires after the button was pressed.</td>
		</tr>
		<tr>
			<td><div class="highlight"><pre><b>released</b></pre></div></td>
			<td>Fires after the button was released.</td>
		</tr>
    </tbody>
</table>

## Buses: GPIO
Can be used to write and read digital ports, as known from the Arduino Uno

### Signals
<table>
    <thead>
        <tr>
            <td>Name</td>
            <td>Description</td>
            <td>Parameters</td>
        </tr>
    </thead>
    <tbody>
		<tr>
			<td><div class="highlight"><pre><b>pinMode</b> : <span class="kt">bool</span></pre></div></td>
			<td></td>
			<td>
				<ul>
				<li>
					<div class="highlight"><pre> <b>pin</b> : <span class="kt">LedColor</span></pre></div>
				</li>
				</ul>
			</td>
		</tr>
    </tbody>
</table>

##Example 

This example uses the first button connected to the hardware Pin 1 and two leds connected to pin 12 and 13. 
The yellow led can get turned off by pressing the button one and turned off again by pressing the button again. 
The red led will get turned on for one second and then turned off for one second.

```TypeScript
package main;
import platforms.arduino.uno;

setup hmi : GPIO {
	var yellow = pinMode(p13, OUTPUT);
	var red = pinMode(p12, OUTPUT);
}

every button_one.pressed {
	if(hmi.yellow.read() == false) {
		hmi.yellow.write(true);
	} else {
		hmi.yellow.write(false);
	}
}

every 1 second {
	if(hmi.red.read() == false) {
		hmi.red.write(true);
	} else {
		hmi.red.write(false);
	}
}
```

##Interrupt controlled event loop

Instead of using an event queue, as the XDK 110 does, a control with boolean flags is implemented. 
Each event, such as timed events or the pressed and released event, are captured in their own ISR. 
Within the context of the ISR single flags will be set for each occurred event. 
The flags will be handled in an endless loop, after the initialization of the Arduino Uno.

In the example a flag will be used for the event of 1 second and the pressed event of the button_one.

```TypeScript
while(1) {
	if (getHandleEvery1Second1_flag() == true){
		setHandleEvery1Second1_flag(false);
		HandleEvery1Second1();
	}
	if (getHandleEveryButton_onePressed1_flag() == true){
		setHandleEveryButton_onePressed1_flag(false);
		HandleEveryButton_onePressed1();
    }
}
```

As mentioned before, the flags are set in the ISR:

```TypeScript
ISR(INT1_vect){
	volatile int oldState = 0;
	volatile int currentState = 0;
	oldState = (PIND & _BV(PIND3)) > 0 ? HIGH : LOW;
	// delay for debounce could be placed here
	currentState = (PIND & _BV(PIND3)) > 0 ? HIGH : LOW;
	if (LOW == oldState && LOW == currentState) {
		ButtonTwoPressed(true);
    } else if (HIGH == oldState && HIGH == currentState){
		ButtonTwoReleased(true);
	}
}
```

##How to use the Arduino Uno platform

For the very first beginning the C libraries are contained in the Mita project (/org.eclipse.mita.platform.arduino.uno/ArduinoMitaRuntime). 
There is no toolchain integration. You can copy the Arduino runtime files into your runtime workspace and use them. 
While developing the platform, the AVR Plugin (https://marketplace.eclipse.org/content/avr-eclipse-plugin) was used for compiling and flashing. 

* Create a new C Project 
* Choose an AVR project 
* Set up the atmega 328p (Arduino Uno)
* Add a new file with .mita extension
* After creating a .mita file, a wizard will be opened to convert as the project as a Xtext project. Click on Yes. You also can edit the nature in the .project file.
* Add Paths & Symbols (src-gen, base and folder, which contains the ArduinoMitaRuntime files). Therefore, right click the project and open the Properties. Open C/C++ Build and open Paths & Symbols.
* Set up Programmer - can be found in the project properties under AVR
* Create your application
* Compile & flash

