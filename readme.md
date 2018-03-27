![Mita logo](website/site/content/logo.png)

Eclipse Mita is a new programming language for the embedded IoT.
It targets developers who are new to embedded software development, specifically those who come from a cloud background.
As developer Mita feels like a modern programming language (in the vain of TypeScript), but translates to C code which compiles to native code running directly on the embedded hardware.
Combining declarative confiuration, powerful language features with code generation enables projects to scale their deployment over quantity - from the first prototype to shipping thousands of devices.

## Getting started
At the moment Mita is meant to be integrated into the development environments of device vendors.
For example, the [Bosch Cross Domain Development Kit (XDK110)](http://xdk.io) ships Mita in its workbench under the name of _XDK LIVE_.

To get an impression of how Mita looks like, check out a [short quick demo](https://www.youtube.com/watch?v=Iv68Yc3u7i4), or a talk from the [Eclipse IoT Day 2018 in Grenoble](https://gricad.univ-grenoble-alpes.fr/video/eclipse-pax-new-programming-language-embedded-iot).

## Using Mita
Please take a look at the Mita documentation which provides examples, a getting started guide and a language reference.

## Extending Mita
There are two ways you can extend Mita:

1. _Provide or extend a Mita platform_: to run Mita on a particular device, we need a `platform` which describes this device. For details of how to build such a platform, check out _platform integrator guide_.
2. _Extend the core language itself_: Mita is a programming langauge in its infancy. If you want to help build it, please find and file bug reports, or better yet provide a PR to fix it.

## Get in Touch
Please check out the [Eclipse Mita project home page](https://www.eclipse.org/mita) for details regarding our mailing list.
