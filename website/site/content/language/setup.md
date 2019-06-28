---
title: "System Setup"
description: "The definite reference of the Mita language; all its keywords, constructs and tricks."
weight: 15
draft: false
toc: true
menu:
  main:
    parent: Language
    identifier: setup
    weight: 15
---

System resources have properties which we can configure.
For example, an accelerometer has an acceleration range, a filter bandwidth and some power modes which we can change.
If we wanted to use Bluetooth for communication we would have to set up the GATT characteristics, device name and advertising interval.
If we wanted to connect to a WLAN network, we would have to configure the network name and a preshared key.
 
## System Resource Instantiability
Some system resources (e.g. an HTTP client) can even be used multiple times, others can exist exactly once.
If you try and set up a system resource multiple times, and the resource can only be setup once, the compiler will tell you.
Let's look at the three different types of _instantiability_ that exist in Mita.

### Multiple
Software system resources (e.g. application level protocol implementations - think HTTP or MQTT) can exist multiple times,
thus you can _instantiate_ them multiple times using the `setup` keyword. Let's look at an HTTP client:
```TypeScript
package main;
import platforms.xdk110;

setup sensorBackend : HttpRestClient {
	...
}

setup controlService : HttpRestClient {
	...
}
```
The `HttpRestClient` can exist multiple times.
To identify the instance of the system resource we want to use, we have to name that instance (here, `sensorBackend` and `controlService`).
We will see in a moment what would be inside the setup blocks.

### Once
Other system resources can only be set up once, but we want to give them a name so that we can refer to them later on.
Connectivity is a prime example:
```TypeScript
package main;
import platforms.xdk110;

setup devnet : WLAN {
	...
}

setup sensorBackend : HttpRestClient {
	transport = devnet;
}
```
Here we configure the WLAN connectivity, and use it for HTTP client. For that to work we had to name the WLAN (`devnet` in this case).
However, if we were to add a second WLAN setup block (e.g. `setup production : WLAN { }` the compiler would produce an error, as there can be only one WLAN configuration (there is only one WLAN chip on the device). 

### None
Uninstantiable system resources are things built into the platform which we can only configure, but we cannot name them.
A typical example would be sensors. They are described by the platform, they can be configured, but renaming them does not make sense.
For example:
```TypeScript
package main;
import platforms.xdk110;

setup accelerometer {
	
}
```

## Configuration Items
System resources can have properties which change their behavior and generally configure how they work.
In Mita those things are called _configuration items_.
Configuration items are defined by the platform and are there for you, the developer, to fill in if you need to.
For example, a light sensor needs some time to "collect light", i.e. to measure the current light intensity.
In Mita that time becomes configurable through a _configuration item_:
```TypeScript
package main;
import platforms.xdk110;

setup light {
	integration_time = .MS_12_5;
}
```

{{< note title="Use content assist to explore your options" >}}
In every `setup` block you can always use content assist (`Ctrl + Space` on Windows and Linux, `Cmd + Space` on Mac) to explore what configuration items you have available.
Don't worry about using a "wrong value" either. Configuration items are strongly typed and the compiler is going to tell you if you request a configuration that doesn't make sense.
{{< /note >}}

## Signal Instances
Mita uses the concept of [signals and signal instances]({{< ref "/concepts/index.md" >}}) to model input and output of the device.
Each system resource defines which signals it has available, and what attributes those signals have.
To learn which signals you can use, have a look at the platform reference or use auto-complete within the `setup` block.

```TypeScript
package main;
import platforms.xdk110;

setup phone : BLE {
	var ping = bool_characteristic(UUID=0xCAFE);
}
```

The example above configures the Bluetooth Low Energy (`BLE`) system resource available on the XDK. This system resource sports - amonst others - a `bool_characteristic` signal.
We instantiate this signal and thereby create a BLE GATT characteristic with the _UUID_ ending in `0xCAFE`. So that we can reference this _signal instance_ in our code, we give it the name `ping`.

In our code we can use the signal instances to read and write from them (which in the example would send a Bluetooth notification):
```TypeScript
every 1 second {
	phone.ping.write(true);
}
```
