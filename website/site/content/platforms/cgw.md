---
title: "CGW"
description: "See what you can do with the CGW: all implemented sensors and connectivity."
weight: 40
draft: false
toc: true
menu:
  main:
    parent: Platforms
    identifier: CGW
    weight: 0
---


## Overview: The CGW

The Common GateWay is a Bosch internal development platform, equipped with BMA280, BME280, BLE, CAT-M1/NB-IoT and GPS.

### Implemented System Resources

Currently implemented sensors, connectivities and buses of the CGW platform:

Sensors | Connectivities | Buses | IO
--------|----------------|-------|-------
 | [LED]({{<ref "/platforms/cgw.md#led">}})       


## Configuration

### Startup Delay

To debug the startup process you can configure a startup delay so the CGW can connect via USB before setting up devices, connectivity, etc.:

```TypeScript
setup CGW {
  startupDelay = 5000; /* wait 5 seconds before initialization */
}
```


## Connectivities

### LED

The CGW features three custom usable LEDs in red, green and blue. On and off are encoded using `true` and `false` in Mita.

#### Modalities

Name                            | Description                           | Parameters |
--------------------------------|---------------------------------------|------------|------------
`light_up: bool`                | Represents one of the three LEDs.     | `color: LedColor`  | One of `Red`, `Green` or `Blue`.


