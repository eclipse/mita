---
title: "Packages"
description: "The definite reference of the Mita language; all its keywords, constructs and tricks."
weight: 10
draft: false
toc: true
menu:
  main:
    parent: Language
    identifier: packages
    weight: 10
---
In Mita code is organized in packages, which serve multiple purposes:

* __Divide the namespace__: Mita programs have one global namespace per `.mita` file. Unlike Java for example, there are no means to qualify the name of an element. Packages are used to keep this namespace clean. Only things which are explicitly imported from other packages are visible in that namespace. See [Importing Packages](#importing-packages) for more details.
* __Group code__: packages are a formidable way to group code which conceptually belongs together. Where other languages have modules or classes, Mita uses packages.
* __Hide information__: in Mita visibility of functions, types and the likes is decided on a package level. There are only two levels of visibility: things are either visible outside a package or they are not. This is very similar to how NodeJS manages visibility (think `module.export`) or how Go does it (uppercase functions/structure members/types get exported). See [Hiding Information](#hiding-information-visibility) for more details. 

All Mita code belongs to a particular package. Thus, the first line in every `.mita` file is the `package` statement. The main application logic, for example, by convention is in the `main` package:
```TypeScript
package main;

...
``` 

## Naming Conventions
Just now we have seen the first naming convention: the core application logic and system setup are in the `main` package.
The platforms which we import -- each Mita program needs to import a platform -- are by convention found in the `platforms` package. 
The [XDK110 platform]({{ < ref "/platforms/xdk110.md" > }}) for example is in the `platforms.xdk110` package.

All in all you are free to name your packages however you like. The files which constitute your package content can be located wherever in the project. However, it is a good idea to replicate the logical package structure in folders. For example:
```Pre
algorithm/
 |- api.mita				package algorithm
 |- statistics.mita		package algorithm.statistics
 \- structures.mita		package algorithm.structures
main.mita				package main
```

Notice how we use a dot `.` to indicate a sub-package relationship. 
This is merely a convention and has no influence on visibility or any other implication.

## Importing Packages
Packages divide the namespace, which is the space in which the names of functions and types have to be unique. 
Within a package all type names and functions (save for [polymorphism]({{ < ref "/platforms/xdk110.md" > }})) have to be unique.
When we import a package, we import all names from that namespace into our local program. Consider the following example:
```TypeScript
// file: mypackage.mita
package mypackage;
...

export fn answerTheQuestion() {
	return 42;
}

// file: application.mita
package main;
import mypackage;

every XDK110.startup {
	println(`The answer: ${answerTheQuestion()}`);
}
```

If it were not for the `import mypackage` statement, the `answerTheQuestion` function would not be visible in `application.mita`.

To import a package use the `import` statement. We have seen those in previous examples when we imported the platform, which is mandatory. Thus, every Mita program file must have at least one import: the platform import.
For example:
```TypeScript
package main;
import platforms.xdk110;

...
```

You can shadow imported names within the current file. If in the example above `application.mita` defined its own `answerTheQuestion()` function, all code within `application.mita` would refer to that one instead of the imported function.


## Hiding Information (Visibility)
By default nothing is visible outside a package, nothing is exported to the outside world. This way, if you want to make things available outside the package, that has to be a conscious decision. To do so, mark what you want to export with the `export` keyword. For example:
```TypeScript
package utility;
import platforms.xdk110;

fn saturate(config : PidController) {
	...
}

export fn control(config : PidController, input : int32) : int32 {
	...
	saturate(config);
	...
}
```

In this example, the `saturate` function is not visible outside the `utility` package, but the `control` function is because it is marked with the `export` keyword.
This allows you to hide functions and types which are not meant for consumption outside of package and thus to provide a well defined API.
The generated C code will respect your export choices and mark non-exported objects as `static` which is "C speak" for _visible only within the same file_.
