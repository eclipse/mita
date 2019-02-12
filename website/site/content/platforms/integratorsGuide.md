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
One of Mita's key features is the clean separation of core language and platform specific code.
Mita isn't written just for one particular device, instead users specify for which device they write code by importing an available platform.
This integrators guide will tell you how to write your own platform for Mita, e.g. how you can provide developers with the different concepts/devices/features specific to your platform and its resources.

## Concepts

### Platform
If you want to enable Mita on hardware that it was not available for, you need to implement a Mita platform.
In Mita a platform refers to particular device, describes its available hardware resources and integrates the software layer for that device.
Mita platforms abstract things fundamental features of an IoT software stack, for example how events, exceptions, or logging are handled, how we compile code for that platform or how time is dealt with.
They further describe _system resources_ such as communication hardware, sensors, GPIO, busses (think I2C or SPI) as and application layer protocols.

### System Resources
A platform contains a number of system resources accompanied. System resources are things like sensors and network protocols. They are the basic building blocks developers can interact with and configure in Mita.

There are different kinds of system resources: `sensor`, `connectivity`, `io` and `bus`.
These kinds are descriptive only. While you should use the kind which best fits your system ressource, that type won't make them behave any different.
The only exception is the `platform` system resource: it has a special syntax and defines which resources you actually export to the user.

System resources can be marked as non-instantiable, singletons (instantiable once) and instantiable.
If your system resource describes hardware available on the device, e.g. a sensor, this system resource can not be [instantiated](#instantiability) or only once (see below for more details).

System resources contain different things:

- `generator` and `validator` are strings specifying the fully qualified Java class names of your generators and validators.
- `sizeInferrer` specifies the fully qualified Java class name of an inferer that computes the size of things specified by your platform. You don't need to worry about this unless you build advanced signals or modalities though.
- `configuration-item`s are things a user can configure once per setup. They can be used to specify sensor ranges, WLAN credentials or backend URLs. You can also use them to express dependencies between resources: for example the XDK's MQTT resource requires a WLAN resource to be set up. You can mark configuration items as `required`.
- `event`s can be handled by the user with `every` blocks. For now they are quite simple in that they cannot be instantiated or carry a payload.
- `modality` specifies something that can be read from your resource. They can only be used with `singleton` resources.
- `signal`s are bi-directional communication channels of a system resource. THey can be instantiated multiple times in the system resource setup. They can be configured with arguments which makes them look like function calls.

#### Instantiability
There are two views on instantiability. One is how it affects users, the other is what kind of resource you are specifying.

- `singleton` resources can only be reffered to as themselves, i.e. when they are set up they don't get another name. Typical singletons are sensors, which can be configured and offer events and modalities but no signals. They do not need configuration to function and no other resources depend on them.
- `many` and `named-singleton` resources need to be set up to be used. Once set up they can be referenced by their configured name. They can offer signals but no modalities. You can only specify dependencies between _instantiable_ resources, no matter if they're `singleton` or `many`.

#### Modalities
Modalities are runtime state that can be read from a system resource: they represent the state of the resource at some point in time.
Therefore when a user reads from different modalities of a resource the resource has to guarantee that all values are from the same sample.
Mita caters to this requirement by implementing generators for different Mita expressions: modality preparations that first read and save all modality values for your resource and modality accesses which then access these stored values.

The Mita generators ensure that subsequent reads of the same modality are from different samples if the resource can provide any.
Modalities are of the type that is read from them, for example the XDK's accelerometer has a `magnitude` modality of type `uint32` since magnitudes are always positive whereas single axes are signed `int32`s.

#### Signals
Signals are "bidirectional channels to the outside world".
They are used to define HTTP REST resources, files on a SD card or LEDs.
Users can instantiate signals as often as they like, and both read and write signals.
Each signal instance is configured on its own using a function call like syntax.

Signals are of the type that is read from and written to them, for example LEDs are of type `bool` and MQTT topics of type `string`.

#### Aliases
Aliases are a special kind of system resource that can be used to specify a fixed number of instances of non-instantiable resources.
This means that you don't have to duplicate your button definition for the 10 buttons available on your device but can instead create 10 aliases.
You can also use this to rename a resource if you want to make the technical name of a sensor more accessible to your users (e.g. rename `BMA280` to `accelerometer`).

### Platform Description Language
You define your platform in a `.platform` file.
Here you describe the system resources available on your platform as well as the data structures it requires.
For a complete syntax reference consult `org.eclipse.mita.platform/src/org/eclipse/mita/platform/PlatformDSL.xtext` or existing platform definitions.

Platform files start with the namespace the defined platform lives in via a `package <ID>;` statement.

Then you can define as many system resources and types as you like.
Type definitions are the same as in standard Mita code.
System resources are specified with their kind, one of `sensor`, `connectivity`, `io` and `bus`, optionally their instantiability and their name.
Then their properties follow in brackets: `generator <string>`, optionally `validator <string>` and `sizeInferrer <string>`, and then configuration items, signals, events and modalities.

There is one special system resource you define in a platform: the platform itself.
It defines the Java module that binds your standard generators for startup, time, exceptions etc., a global validator and all system resources exported to the user.
Since it is a system resource it can have events like `startup` and configuration items like power modes or fault behaviour.
All types you define in your `.platform` file are exported.

### Generators
Generators are at the core of your platform implementation.
They are written using [Eclipse Xtend](https://www.eclipse.org/xtend/) and generate the C code.
Generators return C code as `CodeFragments` which not only hold generated code but also a list of C includes the code requires as well as some preamble that will be prepended to the generated C files.

Every platform needs to implement the following six generators: [`IPlatformEventLoopGenerator`](#event-loop-generator), [`IPlatformExceptionGenerator`](#exception-generator), [`IPlatformLoggingGenerator`](#logging-generator), [`IPlatformMakefileGenerator`](#makefile-generator), [`IPlatformStartupGenerator`](#startup-generator), and [`IPlatformTimeGenerator`](#platform-time-generator).
These generators are bound in your platform module which should extend `EmptyPlatformGeneratorModule`.

#### Event Loop Generator
The [event loop](../concepts/index.md#event-loop) is a Mita program's core driver.
All events that happen on the platform (including time) are handled sequentially by this event loop. The event loop generator is responsible implementing the event loop. There are two main patterns for this implementation:

 - _using a queue:_ if your platform supports queues, for example because your RTOS does, this is the easiest way of implementing event loops. Each time an event happens, a function pointer pointing to the handler is enqueued in the central event queue. A single event handler task continuously blocks/deques from this event queue and executes one handler after the other. The XDK110 platform implements this pattern.
 - _using even flags:_ if you do not have tasks or queues available, boolean event flags can be used. To this end your event loop generator will generate a flag (global boolean variable) for each event. When an event happens that flag is set to true. A central loop checks each flag and if that flag is set it executes the corresponding handler. Unfortunately extending this pattern to support multiple events of the same type, yet handled in sequence is not easy to implement. The Arduino platform implements this pattern.

#### Exception Generator
Unlike C Mita supports exceptions. The exception generator translates Mita exceptions to C code.
This generator defines the C type which represents exceptions on your platform, a special `NO_EXCEPTION` value, as well as runtime representations for each exception using in a Mita program.

Exceptions typically map to special return values in C. Many platforms already have provisions for such a return code mechanism.
The task of your exception generator then is is it to make use of those retcode provisions.

#### Logging Generator
Mita has platform level logging support which is primarily used to produce diagnostic output during device startup/initialization.
If your platform does not support this type of logging (e.g. because it has no wired connection or enough bandwidth), an "empty" implementation that simply swallows all debug output is perfectly legal.

#### Makefile Generator
Mita assumes that your platform uses some kind of build system, specifically Makefiles. The Makefile generator has to integrate Mita's generated code into your platform's build system.
This generator has access to all Mita code written by the user, and is passed a list of C files to compile. This comes in handy if you need to change compile-time flags according to which system resources are used.

Mita's current dependency on `make` is not dogmatic. If you require another mechanism for building applications plase file an issue/PR.

#### Startup Generator
A Mita program boots using a two-phase initialization procedure:

- In `main`, which you generate, you initialize your event system and should enqueue `Mita_initialize` and `Mita_goLive`. Since after `Mita_goLive` the system is fully running you could also inject an event like `platform.startup` here.
- `Mita_initialize` calls the setup methods of all used system resources. It uses cross links between them to calculate some order in which to do this. It is assumed that unused resources don't need to be initialized and that all startup dependencies are declared with configuration items explicitly. If you have implicit dependencies your platform generators need to handle them themselves.
- `Mita_goLive` calls the enable methods of all used system resources. After a resource has been enabled it may start to fire events. The order of enabling follows the same rules as with initialization.

The startup generator produces the glue code required to implement this mechanism on your platform.
Specifically, it generates the `main` function which serves as entrypoint into the program.
Here you initialize your event loop, enqueue at least the two neccessary functions `Mita_initialize` and `Mita_goLive`, and start the event loop (e.g. by starting the task scheduler of your RTOS).
Global variables are initialized after all resources have been enabled.

#### Time Generator
The time generator provides the most basic resource that must be available on all platforms: time. Time is set up in three phases:
- `Setup` should be used to create timers and other data structures you require globally and for each time event. Those timers must not be running yet.
- `GoLive` enables all previously set up timers,
- `Enable` needs to start all per-event timers.

#### Resource Specific Generators
Each system resource comes with its own generator.
System resources are prepared in two stages: `setup` and `enable` which correspond to the _initialize_ and _go live_ phases of the startup generator.

When you generate code for those phases you have access to some prepared information:
- `configuration` can be queried for configured values. You can either get preprocessed information like strings or integers, or the raw expressions. If the user did not configure anything you will get the default value if your platform configures one.
- `eventHandler` is a list of all handlers your system resource's events.
- The configured system resource `component` and the `setup` of the system resource.

Beyond that your generator will need to implement different methods depending to which features it offers:

- **Events:** You can configure any events a resource offers in `setup`, however events should only fire after a resource has been enabled.
Beyond that it is your responsibility to put any callbacks your event needs in a preamble of one of those stages and to inject user specified events into the event loop.
To help you with this `GeneratorUtils.getHandlerName(EventHandlerDeclaration)` provides the C name of an event handler.

- **Signals:** If the resource has signals you will need to implement `generateSignalInstanceGetter` and `generateSignalInstanceSetter` which read or write signal instances.
The Mita generator will call these methods once per signal instance so you can generate code for different configurations of different signals.
For this you can use `ModelUtils.getArgumentValue(SignalInstance sigInst, String argumentName)` to get the arguments a signal is configured with.
Beyond that you can walk the model to get things like configuration or referenced system resources.

- **Modalities:**
To generate code for modalities you need to implement `generateAccessPreparationFor` and `generateModalityAccessFor`.
The first function is called whenever all modalities of a resource should be read.
It should store these values somewhere on the stack.
The code generated in `generateModalityAccessFor` will then query these variables to produce a value to the user program.
To get a unique name for your variables you can use `GeneratorUtils.getUniqueIdentifier(ModalityAccessPreparation)`.

### Validation
Validation enables you to guide developers and find issues before flashing code to a device.
Mita itself checks for basic issues, e.g. for array access out of bounds.
Since validation is more laborious and error prone to implement that type checking you should prefer the latter over the former.

Say you want to provide WLAN as a system resource. There are different kinds of authentication to WLAN: pre-shared key or enterprise. As an initial draft you might offer three configuration items:

```
configuration-item isEnterprise: bool
configuration-item username: string
required configuration-item password: string
```

This covers both cases: the password is used as the pre-shared key unless isEnterprise is set to `true`.
However, now you have to validate that, if `isEnterprise` is `true` the user also configured `username` and should produce the same error message as default validation for required configuration items.
This is error prone and not consistent for the user since as only one of those fields was marked required.

A better approach would be to introduce a sum type that combines all three configuration items into one:
```
alt WlanAuthentication {
	  Enterprise: {username: string, password: string}
	| WithKey: {preSharedKey: string}
}

required configuration-item authentication: WlanAuthentication
```

This takes care of everything at once: passwords are no longer the same as pre-shared keys, authentication is required and both the user and type checker know that if you chose enterprise authentication you need two values, not one.

Should types not be enough to correctly validate resource setups, for example for value ranges or number of accesses, platforms can specify both a global validator as well as validators per system resource.
The first is specified in your platform resource and is called per `.mita` file whereas the second is specified per resource and called per setup of that resource.

Validators implement `IResourceValidator`, defining one method `validate`. System resource validators get each resource setup as the `context` argument.
They then can walk the model to find bad configuration or usage and provide errors, warnings and information via the `ValidationMessageAcceptor`.
No C code will be generated as long as errors are present.

## Hands On
Now that we have learned about the building blocks of platform definitions, let's put everything together and create a simple platform for the [Arduino Uno](https://en.wikipedia.org/wiki/Arduino_Uno) board.
The next sections demonstrate how to setup your working environment and walk you through the development of a new platform definition.

### Technical Setup
First of all, we need to setup our development environment.
The easiest way is to use the Eclipse Installer with our setup file.
This will automatically download an Eclipse IDE, clone the Mita repository and import all projects into your workspace.
The whole process is described in our [contribution guide](contributing.md#set-up-your-developer-workspace).

Once you have your mita development workspace running, you can create a new project in which you are going to define your platform:
- Go to _File -> New -> Project.._ and select _Plug-in Development -> Plug-in Project_.
- Click _Next >_ and specify a project name. In this example we choose _my.arduino.platform_.
- Click _Finish_.

In the new project, create a new file with the ending _.platform_, such as _myarduino.platform_. Open the file _myarduino.platform_ and insert the following code snippet:

```
package platforms.myarduino;

platform Arduino {

}
```

We will define some proper contents soon, but first of all let's make a further change to our development environment. You probably noticed that the platform file is opened as a plain text file. This is not very convenient as you will not get any content proposals or validation upon editing. To change this, there are two ways: (1) Install the latest Mita release into your development IDE or (2) start a runtime environment and import your platform project into your runtime workspace. Since at time of writing this guide there is no official Mita release yet, we will show you how to go with the second way:
- In your development IDE, click _Run -> Run Configurations.._. The _Run Configurations_ dialog will appear.
- In the _Run Configurations_ dialog, right-click on _Eclipse Application_ and select _New_.
- Give the new run configuration a name, e.g. _Mita Runtime_.
- Press _Run_.

The run configuration starts a new Eclipse instance in which all the plugins from your development workspace are installed. In this runtime instance, you can import the platform project we just created:
- On first startup, you will probably see a welcome page. Close the _Welcome_ tab.
- Go to _File -> Import.._ and select _General -> Existing Project into Workspace_. Click _Next >_.
- Click on the top right _Browse..._ button to select the project you created above. If you do not know where this project is located on your file system, go back to your development IDE, right-click on the project and select _Properties_. From the _Properties_ dialog you can copy the project location and paste it into the _Import_ dialog in your runtime IDE.
- Make sure the option _Copy projects into workspace_ is *not* enabled. In that way you can work on the same files from your development and runtime workspace.
- Click _Finish_.

Your plaform project is now imported into your runtime workspace. Open the _myarduino.platform_ file. On the first time, a dialog asking you to apply the Xtext nature will pop up. Close that dialog by pressing _Yes_. You should now see syntax highlighting. In particular, you should see an error marker on line 5, saying that the parameter _module_ is missing. Let's fix that by adding `module ""` to the platform definition:
```
package platforms.myarduino;

platform Arduino {
  module ""
}
```
Changes in your runtime workspace are also reflected in your developer workspace. This means you can switch between the two whatever fits better. Usually, it is best to write the platform definition in the runtime workspace because of the language features you get from the platform editor. However, writing code generators makes sense in the developer workspace as you will often refer to already existing Mita generators.

The next step is to register the new platform so that it can be imported in a Mita application. To register the platform create a new file _plugin.xml_ in your platform project and paste the following contribution:
```
<?xml version="1.0" encoding="UTF-8"?>
<?eclipse version="3.4"?>
<plugin>
   <extension
         point="org.eclipse.mita.library.extension.type_library">
      <Library
            description="Arduino Platform Definition"
            id="platforms.myarduino"
            name="Arduino Platform Definition"
            optional="true"
            version="1.0.0">
         <ResourceURI
               uri="platform:/plugin/my.arduino.platform/myarduino.platform">
         </ResourceURI>
      </Library>
   </extension>
</plugin>
```
This piece of XML code registers the platform defined in the _myarduino.platform_ file (see ResourceURI) under the ID `platforms.myarduino`. In case your _MANIFEST.MF_ file contains an error now, open that file, click on the error marker and select the proposed solution. Save that file. Your project should have no errors.

As XML is static, we need to restart the runtime IDE in order to load the new extension.

After a restart, your new Arduino platform should be visible by any Mita application. We can test this by creating a new Mita application:
- Create a new C project with _File -> New -> Project.. -> C/C++ -> C Project_. Name it _my.arduino.app_ and click _Finish_.
- In the new project, create a Mita application file with _File -> New -> Other.._ and select _Mita -> Mita Application File_. The _Platform_ drop-down should now contain an entry for your platform: _platforms.myarduino_. Select it and click on _Finish_. The newly created file should have the following contents:
```
package my.pkg;

import platforms.myarduino;
```
Of course, this application does not do anything yet. Please note, at this point your application file might contain an error due to missing code generator contributions. Please ignore this error for now. We will cover code generation soon.

### Writing a platform definition
Now that you have set up your development environment, let's start writing your first platform definition. As a first step, we will define that our Arduino board comes with two buttons which emit events when they get pressed or released. Please recall, a platform is a collection of system resources accompanied by type definitions. System resources can be of the kind `sensor`, `connectivity`, `io` and `bus`.

A button falls into the `sensor` category. Sensors can specify modalities and events. Modalities define the state of a sensor, they can be read out in a Mita program. In the button case, it is a boolean that defines whether the button is currently pressed or not. Events are used in Mita as triggers in `every {..}` code blocks. A button sends an event when it gets pressed, or released. Hence, our button definition looks as follows:
```
sensor Button {
	generator ""
	modality is_pressed : bool
	event pressed
	event released
}
```
Ignore the `generator` part for now. We will cover that soon.

Now that we have defined what a button is capable of, we can express that our platform consists of two of them. For this, we create an `alias` for each button and export it in the platform resource:

```
alias button_one for Button
alias button_two for Button

platform Arduino {
	module ""
	has button_one
	has button_two
}
```

Putting both parts together, our first version of the Arduino platform is defined as:
```
package platforms.myarduino;

sensor Button {
	generator ""
	modality is_pressed : bool
	event pressed
	event released
}

alias button_one for Button
alias button_two for Button

platform Arduino {
	module ""
	has button_one
	has button_two
}
```
You can test this directly by adding some code to your Mita application in _my.arduino.app/application.mita_:
```
package my.pkg;

import platforms.myarduino;

every button_one.pressed {
  println("Hello World");
}
```

### Contributing platform code generators
Code generators build the core of your platform implementation. When contributing a platform you need to provide a couple of resource-independant code generators as well as one code generator per system resource of your platform definition.

The standard code generators are bound in a platform generator module. The module is registered in the `module` part of your platform definition. To create a platform generator module, right-click on the _src_ folder in the _my.arduino.platform_ project and create a new Xtend file. Give the module a name, such as _MyArduinoPlatformGeneratorModule_ and click on _Finish_. As a starting point, define the following bindings in your module:
```
class MyArduinoPlatformGeneratorModule extends EmptyPlatformGeneratorModule {

  override bindIPlatformEventLoopGenerator() {
    MyArduinoEventLoopGenerator
  }
  override bindIPlatformExceptionGenerator() {
    MyArduinoExceptionGenerator
  }
  override bindIPlatformStartupGenerator() {
    MyArduinoStartupGenerator
  }
}
```
For this to compile you need to add the following dependencies to your _MANIFEST.MF_ file:
- org.eclipse.mita.program,
- com.google.guava,
- org.eclipse.xtext.xbase.lib,
- org.eclipse.xtend.lib,
- org.eclipse.xtend.lib.macro

Additionally, you need to create the three code generators _MyArduinoEventLoopGenerator_, _MyArduinoExceptionGenerator_ and _MyArduinoStartupGenerator_. As an initial starting point, you can copy the contents from the generators defined in the _org.eclipse.mita.platform.arduino_ plugin. Next, you need to register the module in the platform definition:
```
platform Arduino {
  module "my.arduino.platform.MyArduinoPlatformGeneratorModule"
  has button_one
  has button_two
}
```

Besides standard platform generators you need to contribute a code generator per system resource. In this example, this means you need to provide a code generator for the Arduino buttons. Resource generators are registered with the `generator` parameter in the platform definition:
```
sensor Button {
  generator "my.arduino.platform.MyArduinoButtonGenerator"
  modality is_pressed : bool
  event pressed
  event released
}
```
The detailed contents of the code generators is out of the scope of this guide. For a starting point, please refer to the code generators in the _org.eclipse.mita.platform.arduino_ plugin.

Once you have filled your code generators with something useful, you can test them easily by touching the Mita application file. Code is generated automatically on every save action into the _src-gen_ folder of the application project. Please note, you might need to restart your runtime environment to reflect all the changes in the platform definition file.
