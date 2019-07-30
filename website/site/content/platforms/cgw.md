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

The Common GateWay (CGW) is a Bosch internal development platform, equipped with BMA280, BME280, BLE, CAT-M1/NB-IoT and GPS.

### Implemented System Resources

Currently implemented sensors, connectivities and buses of the CGW platform:

Sensors | Connectivities | Buses | IO
--------|----------------|-------|-------
[Accelerometer]({{<ref "/platforms/cgw.md#accelerometer-bma280">}}) | [LED]({{<ref "/platforms/cgw.md#led">}})       
[Environment]({{<ref "/platforms/cgw.md#environment-bme280">}}) | [REST over HTTP]({{<ref "/platforms/cgw.md#rest-over-http">}})

## Configuration

### Startup Delay

To debug the startup process you can configure a startup delay so the CGW can connect via USB before setting up devices, connectivity, etc.:

```TypeScript
setup CGW {
  startupDelay = 5000; /* wait 5 seconds before initialization */
}
```

### Console Interface

Console output can be viewed either via RTT or UART. You configure this like this:

```TypeScript
setup CGW {
  consoleInterface = .UART; // or .RTT
}
```

## Connectivities

### LED

The CGW features three custom usable LEDs in red, green and blue. On and off are encoded using `true` and `false` in Mita.

#### Modalities

Name                            | Description                           | Parameters | 
--------------------------------|---------------------------------------|------------|------------
`light_up: bool`                | Represents one of the three LEDs.     | `color: LedColor`  | One of `Red`, `Green` or `Blue`.

### Radio

The Common Gateway features a u-blox mobile radio capable of both CAT-M1 and NB-IoT technologies. 

```TypeScript
setup net: Radio {
  radioStandard = .CAT_M1;
  apn = "internet.m2mportal.de";
}
```

#### Configuration

   | Name                            | Description
---|---------------------------------|------------
**Required** | `radioStandard: RadioStandard`      | Whether to use NB-IoT or CAT-M1. One of `.NB_IoT, .CAT_M1`.
**Required** | `apn: string`                       | The APN of your mobile provider.


### REST over HTTP

Using REST you can easily talk to servers over HTTP. REST defines a stateless interface with a simple URL scheme. Normally a REST server consists of a versioned endpoint like `http://api.github.com/v3` which then provides different resources, for example `api.github.com/v3/repos/eclipse/mita/branches` and `/repos/eclipse/mita/issues`.

Currently, only writing, some content types and POST method is supported.

#### Example

```TypeScript
setup net: Radio { /* ... */ }

setup backend: HttpRestClient {
  transport = net;
  endpointBase = "http://jsonplaceholder.typicode.com";

  var posts = resource("/posts");
}

every 100 milliseconds {
  backend.branches.write(`${accelerometer.magnitude.read()}`);
}
```

#### Configuration

   | Name                            | Description
---|---------------------------------|------------
**Required** |`transport: Radio`       | The transport layer used for communication.
**Required** |`endpointBase: string`  | The server URL base to which REST requests are made.

#### Signals

Name                            | Description                           | Parameters | 
--------------------------------|---------------------------------------|------------|------------
`resource: string`              | A REST resource on the server.        | `endpoint: string`  | The REST path to the resource.
 || `contentType: ContentType`  | The content type of your payload. One of `.Text, .Json, .Xml, .Octet, .WwwUrl, Multipart`. Default: `.Json`


## Sensors

### Accelerometer (BMA280)
The BMA280 is a tri axial, low-g acceleration sensor with digital output for consumer applications. It allows measurements of acceleration in three perpendicular axes.

#### Configuration
   | Name                            | Description
---|---------------------------------|------------
   | `range: BMA280_Range`           | The range of acceleration we want to measure. Default: `2G`
   | `bandwidth: BMA280_Bandwidth`   | The low-pass filter bandwidth used by the BMA. Default: `500Hz`

#### Modalities
   | Name                            | Description
---|---------------------------------|------------
   | `x_axis: int32`                 | The X axis of the BMA280.
   | `y_axis: int32`                 | The Y axis of the BMA280.
   | `z_axis: int32`                 | The Z axis of the BMA280.
   | `magnitude: int32`              | The L2 norm of the acceleration vector: `sqrt(x^2 + y^2 + z^2)`


### Environment (BME280)
The BME280 is a combined digital **humidity**, **pressure** and **temperature** sensor based on proven sensing principles.

#### Configuration

   | Name                            | Description
---|---------------------------------|------------
   | `power_mode: BME280_PowerMode`                   | The BME280 power mode. Default: `Normal`.
   | `standby_time: uint32`                           | The standby time used in normal mode in milliseconds. Beware that the value supplied here will be clipped to the nearest valid value.
   | `temperature_oversampling: BME280_Oversampling`  | Reduces noise in the temperature measurement by over sampling. Higher oversampling settings reduce noise but increase measurement time and power consumption.
   | `pressure_oversampling: BME280_Oversampling`     | Reduces noise in the pressure measurement by over sampling. Higher oversampling settings reduce noise but increase measurement time and power consumption.
   | `humidity_oversampling: BME280_Oversampling`     | Reduces noise in the humidity measurement by over sampling. Higher oversampling settings reduce noise but increase measurement time and power consumption.

#### Modalities

Name                            | Description
--------------------------------|---------------------------------------
`temperature : int32`           | The temperature reported by the BME280.
`pressure : uint32`             | The pressure reported by the BME280.
`humidity : uint32`             | The humidity reported by the BME280 in percentage.



