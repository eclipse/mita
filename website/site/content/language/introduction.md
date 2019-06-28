---
title: "Introduction"
description: "The definite reference of the Mita language; all its keywords, constructs and tricks."
weight: 1
draft: false
menu:
  main:
    parent: Language
    identifier: introduction
    weight: 01
---

Mita is a programming language that is focused on making Internet-Of-Things things easier to program, especially for developers without embedded development background.
Its language design and feature-set are meant to make anyone coming from a world of Javascript, Typescript, Java, Swift or Go feel right at home.
Compared to C you do not have to care about allocating memory, strings behave naturally, as do arrays.
Featuring powerful abstractions and a model-driven system configuration approach we can often tell at compile time if something will not work.
At the core of Mita is a platform model which describes what resources (think connectivity, sensors or low-level hardware interfaces) you have to work with. 

All Mita code compiles to C code. This is a very powerful feature.
It allows developers to inspect the generated code, learn from it and when they hit that inevitable glass ceiling continue where they left off, but in C.
Further, once you leave the prototyping phase or feel that you need more control over your system, you can always fall back to the C level and go from there.

## Anatomy of an Mita program
Mita programs live in files ending with `.mita`, for example `application.mita`. Let's have a look at an example which implements a simple Bluetooth enabled shock detector:
```TypeScript
package main;

import platforms.xdk110;

setup smartphone : BLE {
    deviceName = "HelloWorld";
    var shockDetected = bool_characteristic(UUID=0xCAFE);
}

every accelerometer.activity {
    if(accelerometer.magnitude.read() > 5000) {
        smartphone.shockDetected.write(true);
    }
}
```

Now let's go over this code and understand it bit by bit.

```TypeScript
package main;
```
All Mita code has a package associated with it, which means that the first line of any `.x` file is always a _package_ statement which tells the compiler to which package the subsequent code belongs to.
There is no fixed naming that you would need to adhere to, merely conventions. For example, the main application logic is typically located in a package named _main_. More details about packages can be found in the [language section].

```TypeScript
import platforms.xdk110;
```
Much like packages are defined, they need to be imported so that they can be used. This import is a special one, and the only import that every `.x` file needs to have. It imports the platform for which we are writing our program.
By convention platforms are located in the _platforms_ package. 

```TypeScript
setup smartphone : BLE {
    ...
}
```
Setup blocks configure the resources we have at our disposal, in this case a Bluetooth Low Energy connectivity. Which resources exist depends on the platform you have previously imported - not every hardware has the same radio or sensors installed, for example. The content of the setup block depends on the resource being set up. Whenever you are inside a setup block, you can use auto-complete (`Ctrl+Space`)
to find out what you can configure or do next.

```TypeScript
every accelerometer.activity {
    ...
}
```
Most of their time IoT devices spend sleeping in some low-power mode. Every now and then, triggered by time or some external event, they wake up do some sensing, computation and send data using wireless connectivity.
Mita is an event based language which maps nicely to the way such IoT devices work. Using the _every_ keyword we can react to events or time. Instead of `every accelerometer.activity { ... }` we could also write `every 100 milliseconds { ... }` which would simply execute every 100 milliseconds.  

```TypeScript
if(accelerometer.magnitude.read() > 5000) {
    ...
}
```
Sensor data and other resources providing data at runtime (we call them _modalities_) can be read at any time. We did not have to set up the accelerometer, the platform told the compiler that such a sensor exists and has a magnitude that can be read. Should you want to change the default values of the accelerometer after all, you can always use a `setup accelerometer { ... }` block to do that. 

```TypeScript
smartphone.shockDetected.write(true);
```
Earlier in the setup block for the Bluetooth Low Energy resource we configured a [BLE GATT characteristic](https://en.wikipedia.org/wiki/Bluetooth_Low_Energy#Software_model), which we named `shockDetected`. To send out data using Bluetooth all we need to do is to write to this characteristic using the built-in `write` function. All the nitty details of how to use the underlying Bluetooth stack are handled by the platform, not by you, the developer.

That concludes our first tour of an Mita program. There is a lot more to learn though. The following sections give an overview of the basic concepts, followed by more in-depth chapters of specific language elements.

