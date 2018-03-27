---
title: "Events"
description: "The definite reference of the Mita language; all its keywords, constructs and tricks."
weight: 35
draft: false
toc: true
menu:
  main:
    parent: Language
    identifier: events
    weight: 35
---
	
System resources and time define events. All events can be handled using the `every` keyword.

```TypeScript
every accelerometer.any_motion { }
every 60 seconds { }
```

Time comes in different resolutions:

- `milliseconds`
- `seconds`
- `minutes`
- `hours`

Most platforms can only define a limited amount of timers. Therefore the number of time event handlers is limited by that amount. 
Furthermore, since time is a limited resource, especially on embedded devices, events can be handled multiple times.
Event handlers will be executed in the order they appear in the source code.

```TypeScript
var foo = 0;
every accelerometer.any_motion { 
	foo = 1; 
}
every accelerometer.any_motion { 
	foo = 2; 
} 
```

