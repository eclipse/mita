---
title: "Integrators Guide"
description: "Learn how to extend Mita with new platforms: How to create the required Eclipse plugins, write generators and to what rules your implementation should adhere."
weight: 10
draft: false
toc: true
menu:
  main:
    parent: Platforms
    identifier: integrators-guide
    weight: 10
---

## Introduction

What makes Mita special and powerful is the clean separation of core language and platform specific code. Mita isn't written just for one singular device, instead users specify for which device they write code by importing one available platform. This integrators guide will tell you how to write your own platform for Mita, what you need to watch out for and how you can express different things specific to your platform and its resources.

## Concepts

### System Resources

A platform is a collection of system resources accompanied by type definitions. System resources are things like sensors and network protocols. They are the basic building blocks users can setup in Mita.

There are different kinds of system resources: `sensor`, `connectivity`, `io` and `bus`. These kinds are descriptive only, i.e. you should give your system ressources their correct kind, but they won't behave different from each other. The only exception is the `platform` system resource: it has a special syntax and defines which resources you actually export to the user.

Other than their category there is another thing differentiating system resources: whether they are instantiable and how often.

System resources define multiple things:
- `generator` and `validator` are strings specifying the fully qualified Java class names of your generators and validators.
- `sizeInferrer` specifies the fully qualified Java class name of a class that infers the size of things specified by your platform. You won't need to worry about this unless you build advanced signals or modalities though.
- `configuration-item`s are things a user can configure once per setup. They can be used to specify sensor ranges, WLAN credentials or backend URLs. You can even use them to express dependencies between resources: for example the XDK's MQTT resource requires a WLAN resource to be set up.
- `event`s can be handled by the user with `every` blocks. For now they are quite simple in that they cannot be instantiated or carry a payload.
- `modality` specifies something that can be read from your resource. They can only be used with `singleton` resources.
- `signal`s are things that can be instantiated multiple times per set up system resource and can be read from and written to. They can be configured with arguments like function calls.

#### Instantiability

There are two views on instantiability. One is how it affects users, another is what kind of resource you are specifying and what it offers and needs.

- `singleton` resources are only referencible as themselves and when they are set up they won't get another name. Singletons are mostly sensors, can be configured and offer events and modalities but no signals. They don't need configuration to function and are not depended upon by other resources.
- `many` and `named-singleton` resources need to be set up to be used. Afterwards they can be referenced by their configured name. They can offer signals but no modalities. You can only specify dependencies between resources with these kinds of resources.

#### Modalities

Modalities are things that can be read from a system resource. They represent the state of the resource at some point in time. Therefore when a user reads from different modalities of a resource the resource should guarantee that all values are from the same sample. You implement this by implementing generators for different Mita expressions: modality preparations that first read and save all modality values for your resource and modality accesses which then access these stored values.

Subsequent reads of the same modality are from different samples if the resource can provide any.

Modalities are of the type that is read from them, for example the XDK's accelerometer has a `magnitude` modality of type `uint32` since magnitudes are always positive whereas single axes are signed `int32`s.

#### Signals

Signals are "channels to the outside world". They are used to define HTTP REST resources, files on a SD card or LEDs. Users can instantiate signals as much as they like and both read and write signals. Each signal instance is configured on its own via function call like arguments.

Signals are of the type that is read from and written to them, for example LEDs are of type `bool` and MQTT topics of type `string`.

#### Aliases

Aliases are a special kind of system resource that can be used to specify a fixed number of instances of not instantiable resources. This means that you don't need to duplicate your button definition for the 10 buttons available on your device but can instead create 10 aliases. You can also use this to rename a resource if you want to reflect that your accelerometer really is some specific sensor.

### Platform Description Language
You define your platform in a `.platform` file. Here you define the system resources available on your platform as well as data structures it requires. We will give a rough overview here but for complete and syntax reference consult `org.eclipse.mita.platform/src/org/eclipse/mita/platform/PlatformDSL.xtext` or existing platform definitions.

Platform files start with the namespace the defined platform lives in via a `package <ID>;` statement.

Then you may define as many system resources and types as you like. Type definitions are the same as in standard Mita code. System resources are specified with their kind, one of `sensor`, `connectivity`, `io` and `bus`, optionally their instantiability and their name. Then their properties follow in brackets: `generator <string>`, optionally `validator <string>` and `sizeInferrer <string>`, and then configuration items, signals, events and modalities.

There is one special system resource you define in a platform: the platform itself. It defines the Java module that binds your standard generators for startup, time, exceptions etc., a global validator and all system resources exported to the user. Since it is a system resource it can have events like `startup` and configuration items like power modes or fault behaviour.

All types you define in your `.platform` file are exported.

### Generators

### Validation

### Platform Initialization

### Event Loop

### Event Handlers

## Hands On

### Technical Setup

### Walkthrough Arduino Platform

### Building Blocks
